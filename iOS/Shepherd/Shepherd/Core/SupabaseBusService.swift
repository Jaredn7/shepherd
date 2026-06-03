//
//  SupabaseBusService.swift
//  Shepherd
//
//  Real Supabase Bus Station client (fetch, batch send, ACK delete).
//

import Foundation

enum SupabaseBusError: LocalizedError {
    case invalidResponse
    case serverError(String)
    case majorUpdateRequired(String)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Unexpected response from the Bus Station."
        case .serverError(let message):
            return message
        case .majorUpdateRequired(let version):
            return "Major update required. Minimum version: \(version)"
        case .network(let error):
            return error.localizedDescription
        }
    }
}

struct RemoteLockboxPayload: Decodable {
    let type: String
    let senderPublicKey: String
    let iv: String
    let ciphertext: String
    let authTag: String

    enum CodingKeys: String, CodingKey {
        case type
        case senderPublicKey = "sender_public_key"
        case iv
        case ciphertext
        case authTag = "auth_tag"
    }
}

struct RemoteLockbox: Decodable, Identifiable {
    let id: UUID
    let senderDeviceId: UUID
    let minAppVersion: String
    let payload: RemoteLockboxPayload
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case senderDeviceId = "sender_device_id"
        case minAppVersion = "min_app_version"
        case payload
        case createdAt = "created_at"
    }
}

struct FetchLockboxesResponse: Decodable {
    let lockboxes: [RemoteLockbox]
    let updateAvailable: Bool
    let heldCount: Int

    enum CodingKeys: String, CodingKey {
        case lockboxes
        case updateAvailable = "update_available"
        case heldCount = "held_count"
    }
}

struct OutboundLockboxPayload: Encodable {
    let type: String
    let senderPublicKey: String
    let iv: String
    let ciphertext: String
    let authTag: String

    enum CodingKeys: String, CodingKey {
        case type
        case senderPublicKey = "sender_public_key"
        case iv
        case ciphertext
        case authTag = "auth_tag"
    }
}

struct OutboundLockbox: Encodable {
    let recipientDeviceId: UUID
    let minAppVersion: String
    let payload: OutboundLockboxPayload

    enum CodingKeys: String, CodingKey {
        case recipientDeviceId = "recipient_device_id"
        case minAppVersion = "min_app_version"
        case payload
    }
}

final class SupabaseBusService {
    static let shared = SupabaseBusService()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        self.encoder = JSONEncoder()
    }

    func fetchLockboxes(recipientDeviceId: UUID) async throws -> FetchLockboxesResponse {
        var components = URLComponents(
            url: SupabaseConfig.functionsURL("bus-fetch"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "recipient_device_id", value: recipientDeviceId.uuidString),
            URLQueryItem(name: "app_version", value: SupabaseConfig.appVersion),
        ]

        let request = try makeRequest(url: components.url!, method: "GET")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        if (response as? HTTPURLResponse)?.statusCode == 426 {
            if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let minVersion = payload["minimum_required_version"] as? String {
                throw SupabaseBusError.majorUpdateRequired(minVersion)
            }
            throw SupabaseBusError.majorUpdateRequired("unknown")
        }

        return try decoder.decode(FetchLockboxesResponse.self, from: data)
    }

    func sendLockboxes(
        senderDeviceId: UUID,
        lockboxes: [OutboundLockbox]
    ) async throws -> [UUID] {
        struct Body: Encodable {
            let senderDeviceId: UUID
            let lockboxes: [OutboundLockbox]

            enum CodingKeys: String, CodingKey {
                case senderDeviceId = "sender_device_id"
                case lockboxes
            }
        }

        let url = SupabaseConfig.functionsURL("bus-send")
        var request = try makeRequest(url: url, method: "POST")
        request.httpBody = try encoder.encode(Body(senderDeviceId: senderDeviceId, lockboxes: lockboxes))

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ids = json["ids"] as? [String] else {
            throw SupabaseBusError.invalidResponse
        }
        return ids.compactMap(UUID.init(uuidString:))
    }

    func acknowledgeLockboxes(
        recipientDeviceId: UUID,
        lockboxIds: [UUID]
    ) async throws {
        struct Body: Encodable {
            let recipientDeviceId: UUID
            let lockboxIds: [UUID]

            enum CodingKeys: String, CodingKey {
                case recipientDeviceId = "recipient_device_id"
                case lockboxIds = "lockbox_ids"
            }
        }

        let url = SupabaseConfig.functionsURL("bus-ack")
        var request = try makeRequest(url: url, method: "POST")
        request.httpBody = try encoder.encode(
            Body(recipientDeviceId: recipientDeviceId, lockboxIds: lockboxIds)
        )

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    // MARK: - Private

    private func makeRequest(url: URL, method: String) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseBusError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["error"] as? String {
                throw SupabaseBusError.serverError(message)
            }
            throw SupabaseBusError.serverError("HTTP \(http.statusCode)")
        }
    }
}
