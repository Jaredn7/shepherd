//
//  ServiceGroup.swift
//  Shepherd
//
//  Core Data model representing a field service group in a
//  Jehovah's Witness congregation.
//

import Foundation
import CoreData

// MARK: - ServiceGroup Model

/// A field service group within the congregation.
///
/// Each congregation is divided into service groups, typically
/// overseen by an elder (the group overseer) with one or more
/// ministerial servants or elders as assistants.
@objc(ServiceGroup)
public class ServiceGroup: NSManagedObject {

    // MARK: Primary Key

    /// Unique identifier for this service group.
    @NSManaged public var id: UUID

    // MARK: Properties

    /// The display name of the service group (e.g., "Group 1", "Group 2").
    @NSManaged public var name: String

    /// The UUID of the elder appointed as this group's overseer.
    ///
    /// References a `Publisher` with `privilege == .elder`.
    @NSManaged public var overseerId: UUID?

    /// Underlying storage for assistants
    @NSManaged public var assistantIds: Data

    /// The UUIDs of publishers serving as assistants to the group overseer.
    ///
    /// Typically one or more ministerial servants or elders.
    public var assistantIdsArray: [UUID] {
        get {
            if let decoded = try? JSONDecoder().decode([UUID].self, from: assistantIds) {
                return decoded
            }
            return []
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                assistantIds = encoded
            }
        }
    }

    // MARK: Timestamps

    /// The date this service group record was created.
    @NSManaged public var createdAt: Date

    // MARK: Initialiser

    /// Creates a new `ServiceGroup` instance.
    ///
    /// - Parameters:
    ///   - context: The Core Data managed object context.
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - name: Display name for the group.
    ///   - overseerId: UUID of the group overseer (optional).
    ///   - assistantIdsArray: UUIDs of group assistants (default: empty).
    ///   - createdAt: Creation timestamp (default: now).
    @nonobjc public convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        name: String,
        overseerId: UUID? = nil,
        assistantIdsArray: [UUID] = [],
        createdAt: Date = .now
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "ServiceGroup", in: context)!
        self.init(entity: entity, insertInto: context)
        self.id = id
        self.name = name
        self.overseerId = overseerId
        if let encoded = try? JSONEncoder().encode(assistantIdsArray) {
            self.assistantIds = encoded
        } else {
            self.assistantIds = Data()
        }
        self.createdAt = createdAt
    }
}
