//
//  CongregationSyncService.swift
//  Shepherd
//
//  Broadcasts directory changes to every connected device in the congregation.
//

import Foundation
import CoreData

enum CongregationSyncError: LocalizedError {
    case publisherNotFound
    case noRecipients

    var errorDescription: String? {
        switch self {
        case .publisherNotFound:
            return "Publisher record not found."
        case .noRecipients:
            return "No other devices are connected yet to receive this update."
        }
    }
}

@MainActor
final class CongregationSyncService {
    static let shared = CongregationSyncService()

    private let context: NSManagedObjectContext
    private let identity = DeviceIdentityManager.shared
    private let bus = SupabaseBusService.shared

    private init() {
        self.context = CoreDataManager.shared.context
    }

    // MARK: - Add publisher (local + broadcast)

    @discardableResult
    func addPublisher(
        firstName: String,
        lastName: String,
        privilege: PublisherPrivilege = .publisher,
        pioneerStatus: PioneerStatus = .none,
        phoneNumber: String? = nil,
        email: String? = nil
    ) async throws -> Publisher {
        let publisher = Publisher(
            context: context,
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: phoneNumber,
            email: email,
            privilege: privilege,
            pioneerStatus: pioneerStatus,
            publicKey: nil,
            isActive: true
        )

        try context.save()

        try await broadcastPublisherInsert(publisher)

        return publisher
    }

    func broadcastPublisherInsert(_ publisher: Publisher) async throws {
        let instruction = directoryInstruction(
            action: "INSERT",
            publisher: publisher
        )
        try await broadcast(instruction: instruction, excludingDeviceIds: [])
    }

    func broadcastPublisherUpdate(_ publisher: Publisher, excludingDeviceIds: Set<UUID> = []) async throws {
        let instruction = directoryInstruction(
            action: "UPDATE",
            publisher: publisher
        )
        try await broadcast(instruction: instruction, excludingDeviceIds: excludingDeviceIds)
    }

    // MARK: - Broadcast engine

    func broadcast(
        instruction: [String: Any],
        excludingDeviceIds: Set<UUID>
    ) async throws {
        let recipients = try directoryRecipients(excluding: excludingDeviceIds.union([identity.deviceId]))
        guard !recipients.isEmpty else { return }

        var outbound: [OutboundLockbox] = []
        for entry in recipients {
            let box = try CryptoManager.shared.encrypt(
                jsonObject: instruction,
                forRecipientPublicKey: entry.publicKey
            )
            outbound.append(
                OutboundLockbox(
                    recipientDeviceId: entry.deviceId,
                    minAppVersion: SupabaseConfig.appVersion,
                    payload: OutboundLockboxPayload(
                        type: "directory_update",
                        senderPublicKey: CryptoManager.shared.publicKeyBase64(),
                        iv: box.iv,
                        ciphertext: box.ciphertext,
                        authTag: box.authTag
                    )
                )
            )
        }

        let chunkSize = 100
        var index = 0
        while index < outbound.count {
            let end = min(index + chunkSize, outbound.count)
            let chunk = Array(outbound[index..<end])
            _ = try await bus.sendLockboxes(
                senderDeviceId: identity.deviceId,
                lockboxes: chunk
            )
            index = end
        }
    }

    // MARK: - Helpers

    private func directoryRecipients(excluding deviceIds: Set<UUID>) throws -> [DeviceDirectoryEntry] {
        let request = NSFetchRequest<DeviceDirectoryEntry>(entityName: "DeviceDirectoryEntry")
        let all = try context.fetch(request)
        return all.filter { !deviceIds.contains($0.deviceId) }
    }

    func publisher(for id: UUID) throws -> Publisher? {
        let request = NSFetchRequest<Publisher>(entityName: "Publisher")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    func isDeviceLinked(publisherId: UUID) -> Bool {
        let request = NSFetchRequest<DeviceDirectoryEntry>(entityName: "DeviceDirectoryEntry")
        request.predicate = NSPredicate(format: "publisherId == %@", publisherId as CVarArg)
        request.fetchLimit = 1
        return (try? context.fetch(request).first) != nil
    }

    func publisherWirePayload(_ publisher: Publisher) -> [String: Any] {
        [
            "id": publisher.id.uuidString,
            "first_name": publisher.firstName,
            "last_name": publisher.lastName,
            "phone_number": publisher.phoneNumber as Any,
            "email": publisher.email as Any,
            "privilege": publisher.privilegeRaw,
            "pioneer_status": publisher.pioneerStatusRaw,
            "service_group_id": publisher.serviceGroupId?.uuidString as Any,
            "roles": publisher.rolesArray,
            "public_key": publisher.publicKey as Any,
            "is_active": publisher.isActive,
            "created_at": ISO8601DateFormatter().string(from: publisher.createdAt),
            "updated_at": ISO8601DateFormatter().string(from: publisher.updatedAt),
        ]
    }

    private func directoryInstruction(action: String, publisher: Publisher) -> [String: Any] {
        [
            "action": action,
            "table": "Publisher",
            "record_id": publisher.id.uuidString,
            "data": publisherWirePayload(publisher),
            "timestamp": ISO8601DateFormatter().string(from: .now),
        ]
    }
}
