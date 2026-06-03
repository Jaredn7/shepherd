//
//  PendingLockbox.swift
//  Shepherd
//
//  Core Data model representing an incoming encrypted message
//  (lockbox) that has not yet been decrypted and processed.
//

import Foundation
import CoreData

// MARK: - PendingLockbox Model

/// An encrypted message received from another publisher or the backend.
///
/// A pending lockbox stores all the AES-256-GCM components needed to
/// decrypt the payload once the recipient's `CryptoManager` processes it.
/// After successful decryption and handling, `isProcessed` is set to `true`.
@objc(PendingLockbox)
public class PendingLockbox: NSManagedObject {

    // MARK: Primary Key

    /// Unique identifier for this lockbox.
    @NSManaged public var id: UUID

    // MARK: Metadata

    /// The type of payload contained in this lockbox.
    ///
    /// Examples:
    /// - `"directory_update"` — updated publisher directory
    /// - `"schedule_update"` — midweek/weekend meeting schedule
    /// - `"field_service_report"` — monthly service report
    @NSManaged public var type: String

    /// The sender's Base64-encoded P-256 public key.
    ///
    /// Used to derive the shared secret for decryption via ECDH
    /// key agreement in `CryptoManager`.
    @NSManaged public var senderPublicKey: String

    // MARK: Encrypted Payload (AES-256-GCM Components)

    /// The 12-byte initialisation vector (nonce), Base64-encoded.
    @NSManaged public var iv: String

    /// The encrypted payload data, Base64-encoded.
    @NSManaged public var ciphertext: String

    /// The 16-byte GCM authentication tag, Base64-encoded.
    @NSManaged public var authTag: String

    // MARK: Status

    /// The date and time this lockbox was received.
    @NSManaged public var receivedAt: Date

    /// Whether this lockbox has been successfully decrypted and processed.
    @NSManaged public var isProcessed: Bool

    /// Supabase row ID used for ACK deletion after successful processing.
    @NSManaged public var remoteId: UUID?

    /// Anonymous sender device UUID from the shipping label.
    @NSManaged public var senderDeviceId: UUID?

    // MARK: Convenience

    /// Converts this stored lockbox into a `SealedLockbox` for decryption.
    var sealedLockbox: SealedLockbox {
        SealedLockbox(iv: iv, ciphertext: ciphertext, authTag: authTag)
    }

    // MARK: Initialiser

    /// Creates a new `PendingLockbox` instance.
    ///
    /// - Parameters:
    ///   - context: The Core Data managed object context.
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - type: The payload type string.
    ///   - senderPublicKey: The sender's Base64 P-256 public key.
    ///   - iv: The Base64-encoded 12-byte AES-GCM nonce.
    ///   - ciphertext: The Base64-encoded encrypted data.
    ///   - authTag: The Base64-encoded 16-byte GCM authentication tag.
    ///   - receivedAt: Timestamp of receipt (default: now).
    ///   - isProcessed: Processing status (default: `false`).
    ///   - remoteId: Supabase lockbox row ID (optional).
    ///   - senderDeviceId: Anonymous sender device UUID (optional).
    @nonobjc public convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        type: String,
        senderPublicKey: String,
        iv: String,
        ciphertext: String,
        authTag: String,
        receivedAt: Date = .now,
        isProcessed: Bool = false,
        remoteId: UUID? = nil,
        senderDeviceId: UUID? = nil
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "PendingLockbox", in: context)!
        self.init(entity: entity, insertInto: context)
        self.id = id
        self.type = type
        self.senderPublicKey = senderPublicKey
        self.iv = iv
        self.ciphertext = ciphertext
        self.authTag = authTag
        self.receivedAt = receivedAt
        self.isProcessed = isProcessed
        self.remoteId = remoteId
        self.senderDeviceId = senderDeviceId
    }
}
