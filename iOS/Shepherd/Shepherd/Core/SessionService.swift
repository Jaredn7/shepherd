//
//  SessionService.swift
//  Shepherd
//

import CoreData
import Foundation

/// Signs the user out on this device and returns to onboarding.
@MainActor
enum SessionService {
    private static let entityNames = [
        "Publisher",
        "ServiceGroup",
        "PendingLockbox",
        "DeviceDirectoryEntry",
        "AccessRequest",
    ]

    static func logout() throws {
        let context = CoreDataManager.shared.context

        for entityName in entityNames {
            let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let delete = NSBatchDeleteRequest(fetchRequest: fetch)
            delete.resultType = .resultTypeObjectIDs
            let result = try context.execute(delete) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                    into: [context]
                )
            }
        }

        try context.save()

        DeviceIdentityManager.shared.resetOnboarding()
        DeviceIdentityManager.shared.lastSuccessfulSync = nil
        try? CryptoManager.shared.regenerateKeyPair()
        InviteDeepLinkHandler.shared.resetForLogout()

        DeviceIdentityBridge.shared.inviteJoinError = nil
        DeviceIdentityBridge.shared.refresh()
    }
}
