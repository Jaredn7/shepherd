//
//  LockboxProcessor.swift
//  Shepherd
//
//  Decrypts lockboxes and applies instruction-manual mutations to Core Data.
//

import Foundation
import CoreData

enum LockboxProcessorError: LocalizedError {
    case unsupportedAction(String)
    case unsupportedTable(String)
    case missingRecordId
    case wipeDatabase

    var errorDescription: String? {
        switch self {
        case .unsupportedAction(let action):
            return "Unsupported lockbox action: \(action)"
        case .unsupportedTable(let table):
            return "Unsupported table: \(table)"
        case .missingRecordId:
            return "Instruction missing record_id."
        case .wipeDatabase:
            return "Remote wipe command received."
        }
    }
}

final class LockboxProcessor {
    static let shared = LockboxProcessor(context: CoreDataManager.shared.context)

    private let context: NSManagedObjectContext

    private init(context: NSManagedObjectContext) {
        self.context = context
    }

    /// Processes all unprocessed pending lockboxes. Returns remote IDs ready for ACK.
    @discardableResult
    func processPendingLockboxes() throws -> [UUID] {
        let request = NSFetchRequest<PendingLockbox>(entityName: "PendingLockbox")
        request.predicate = NSPredicate(format: "isProcessed == NO")
        request.sortDescriptors = [NSSortDescriptor(key: "receivedAt", ascending: true)]

        let pending = try context.fetch(request)
        var ackIds: [UUID] = []

        for lockbox in pending {
            do {
                try process(lockbox: lockbox)
                lockbox.isProcessed = true
                if let remoteId = lockbox.remoteId {
                    ackIds.append(remoteId)
                }
            } catch LockboxProcessorError.wipeDatabase {
                try wipeLocalDatabase()
                lockbox.isProcessed = true
                if let remoteId = lockbox.remoteId {
                    ackIds.append(remoteId)
                }
                break
            } catch {
                // Silently skip bad lockboxes per edge-case spec (auth tag failure).
                continue
            }
        }

        if context.hasChanges {
            try context.save()
        }

        return ackIds
    }

    func process(lockbox: PendingLockbox) throws {
        let decrypted = try CryptoManager.shared.decryptJSON(
            lockbox: lockbox.sealedLockbox,
            senderPublicKey: lockbox.senderPublicKey
        )

        if let instructions = decrypted["instructions"] as? [[String: Any]] {
            for instruction in instructions {
                try applyInstruction(instruction)
            }
            return
        }

        if let publishers = decrypted["publishers"] as? [[String: Any]] {
            for publisherData in publishers {
                try upsertPublisher(from: publisherData)
            }
            return
        }

        try applyInstruction(decrypted)
    }

    /// Applies a pre-approved welcome package (from invite resolve, not a lockbox).
    func applyWelcomeInstructions(_ instructions: [[String: Any]]) throws {
        for instruction in instructions {
            try applyInstruction(instruction)
        }
        if context.hasChanges {
            try context.save()
        }
    }

    // MARK: - Instruction Manual

    private func applyInstruction(_ instruction: [String: Any]) throws {
        let action = (instruction["action"] as? String ?? instruction["Action"] as? String ?? "")
            .uppercased()

        if action == "WIPE_DATABASE" {
            throw LockboxProcessorError.wipeDatabase
        }

        if action == "ACCESS_REQUEST" || action == "ACCESS_REQUEST_RECEIVED" {
            try handleAccessRequest(instruction)
            return
        }

        if action == "LINKED" || action == "WELCOME_LINKED" {
            try handleWelcomeLinked(instruction)
            return
        }

        if action == "DEVICE_LINKED" {
            try handleDeviceLinked(instruction)
            return
        }

        guard let table = instruction["table"] as? String ?? instruction["Table"] as? String else {
            if action == "DIRECTORY_UPDATE" {
                if let publishers = instruction["publishers"] as? [[String: Any]] {
                    for publisherData in publishers {
                        try upsertPublisher(from: publisherData)
                    }
                }
                return
            }
            return
        }

        switch action {
        case "INSERT", "UPDATE", "UPSERT":
            guard let recordId = uuid(from: instruction["record_id"] ?? instruction["Record_ID"]) else {
                throw LockboxProcessorError.missingRecordId
            }
            let data = instruction["data"] as? [String: Any] ?? instruction["Data"] as? [String: Any] ?? [:]
            try upsertRecord(table: table, recordId: recordId, data: data)
        case "DELETE":
            guard let recordId = uuid(from: instruction["record_id"] ?? instruction["Record_ID"]) else {
                throw LockboxProcessorError.missingRecordId
            }
            try deleteRecord(table: table, recordId: recordId)
        default:
            throw LockboxProcessorError.unsupportedAction(action)
        }
    }

    private func upsertRecord(table: String, recordId: UUID, data: [String: Any]) throws {
        switch table {
        case "Publisher":
            var payload = data
            payload["id"] = recordId.uuidString
            try upsertPublisher(from: payload)
        case "ServiceGroup":
            try upsertServiceGroup(recordId: recordId, data: data)
        case "DeviceDirectoryEntry":
            try upsertDirectoryEntry(recordId: recordId, data: data)
        default:
            throw LockboxProcessorError.unsupportedTable(table)
        }
    }

    private func deleteRecord(table: String, recordId: UUID) throws {
        let entityName: String
        switch table {
        case "Publisher": entityName = "Publisher"
        case "ServiceGroup": entityName = "ServiceGroup"
        case "DeviceDirectoryEntry": entityName = "DeviceDirectoryEntry"
        default:
            throw LockboxProcessorError.unsupportedTable(table)
        }

        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "id == %@", recordId as CVarArg)
        request.fetchLimit = 1
        if let object = try context.fetch(request).first {
            context.delete(object)
        }
    }

    // MARK: - Entity Upserts

    private func upsertPublisher(from data: [String: Any]) throws {
        guard let id = uuid(from: data["id"]) else { return }

        let request = NSFetchRequest<Publisher>(entityName: "Publisher")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        let publisher = try context.fetch(request).first ?? Publisher(
            context: context,
            id: id,
            firstName: "",
            lastName: ""
        )

        if let firstName = data["first_name"] as? String ?? data["firstName"] as? String {
            publisher.firstName = firstName
        }
        if let lastName = data["last_name"] as? String ?? data["lastName"] as? String {
            publisher.lastName = lastName
        }
        if data.keys.contains("phone_number") || data.keys.contains("phoneNumber") {
            publisher.phoneNumber = data["phone_number"] as? String ?? data["phoneNumber"] as? String
        }
        if data.keys.contains("email") {
            publisher.email = data["email"] as? String
        }
        if let privilege = data["privilege"] as? String ?? data["privilegeRaw"] as? String {
            publisher.privilegeRaw = privilege
        }
        if let pioneer = data["pioneer_status"] as? String ?? data["pioneerStatus"] as? String ?? data["pioneerStatusRaw"] as? String {
            publisher.pioneerStatusRaw = pioneer
        }
        if let groupRaw = data["service_group_id"] as? String ?? data["serviceGroupId"] as? String {
            publisher.serviceGroupId = UUID(uuidString: groupRaw)
        }
        if let roles = data["roles"] as? [String] {
            publisher.rolesArray = roles
        }
        if let publicKey = data["public_key"] as? String ?? data["publicKey"] as? String {
            publisher.publicKey = publicKey
        }
        if let isActive = data["is_active"] as? Bool ?? data["isActive"] as? Bool {
            publisher.isActive = isActive
        }
        publisher.updatedAt = parseDate(data["updated_at"] ?? data["updatedAt"]) ?? .now
        if publisher.createdAt.timeIntervalSince1970 == 0 {
            publisher.createdAt = parseDate(data["created_at"] ?? data["createdAt"]) ?? .now
        }
    }

    private func upsertServiceGroup(recordId: UUID, data: [String: Any]) throws {
        let request = NSFetchRequest<ServiceGroup>(entityName: "ServiceGroup")
        request.predicate = NSPredicate(format: "id == %@", recordId as CVarArg)
        request.fetchLimit = 1

        let group = try context.fetch(request).first ?? ServiceGroup(
            context: context,
            id: recordId,
            name: "Group"
        )

        if let name = data["name"] as? String {
            group.name = name
        }
        if let overseerRaw = data["overseer_id"] as? String ?? data["overseerId"] as? String {
            group.overseerId = UUID(uuidString: overseerRaw)
        }
        if let assistants = data["assistant_ids"] as? [String] {
            let uuids = assistants.compactMap(UUID.init(uuidString:))
            group.assistantIdsArray = uuids
        }
    }

    private func upsertDirectoryEntry(recordId: UUID, data: [String: Any]) throws {
        guard let deviceId = uuid(from: data["device_id"] ?? data["deviceId"]),
              let publicKey = data["public_key"] as? String ?? data["publicKey"] as? String else {
            return
        }

        let request = NSFetchRequest<DeviceDirectoryEntry>(entityName: "DeviceDirectoryEntry")
        request.predicate = NSPredicate(format: "deviceId == %@", deviceId as CVarArg)
        request.fetchLimit = 1

        let entry = try context.fetch(request).first ?? DeviceDirectoryEntry(
            context: context,
            id: recordId,
            deviceId: deviceId,
            publicKey: publicKey
        )

        entry.publisherId = uuid(from: data["publisher_id"] ?? data["publisherId"])
        entry.publicKey = publicKey
        entry.isElder = data["is_elder"] as? Bool ?? data["isElder"] as? Bool ?? false
        entry.updatedAt = .now
    }

    // MARK: - Onboarding Handlers

    private func handleAccessRequest(_ instruction: [String: Any]) throws {
        guard DeviceIdentityManager.shared.directoryScope == .full,
              let deviceId = uuid(from: instruction["device_id"] ?? instruction["requester_device_id"]),
              let publicKey = instruction["public_key"] as? String ?? instruction["requester_public_key"] as? String else {
            return
        }

        let request = NSFetchRequest<AccessRequest>(entityName: "AccessRequest")
        request.predicate = NSPredicate(format: "requesterDeviceId == %@", deviceId as CVarArg)
        request.fetchLimit = 1

        if try context.fetch(request).first != nil { return }

        let publisherId = uuid(from: instruction["publisher_id"] ?? instruction["publisherId"])

        _ = AccessRequest(
            context: context,
            requesterDeviceId: deviceId,
            requesterPublicKey: publicKey,
            publisherId: publisherId,
            requestedAt: parseDate(instruction["requested_at"]) ?? .now
        )
    }

    private func handleWelcomeLinked(_ instruction: [String: Any]) throws {
        if let publisherId = uuid(from: instruction["publisher_id"]) {
            let scope: DirectoryScope = (instruction["directory_scope"] as? String == "full") ? .full : .lite
            DeviceIdentityManager.shared.markLinked(publisherId: publisherId, scope: scope)
        }
        if let congregationId = uuid(from: instruction["congregation_id"]) {
            DeviceIdentityManager.shared.congregationId = congregationId
        }
        DispatchQueue.main.async {
            DeviceIdentityBridge.shared.refresh()
        }
    }

    private func handleDeviceLinked(_ instruction: [String: Any]) throws {
        guard DeviceIdentityManager.shared.directoryScope == .full,
              let publisherId = uuid(from: instruction["publisher_id"]),
              let deviceId = uuid(from: instruction["device_id"]),
              let publicKey = instruction["public_key"] as? String else {
            return
        }

        let publisherRequest = NSFetchRequest<Publisher>(entityName: "Publisher")
        publisherRequest.predicate = NSPredicate(format: "id == %@", publisherId as CVarArg)
        publisherRequest.fetchLimit = 1

        if let publisher = try context.fetch(publisherRequest).first {
            publisher.publicKey = publicKey
            publisher.updatedAt = .now
        }

        let entryRequest = NSFetchRequest<DeviceDirectoryEntry>(entityName: "DeviceDirectoryEntry")
        entryRequest.predicate = NSPredicate(format: "deviceId == %@", deviceId as CVarArg)
        entryRequest.fetchLimit = 1

        if try context.fetch(entryRequest).first == nil {
            _ = DeviceDirectoryEntry(
                context: context,
                publisherId: publisherId,
                deviceId: deviceId,
                publicKey: publicKey
            )
        }
    }

    private func wipeLocalDatabase() throws {
        DeviceIdentityManager.shared.resetOnboarding()
        for entityName in ["Publisher", "ServiceGroup", "PendingLockbox", "DeviceDirectoryEntry", "AccessRequest"] {
            let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let delete = NSBatchDeleteRequest(fetchRequest: fetch)
            try context.execute(delete)
        }
        try context.save()
    }

    // MARK: - Helpers

    private func uuid(from value: Any?) -> UUID? {
        if let uuid = value as? UUID { return uuid }
        if let string = value as? String { return UUID(uuidString: string) }
        return nil
    }

    private func parseDate(_ value: Any?) -> Date? {
        if let date = value as? Date { return date }
        if let string = value as? String {
            return ISO8601DateFormatter().date(from: string)
        }
        return nil
    }
}
