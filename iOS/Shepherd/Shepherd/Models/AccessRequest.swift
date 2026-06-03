//
//  AccessRequest.swift
//  Shepherd
//

import Foundation
import CoreData

public enum AccessRequestStatus: String, Codable {
    case pending
    case approved
    case rejected
}

@objc(AccessRequest)
public class AccessRequest: NSManagedObject {

    @NSManaged public var id: UUID
    @NSManaged public var requesterDeviceId: UUID
    @NSManaged public var requesterPublicKey: String
    @NSManaged public var requestedAt: Date
    @NSManaged public var statusRaw: String

    /// The publisher record this device is trying to link to (from the invite).
    @NSManaged public var publisherId: UUID?

    public var status: AccessRequestStatus {
        get { AccessRequestStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    @nonobjc public convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        requesterDeviceId: UUID,
        requesterPublicKey: String,
        publisherId: UUID? = nil,
        requestedAt: Date = .now,
        status: AccessRequestStatus = .pending
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "AccessRequest", in: context)!
        self.init(entity: entity, insertInto: context)
        self.id = id
        self.requesterDeviceId = requesterDeviceId
        self.requesterPublicKey = requesterPublicKey
        self.publisherId = publisherId
        self.requestedAt = requestedAt
        self.statusRaw = status.rawValue
    }
}
