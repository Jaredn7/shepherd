//
//  Publisher.swift
//  Shepherd
//
//  Core Data model representing a publisher (member) in a
//  Jehovah's Witness congregation.
//

import Foundation
import CoreData

// MARK: - Enumerations

/// The theocratic privilege assigned to a male publisher.
public enum PublisherPrivilege: String, Codable, CaseIterable {
    /// A baptised publisher with no additional appointment.
    case publisher
    /// Appointed as a ministerial servant.
    case ministerialServant
    /// Appointed as an elder.
    case elder
}

/// The pioneer (full-time ministry) status of a publisher.
public enum PioneerStatus: String, Codable, CaseIterable {
    /// Not pioneering.
    case none
    /// Serving as an auxiliary pioneer (typically 30 or 50 hours/month).
    case auxiliaryPioneer
    /// Serving as a regular pioneer (ongoing assignment).
    case regularPioneer
    /// Serving as a special pioneer (branch-assigned).
    case specialPioneer
}

// MARK: - Publisher Model

/// A congregation publisher, representing an individual member.
///
/// Each publisher has a unique identity, contact information,
/// theocratic privileges, and an optional P-256 public key used
/// for end-to-end encrypted communication.
@objc(Publisher)
public class Publisher: NSManagedObject {

    // MARK: Primary Key

    /// Unique identifier for this publisher.
    @NSManaged public var id: UUID

    // MARK: Personal Information

    /// The publisher's first (given) name.
    @NSManaged public var firstName: String

    /// The publisher's last (family) name.
    @NSManaged public var lastName: String

    /// Optional phone number for contact.
    @NSManaged public var phoneNumber: String?

    /// Optional email address for contact.
    @NSManaged public var email: String?

    // MARK: Theocratic Assignments

    @NSManaged public var privilegeRaw: String

    /// The publisher's current privilege (publisher, ministerial servant, or elder).
    public var privilege: PublisherPrivilege {
        get {
            PublisherPrivilege(rawValue: privilegeRaw) ?? .publisher
        }
        set {
            privilegeRaw = newValue.rawValue
        }
    }

    @NSManaged public var pioneerStatusRaw: String

    /// The publisher's current pioneer status.
    public var pioneerStatus: PioneerStatus {
        get {
            PioneerStatus(rawValue: pioneerStatusRaw) ?? .none
        }
        set {
            pioneerStatusRaw = newValue.rawValue
        }
    }

    /// The UUID of the field service group this publisher belongs to.
    @NSManaged public var serviceGroupId: UUID?

    /// Underlying storage for roles.
    @NSManaged public var roles: Data

    /// Additional congregation roles assigned to this publisher.
    ///
    /// Examples: `["secretary", "publicTalksCoordinator", "watchtowerConductor"]`
    public var rolesArray: [String] {
        get {
            if let decoded = try? JSONDecoder().decode([String].self, from: roles) {
                return decoded
            }
            return []
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                roles = encoded
            }
        }
    }

    // MARK: Encryption

    /// Base64-encoded P-256 public key for end-to-end encryption.
    ///
    /// This key is used by other publishers to encrypt lockboxes
    /// destined for this publisher. It is exported via
    /// `CryptoManager.shared.publicKeyBase64()`.
    @NSManaged public var publicKey: String?

    // MARK: Status

    /// Whether the publisher is currently active in the congregation.
    @NSManaged public var isActive: Bool

    // MARK: Timestamps

    /// The date this publisher record was created.
    @NSManaged public var createdAt: Date

    /// The date this publisher record was last updated.
    @NSManaged public var updatedAt: Date

    // MARK: Computed Properties

    /// The publisher's full name in "FirstName LastName" format.
    public var fullName: String {
        "\(firstName) \(lastName)"
    }

    // MARK: Initialiser

    /// Creates a new `Publisher` instance.
    ///
    /// - Parameters:
    ///   - context: The Core Data managed object context.
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - firstName: Given name.
    ///   - lastName: Family name.
    ///   - phoneNumber: Optional phone number.
    ///   - email: Optional email address.
    ///   - privilege: Theocratic privilege (default: `.publisher`).
    ///   - pioneerStatus: Pioneer status (default: `.none`).
    ///   - serviceGroupId: Field service group UUID (optional).
    ///   - rolesArray: Array of role strings (default: empty).
    ///   - publicKey: Base64-encoded P-256 public key (optional).
    ///   - isActive: Whether the publisher is active (default: `true`).
    ///   - createdAt: Creation timestamp (default: now).
    ///   - updatedAt: Last-updated timestamp (default: now).
    @nonobjc public convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        firstName: String,
        lastName: String,
        phoneNumber: String? = nil,
        email: String? = nil,
        privilege: PublisherPrivilege = .publisher,
        pioneerStatus: PioneerStatus = .none,
        serviceGroupId: UUID? = nil,
        rolesArray: [String] = [],
        publicKey: String? = nil,
        isActive: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "Publisher", in: context)!
        self.init(entity: entity, insertInto: context)
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumber = phoneNumber
        self.email = email
        self.privilegeRaw = privilege.rawValue
        self.pioneerStatusRaw = pioneerStatus.rawValue
        self.serviceGroupId = serviceGroupId
        if let encoded = try? JSONEncoder().encode(rolesArray) {
            self.roles = encoded
        } else {
            self.roles = Data()
        }
        self.publicKey = publicKey
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
