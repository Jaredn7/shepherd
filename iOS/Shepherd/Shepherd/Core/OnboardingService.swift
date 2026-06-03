//
//  OnboardingService.swift
//  Shepherd
//

import Foundation
import CoreData

struct ResolvedInvite {
    let congregationId: UUID
    let elderPublicKey: String
    let elderDeviceId: UUID
    let inviteCode: String
    let publisherId: UUID
    let welcomePackage: [[String: Any]]
}

enum OnboardingServiceError: LocalizedError {
    case inviteNotFound
    case publisherNotFound
    case welcomePackageMissing
    case welcomePackageIncomplete
    case inviteAckFailed
    case network(String)

    var errorDescription: String? {
        switch self {
        case .inviteNotFound:
            return "No invite found. Tap your invite link on this device first, then open Shepherd."
        case .publisherNotFound:
            return "The publisher for this invite could not be found on this device."
        case .welcomePackageMissing:
            return "This invite is missing its welcome package. Ask your elder for a new link."
        case .welcomePackageIncomplete:
            return "The welcome package did not finish applying on this device. Try again — your invite is still valid."
        case .inviteAckFailed:
            return "Could not confirm your invite with the server. Try again — your welcome package is still available."
        case .network(let message):
            return message
        }
    }
}

@MainActor
final class OnboardingService {
    static let shared = OnboardingService()

    private let identity = DeviceIdentityManager.shared
    private let sync = SyncCoordinator.shared
    private let congregationSync = CongregationSyncService.shared
    private let processor = LockboxProcessor.shared
    private let context = CoreDataManager.shared.context

    private init() {}

    // MARK: - Publisher Flow

    /// Records the landing-page click when the app is opened via Universal Link (web may not have run).
    func recordInviteClick(inviteCode: String) async throws {
        let fingerprint = identity.deviceFingerprint()
        let body: [String: Any] = [
            "invite_code": inviteCode.uppercased(),
            "fingerprint": fingerprint,
        ]

        let url = SupabaseConfig.functionsURL("invite-click")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw OnboardingServiceError.network("Could not register invite click")
        }
    }

    func resolveInvite(inviteCode: String? = nil) async throws -> ResolvedInvite {
        let fingerprint = identity.deviceFingerprint()
        var body: [String: Any] = ["fingerprint": fingerprint]
        if let inviteCode, !inviteCode.isEmpty {
            body["invite_code"] = inviteCode.uppercased()
        }

        let url = SupabaseConfig.functionsURL("invite-resolve")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw OnboardingServiceError.inviteNotFound
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OnboardingServiceError.inviteNotFound
        }

        return try parseResolvedInvite(json)
    }

    /// Applies the welcome package locally and notifies the congregation. Does not clear cloud storage.
    func completeInviteOnboarding(_ invite: ResolvedInvite) async throws {
        try processor.applyWelcomeInstructions(invite.welcomePackage)
        try verifyWelcomePackageApplied(for: invite)

        let publicKey = CryptoManager.shared.publicKeyBase64()

        if let publisher = try congregationSync.publisher(for: invite.publisherId) {
            publisher.publicKey = publicKey
            publisher.updatedAt = .now
        }

        _ = DeviceDirectoryEntry(
            context: context,
            publisherId: invite.publisherId,
            deviceId: identity.deviceId,
            publicKey: publicKey
        )

        try context.save()

        let wasAlreadyLinked = identity.onboardingState == .linked

        let linkInstruction: [String: Any] = [
            "action": "DEVICE_LINKED",
            "publisher_id": invite.publisherId.uuidString,
            "device_id": identity.deviceId.uuidString,
            "public_key": publicKey,
            "congregation_id": invite.congregationId.uuidString,
        ]

        if !wasAlreadyLinked {
            try await sync.sendEncryptedLockbox(
                type: "device_linked",
                instruction: linkInstruction,
                toRecipientDeviceId: invite.elderDeviceId,
                recipientPublicKey: invite.elderPublicKey
            )
        }

        if let publisher = try congregationSync.publisher(for: invite.publisherId) {
            try await congregationSync.broadcastPublisherUpdate(
                publisher,
                excludingDeviceIds: [identity.deviceId]
            )
        }
    }

    /// Tells the server the welcome package was received safely; clears cloud copy (retry-safe until this succeeds).
    func acknowledgeInviteReceipt(inviteCode: String) async throws {
        let fingerprint = identity.deviceFingerprint()
        let body: [String: Any] = [
            "invite_code": inviteCode.uppercased(),
            "fingerprint": fingerprint,
        ]

        let url = SupabaseConfig.functionsURL("invite-ack")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw OnboardingServiceError.inviteAckFailed
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           json["ok"] as? Bool != true {
            throw OnboardingServiceError.inviteAckFailed
        }
    }

    func joinWithPreApprovedInvite(inviteCode: String? = nil) async throws {
        let invite = try await resolveInvite(inviteCode: inviteCode)
        try await completeInviteOnboarding(invite)
        try await acknowledgeInviteReceipt(inviteCode: invite.inviteCode)
    }

    private func verifyWelcomePackageApplied(for invite: ResolvedInvite) throws {
        guard identity.linkedPublisherId == invite.publisherId else {
            throw OnboardingServiceError.welcomePackageIncomplete
        }
        guard identity.congregationId == invite.congregationId else {
            throw OnboardingServiceError.welcomePackageIncomplete
        }
        guard try congregationSync.publisher(for: invite.publisherId) != nil else {
            throw OnboardingServiceError.welcomePackageIncomplete
        }
        let publisherCount = try context.count(for: NSFetchRequest<Publisher>(entityName: "Publisher"))
        guard publisherCount > 0 else {
            throw OnboardingServiceError.welcomePackageIncomplete
        }
    }

    // MARK: - Elder Flow

    func createInviteSession(
        publisherId: UUID,
        congregationId: UUID
    ) async throws -> String {
        let inviteCode = UUID().uuidString.prefix(8).uppercased()
        let welcomePackage = try buildWelcomePackageInstructions(
            publisherId: publisherId,
            congregationId: congregationId
        )

        let body: [String: Any] = [
            "invite_code": String(inviteCode),
            "congregation_id": congregationId.uuidString,
            "publisher_id": publisherId.uuidString,
            "elder_public_key": CryptoManager.shared.publicKeyBase64(),
            "elder_device_id": identity.deviceId.uuidString,
            "welcome_package": welcomePackage,
        ]

        let url = SupabaseConfig.functionsURL("invite-record")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw OnboardingServiceError.network("Failed to create invite session")
        }

        return String(inviteCode)
    }

    /// Path-style URL for Universal Links (`/i/CODE`), not query-only (`/i/?code=`).
    func inviteURL(for inviteCode: String) -> URL? {
        guard let host = SupabaseConfig.inviteHost else { return nil }
        let base = host.hasSuffix("/") ? String(host.dropLast()) : host
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return nil }
        return URL(string: "\(base)/i/\(code)")
    }

    /// Legacy manual approval path (non-link invites).
    func approveAccessRequest(_ accessRequest: AccessRequest) async throws {
        guard let publisherId = accessRequest.publisherId else {
            throw OnboardingServiceError.publisherNotFound
        }

        guard let publisher = try congregationSync.publisher(for: publisherId) else {
            throw OnboardingServiceError.publisherNotFound
        }

        let requesterDeviceId = accessRequest.requesterDeviceId
        let requesterPublicKey = accessRequest.requesterPublicKey

        publisher.publicKey = requesterPublicKey
        publisher.updatedAt = .now
        accessRequest.status = .approved

        _ = DeviceDirectoryEntry(
            context: context,
            publisherId: publisherId,
            deviceId: requesterDeviceId,
            publicKey: requesterPublicKey
        )

        let welcomeInstructions = try buildWelcomePackageInstructions(
            publisherId: publisherId,
            congregationId: identity.congregationId ?? UUID()
        )

        try await sync.sendEncryptedLockbox(
            type: "welcome_package",
            instruction: ["action": "WELCOME_PACKAGE", "instructions": welcomeInstructions],
            toRecipientDeviceId: requesterDeviceId,
            recipientPublicKey: requesterPublicKey
        )

        try await congregationSync.broadcastPublisherUpdate(
            publisher,
            excludingDeviceIds: [requesterDeviceId]
        )

        try context.save()
    }

    func bootstrapElderAccount(
        firstName: String,
        lastName: String,
        congregationId: UUID
    ) throws {
        let publisherId = UUID()
        let publicKey = CryptoManager.shared.publicKeyBase64()

        _ = Publisher(
            context: context,
            id: publisherId,
            firstName: firstName,
            lastName: lastName,
            privilege: .elder,
            publicKey: publicKey
        )

        _ = DeviceDirectoryEntry(
            context: context,
            publisherId: publisherId,
            deviceId: identity.deviceId,
            publicKey: publicKey,
            isElder: true
        )

        identity.bootstrapAsElder(publisherId: publisherId, congregationId: congregationId)
        try context.save()
    }

    // MARK: - Welcome Package Builder

    func buildWelcomePackageInstructions(
        publisherId: UUID,
        congregationId: UUID
    ) throws -> [[String: Any]] {
        var welcomeInstructions: [[String: Any]] = []

        let allPublishers = try context.fetch(NSFetchRequest<Publisher>(entityName: "Publisher"))
        for pub in allPublishers where pub.isActive {
            welcomeInstructions.append([
                "action": "INSERT",
                "table": "Publisher",
                "record_id": pub.id.uuidString,
                "data": congregationSync.publisherWirePayload(pub),
            ])
        }

        let elderEntries = try context.fetch(NSFetchRequest<DeviceDirectoryEntry>(entityName: "DeviceDirectoryEntry"))
        for entry in elderEntries {
            welcomeInstructions.append([
                "action": "INSERT",
                "table": "DeviceDirectoryEntry",
                "record_id": UUID().uuidString,
                "data": [
                    "device_id": entry.deviceId.uuidString,
                    "public_key": entry.publicKey,
                    "publisher_id": entry.publisherId?.uuidString as Any,
                    "is_elder": entry.isElder,
                ],
            ])
        }

        welcomeInstructions.append([
            "action": "LINKED",
            "publisher_id": publisherId.uuidString,
            "congregation_id": congregationId.uuidString,
            "directory_scope": "lite",
        ])

        return welcomeInstructions
    }

    // MARK: - Parsing

    private func parseResolvedInvite(_ json: [String: Any]) throws -> ResolvedInvite {
        guard let congregationRaw = json["congregation_id"] as? String,
              let congregationId = UUID(uuidString: congregationRaw),
              let elderPublicKey = json["elder_public_key"] as? String,
              let elderDeviceRaw = json["elder_device_id"] as? String,
              let elderDeviceId = UUID(uuidString: elderDeviceRaw),
              let inviteCode = json["invite_code"] as? String,
              let publisherRaw = json["publisher_id"] as? String,
              let publisherId = UUID(uuidString: publisherRaw),
              let welcomePackage = json["welcome_package"] as? [[String: Any]] else {
            throw OnboardingServiceError.welcomePackageMissing
        }

        return ResolvedInvite(
            congregationId: congregationId,
            elderPublicKey: elderPublicKey,
            elderDeviceId: elderDeviceId,
            inviteCode: inviteCode,
            publisherId: publisherId,
            welcomePackage: welcomePackage
        )
    }
}
