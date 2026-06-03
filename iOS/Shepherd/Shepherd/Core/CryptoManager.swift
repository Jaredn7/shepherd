//
//  CryptoManager.swift
//  Shepherd
//
//  End-to-End Encryption manager using Apple CryptoKit.
//
//  Cryptographic Flow:
//  ┌──────────────────────────────────────────────────────────────────────┐
//  │ 1. Each device generates a P-256 elliptic curve key pair on first   │
//  │    launch. The private key is stored in the Keychain; the public    │
//  │    key is shared with other publishers via Supabase.                │
//  │                                                                    │
//  │ 2. To send an encrypted "lockbox" to another publisher:            │
//  │    a. Perform ECDH key agreement using our private key and the     │
//  │       recipient's public key → shared secret                       │
//  │    b. Derive a 256-bit AES key from the shared secret using        │
//  │       HKDF-SHA256 with an app-specific info string                 │
//  │    c. Encrypt the JSON payload with AES-256-GCM (12-byte nonce,    │
//  │       16-byte authentication tag)                                  │
//  │                                                                    │
//  │ 3. To decrypt an incoming lockbox:                                 │
//  │    a. Perform ECDH key agreement using our private key and the     │
//  │       sender's public key → same shared secret                     │
//  │    b. Derive the same AES key via HKDF-SHA256                      │
//  │    c. Decrypt and authenticate the ciphertext with AES-256-GCM     │
//  └──────────────────────────────────────────────────────────────────────┘
//

import Foundation
import CryptoKit
import Security

// MARK: - CryptoManager Errors

/// Errors that can occur during cryptographic operations.
enum CryptoManagerError: LocalizedError {
    case keychainSaveFailed(OSStatus)
    case keychainLoadFailed
    case keychainDeleteFailed(OSStatus)
    case invalidPublicKeyData
    case encryptionFailed(Error)
    case decryptionFailed(Error)
    case serializationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .keychainSaveFailed(let status):
            return "Failed to save private key to Keychain (OSStatus: \(status))."
        case .keychainLoadFailed:
            return "Failed to load private key from Keychain."
        case .keychainDeleteFailed(let status):
            return "Failed to delete private key from Keychain (OSStatus: \(status))."
        case .invalidPublicKeyData:
            return "The provided public key data is not a valid P-256 public key."
        case .encryptionFailed(let error):
            return "Encryption failed: \(error.localizedDescription)"
        case .decryptionFailed(let error):
            return "Decryption failed: \(error.localizedDescription)"
        case .serializationFailed(let error):
            return "JSON serialization failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Sealed Lockbox

/// An encrypted payload containing all components needed for decryption.
///
/// The lockbox bundles the AES-GCM nonce (IV), ciphertext, and authentication
/// tag together. All fields are Base64-encoded for safe transport over JSON.
struct SealedLockbox: Codable {
    /// 12-byte initialisation vector, Base64-encoded.
    let iv: String
    /// The encrypted payload, Base64-encoded.
    let ciphertext: String
    /// 16-byte GCM authentication tag, Base64-encoded.
    let authTag: String

    /// Reconstructs a `ChaChaPoly.SealedBox`-equivalent from the stored components.
    func aesGCMSealedBox() throws -> AES.GCM.SealedBox {
        guard let nonceData = Data(base64Encoded: iv),
              let ciphertextData = Data(base64Encoded: ciphertext),
              let tagData = Data(base64Encoded: authTag) else {
            throw CryptoManagerError.decryptionFailed(
                NSError(domain: "SealedLockbox", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid Base64 in lockbox components."])
            )
        }
        let nonce = try AES.GCM.Nonce(data: nonceData)
        return try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertextData, tag: tagData)
    }
}

// MARK: - CryptoManager

/// A singleton responsible for all end-to-end encryption operations.
///
/// `CryptoManager` generates and persists a P-256 key pair, performs ECDH key
/// exchange, derives symmetric AES-256 keys via HKDF, and encrypts/decrypts
/// JSON payloads using AES-256-GCM.
///
/// Usage:
/// ```swift
/// let manager = CryptoManager.shared
/// let myPublicKey = try manager.publicKeyBase64()
///
/// // Encrypt
/// let lockbox = try manager.encrypt(
///     jsonObject: ["name": "John"],
///     forRecipientPublicKey: recipientBase64Key
/// )
///
/// // Decrypt
/// let data = try manager.decrypt(
///     lockbox: lockbox,
///     senderPublicKey: senderBase64Key
/// )
/// ```
final class CryptoManager {

    // MARK: Singleton

    /// The shared singleton instance.
    static let shared = CryptoManager()

    // MARK: Constants

    /// Keychain service identifier for the device's private key.
    private static let keychainService = "com.shepherd.crypto"

    /// Keychain account identifier for the device's private key.
    private static let keychainAccount = "device-p256-private-key"

    /// The info string used during HKDF key derivation.
    /// This binds the derived key to our application's context,
    /// preventing key reuse across different protocols.
    private static let hkdfInfo = "Shepherd-E2E-AES256-Key".data(using: .utf8)!

    /// The salt used during HKDF key derivation.
    /// Using a fixed, app-specific salt ensures deterministic key derivation
    /// from the same shared secret. In production, you may rotate this.
    private static let hkdfSalt = "Shepherd-HKDF-Salt-v1".data(using: .utf8)!

    // MARK: Stored Properties

    /// The device's P-256 private key, lazily loaded from the Keychain
    /// or generated on first access.
    private var privateKey: P256.KeyAgreement.PrivateKey

    // MARK: Initialisation

    /// Private initialiser enforcing singleton usage.
    ///
    /// On first launch, a new P-256 key pair is generated and the private
    /// key is persisted to the Keychain. On subsequent launches, the
    /// existing private key is loaded from the Keychain.
    private init() {
        if let existingKey = CryptoManager.loadPrivateKeyFromKeychain() {
            self.privateKey = existingKey
        } else {
            // First launch: generate a fresh P-256 key pair.
            let newKey = P256.KeyAgreement.PrivateKey()
            self.privateKey = newKey
            try? CryptoManager.savePrivateKeyToKeychain(newKey)
        }
    }

    // MARK: - Public Key Export / Import

    /// Returns this device's public key as a Base64-encoded string.
    ///
    /// The exported key uses the X9.63 compressed representation,
    /// which is the standard format for P-256 public keys (65 bytes
    /// uncompressed: 0x04 || x || y).
    ///
    /// - Returns: A Base64 string representing the P-256 public key.
    func publicKeyBase64() -> String {
        return privateKey.publicKey.x963Representation.base64EncodedString()
    }

    /// Returns this device's P-256 public key.
    func publicKey() -> P256.KeyAgreement.PublicKey {
        return privateKey.publicKey
    }

    /// Imports a P-256 public key from a Base64-encoded string.
    ///
    /// - Parameter base64String: The Base64-encoded X9.63 representation.
    /// - Returns: The reconstructed `P256.KeyAgreement.PublicKey`.
    /// - Throws: `CryptoManagerError.invalidPublicKeyData` if decoding fails.
    static func importPublicKey(from base64String: String) throws -> P256.KeyAgreement.PublicKey {
        guard let keyData = Data(base64Encoded: base64String) else {
            throw CryptoManagerError.invalidPublicKeyData
        }
        do {
            return try P256.KeyAgreement.PublicKey(x963Representation: keyData)
        } catch {
            throw CryptoManagerError.invalidPublicKeyData
        }
    }

    // MARK: - Encryption

    /// Encrypts a JSON-serialisable dictionary for a specific recipient.
    ///
    /// Cryptographic steps:
    /// 1. Serialise `jsonObject` to UTF-8 JSON data.
    /// 2. Import the recipient's public key from Base64.
    /// 3. Perform ECDH key agreement → shared secret.
    /// 4. Derive a 256-bit symmetric key using HKDF-SHA256.
    /// 5. Encrypt the JSON data using AES-256-GCM with a random 12-byte nonce.
    /// 6. Return the nonce, ciphertext, and auth tag as a `SealedLockbox`.
    ///
    /// - Parameters:
    ///   - jsonObject: A dictionary that can be serialised to JSON.
    ///   - recipientPublicKeyBase64: The recipient's Base64-encoded P-256 public key.
    /// - Returns: A `SealedLockbox` containing the encrypted components.
    /// - Throws: `CryptoManagerError` if serialisation, key import, or encryption fails.
    func encrypt(
        jsonObject: [String: Any],
        forRecipientPublicKey recipientPublicKeyBase64: String
    ) throws -> SealedLockbox {
        // Step 1: Serialise the JSON payload.
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys])
        } catch {
            throw CryptoManagerError.serializationFailed(error)
        }

        // Step 2: Import the recipient's public key.
        let recipientPublicKey = try CryptoManager.importPublicKey(from: recipientPublicKeyBase64)

        // Step 3: Derive the shared symmetric key via ECDH + HKDF.
        let symmetricKey = try deriveSymmetricKey(with: recipientPublicKey)

        // Step 4: Encrypt with AES-256-GCM.
        do {
            let sealedBox = try AES.GCM.seal(jsonData, using: symmetricKey)

            // The sealed box contains:
            //   - nonce:      12 bytes (IV)
            //   - ciphertext: same length as plaintext
            //   - tag:        16 bytes (authentication tag)
            return SealedLockbox(
                iv: sealedBox.nonce.withUnsafeBytes { Data($0) }.base64EncodedString(),
                ciphertext: sealedBox.ciphertext.base64EncodedString(),
                authTag: sealedBox.tag.base64EncodedString()
            )
        } catch {
            throw CryptoManagerError.encryptionFailed(error)
        }
    }

    /// Encrypts raw `Data` for a specific recipient.
    ///
    /// - Parameters:
    ///   - data: The plaintext data to encrypt.
    ///   - recipientPublicKeyBase64: The recipient's Base64-encoded P-256 public key.
    /// - Returns: A `SealedLockbox` containing the encrypted components.
    /// - Throws: `CryptoManagerError` on failure.
    func encrypt(
        data: Data,
        forRecipientPublicKey recipientPublicKeyBase64: String
    ) throws -> SealedLockbox {
        let recipientPublicKey = try CryptoManager.importPublicKey(from: recipientPublicKeyBase64)
        let symmetricKey = try deriveSymmetricKey(with: recipientPublicKey)

        do {
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
            return SealedLockbox(
                iv: sealedBox.nonce.withUnsafeBytes { Data($0) }.base64EncodedString(),
                ciphertext: sealedBox.ciphertext.base64EncodedString(),
                authTag: sealedBox.tag.base64EncodedString()
            )
        } catch {
            throw CryptoManagerError.encryptionFailed(error)
        }
    }

    // MARK: - Decryption

    /// Decrypts an incoming `SealedLockbox` from a known sender.
    ///
    /// Cryptographic steps:
    /// 1. Import the sender's public key from Base64.
    /// 2. Perform ECDH key agreement → shared secret (same as encryption).
    /// 3. Derive the same 256-bit symmetric key via HKDF-SHA256.
    /// 4. Reconstruct the AES-GCM sealed box from IV, ciphertext, and tag.
    /// 5. Decrypt and verify the authentication tag.
    ///
    /// - Parameters:
    ///   - lockbox: The `SealedLockbox` received from the sender.
    ///   - senderPublicKeyBase64: The sender's Base64-encoded P-256 public key.
    /// - Returns: The decrypted plaintext `Data`.
    /// - Throws: `CryptoManagerError` if key import, reconstruction, or decryption fails.
    func decrypt(
        lockbox: SealedLockbox,
        senderPublicKey senderPublicKeyBase64: String
    ) throws -> Data {
        // Step 1: Import the sender's public key.
        let senderKey = try CryptoManager.importPublicKey(from: senderPublicKeyBase64)

        // Step 2: Derive the same shared symmetric key.
        let symmetricKey = try deriveSymmetricKey(with: senderKey)

        // Step 3: Reconstruct the sealed box and decrypt.
        do {
            let sealedBox = try lockbox.aesGCMSealedBox()
            return try AES.GCM.open(sealedBox, using: symmetricKey)
        } catch {
            throw CryptoManagerError.decryptionFailed(error)
        }
    }

    /// Decrypts an incoming lockbox and deserialises the result as a JSON dictionary.
    ///
    /// - Parameters:
    ///   - lockbox: The `SealedLockbox` received from the sender.
    ///   - senderPublicKeyBase64: The sender's Base64-encoded P-256 public key.
    /// - Returns: A `[String: Any]` dictionary parsed from the decrypted JSON.
    /// - Throws: `CryptoManagerError` on decryption or deserialisation failure.
    func decryptJSON(
        lockbox: SealedLockbox,
        senderPublicKey senderPublicKeyBase64: String
    ) throws -> [String: Any] {
        let data = try decrypt(lockbox: lockbox, senderPublicKey: senderPublicKeyBase64)
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NSError(domain: "CryptoManager", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Decrypted data is not a JSON dictionary."])
            }
            return json
        } catch {
            throw CryptoManagerError.serializationFailed(error)
        }
    }

    // MARK: - Key Derivation (Private)

    /// Performs ECDH key agreement and derives a 256-bit AES symmetric key.
    ///
    /// 1. Compute the ECDH shared secret between our private key and
    ///    the other party's public key.
    /// 2. Use HKDF-SHA256 with a fixed salt and app-specific info string
    ///    to stretch the shared secret into a 256-bit key suitable for
    ///    AES-256-GCM.
    ///
    /// The same shared secret (and therefore the same derived key) is
    /// produced regardless of which party initiates the exchange, because
    /// ECDH is commutative: `a·B == b·A`.
    ///
    /// - Parameter peerPublicKey: The other party's P-256 public key.
    /// - Returns: A `SymmetricKey` of 256 bits.
    /// - Throws: If the key agreement fails.
    private func deriveSymmetricKey(
        with peerPublicKey: P256.KeyAgreement.PublicKey
    ) throws -> SymmetricKey {
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)

        // HKDF (HMAC-based Key Derivation Function) with SHA-256:
        //   - Salt: fixed app-specific salt (provides domain separation)
        //   - Info: application context string (binds key to this protocol)
        //   - Output length: 256 bits (32 bytes) for AES-256
        let derivedKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: CryptoManager.hkdfSalt,
            sharedInfo: CryptoManager.hkdfInfo,
            outputByteCount: 32 // 256 bits
        )

        return derivedKey
    }

    // MARK: - Key Regeneration

    /// Generates a new P-256 key pair and replaces the existing one.
    ///
    /// This should be called when a user wants to rotate their keys,
    /// e.g. after a device compromise. The new public key must be
    /// re-distributed to all contacts.
    ///
    /// - Throws: `CryptoManagerError.keychainSaveFailed` if saving fails.
    func regenerateKeyPair() throws {
        let newKey = P256.KeyAgreement.PrivateKey()
        try CryptoManager.deletePrivateKeyFromKeychain()
        try CryptoManager.savePrivateKeyToKeychain(newKey)
        self.privateKey = newKey
    }

    // MARK: - Keychain Operations (Private)

    /// Saves a P-256 private key to the Keychain.
    ///
    /// The key is stored as its raw 32-byte representation using
    /// `kSecClassGenericPassword` with a dedicated service/account pair.
    ///
    /// - Parameter key: The private key to persist.
    /// - Throws: `CryptoManagerError.keychainSaveFailed` on failure.
    private static func savePrivateKeyToKeychain(_ key: P256.KeyAgreement.PrivateKey) throws {
        let keyData = key.rawRepresentation

        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  keychainService,
            kSecAttrAccount as String:  keychainAccount,
            kSecValueData as String:    keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw CryptoManagerError.keychainSaveFailed(status)
        }
    }

    /// Loads the P-256 private key from the Keychain.
    ///
    /// - Returns: The reconstructed private key, or `nil` if not found.
    private static func loadPrivateKeyFromKeychain() -> P256.KeyAgreement.PrivateKey? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  keychainService,
            kSecAttrAccount as String:  keychainAccount,
            kSecReturnData as String:   true,
            kSecMatchLimit as String:   kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let keyData = result as? Data else {
            return nil
        }

        return try? P256.KeyAgreement.PrivateKey(rawRepresentation: keyData)
    }

    /// Deletes the stored private key from the Keychain.
    ///
    /// - Throws: `CryptoManagerError.keychainDeleteFailed` if deletion fails
    ///   (ignores `errSecItemNotFound`).
    private static func deletePrivateKeyFromKeychain() throws {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  keychainService,
            kSecAttrAccount as String:  keychainAccount
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CryptoManagerError.keychainDeleteFailed(status)
        }
    }
}
