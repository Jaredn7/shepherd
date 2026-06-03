//
//  DeviceDirectoryEntry.swift
//  Shepherd
//

import Foundation
import CoreData

@objc(DeviceDirectoryEntry)
public class DeviceDirectoryEntry: NSManagedObject {

    @NSManaged public var id: UUID
    @NSManaged public var publisherId: UUID?
    @NSManaged public var deviceId: UUID
    @NSManaged public var publicKey: String
    @NSManaged public var isElder: Bool
    @NSManaged public var updatedAt: Date

    @nonobjc public convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        publisherId: UUID? = nil,
        deviceId: UUID,
        publicKey: String,
        isElder: Bool = false,
        updatedAt: Date = .now
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "DeviceDirectoryEntry", in: context)!
        self.init(entity: entity, insertInto: context)
        self.id = id
        self.publisherId = publisherId
        self.deviceId = deviceId
        self.publicKey = publicKey
        self.isElder = isElder
        self.updatedAt = updatedAt
    }
}
