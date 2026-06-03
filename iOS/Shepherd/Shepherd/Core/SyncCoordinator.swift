//
//  SyncCoordinator.swift
//  Shepherd
//
//  Orchestrates fetch-on-open sync: download → store → decrypt → ACK.
//

import Foundation
import CoreData
import Combine

@MainActor
final class SyncCoordinator: ObservableObject {
    static let shared = SyncCoordinator(context: CoreDataManager.shared.context)

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncError: String?
    @Published private(set) var updateAvailable = false

    private let bus = SupabaseBusService.shared
    private let processor = LockboxProcessor.shared
    private let identity = DeviceIdentityManager.shared
    private let context: NSManagedObjectContext

    private init(context: NSManagedObjectContext) {
        self.context = context
    }

    func syncIfNeeded() async {
        guard identity.onboardingState != .fresh else { return }
        await performSync()
    }

    func performSync() async {
        guard !isSyncing else { return }
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        do {
            let fetchResult = try await bus.fetchLockboxes(recipientDeviceId: identity.deviceId)
            updateAvailable = fetchResult.updateAvailable
            try ingest(remoteLockboxes: fetchResult.lockboxes)

            let ackIds = try processor.processPendingLockboxes()
            if !ackIds.isEmpty {
                try await bus.acknowledgeLockboxes(
                    recipientDeviceId: identity.deviceId,
                    lockboxIds: ackIds
                )
            }

            identity.lastSuccessfulSync = .now
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    // MARK: - Outbound Helpers

    func sendEncryptedLockbox(
        type: String,
        instruction: [String: Any],
        toRecipientDeviceId: UUID,
        recipientPublicKey: String,
        minAppVersion: String? = nil
    ) async throws {
        let resolvedMinVersion = minAppVersion ?? SupabaseConfig.appVersion

        let sealed = try CryptoManager.shared.encrypt(
            jsonObject: instruction,
            forRecipientPublicKey: recipientPublicKey
        )

        let payload = OutboundLockboxPayload(
            type: type,
            senderPublicKey: CryptoManager.shared.publicKeyBase64(),
            iv: sealed.iv,
            ciphertext: sealed.ciphertext,
            authTag: sealed.authTag
        )

        let outbound = OutboundLockbox(
            recipientDeviceId: toRecipientDeviceId,
            minAppVersion: resolvedMinVersion,
            payload: payload
        )

        _ = try await bus.sendLockboxes(
            senderDeviceId: identity.deviceId,
            lockboxes: [outbound]
        )
    }

    // MARK: - Private

    private func ingest(remoteLockboxes: [RemoteLockbox]) throws {
        for remote in remoteLockboxes {
            let existsRequest = NSFetchRequest<PendingLockbox>(entityName: "PendingLockbox")
            existsRequest.predicate = NSPredicate(format: "remoteId == %@", remote.id as CVarArg)
            existsRequest.fetchLimit = 1
            if try context.fetch(existsRequest).first != nil {
                continue
            }

            _ = PendingLockbox(
                context: context,
                type: remote.payload.type,
                senderPublicKey: remote.payload.senderPublicKey,
                iv: remote.payload.iv,
                ciphertext: remote.payload.ciphertext,
                authTag: remote.payload.authTag,
                remoteId: remote.id,
                senderDeviceId: remote.senderDeviceId
            )
        }

        if context.hasChanges {
            try context.save()
        }
    }
}
