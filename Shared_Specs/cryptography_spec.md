# Cryptography Specification (v1.0)
**Last Updated:** 2026-06-03

This document is the absolute source of truth for **End-to-End Encryption (E2EE)** on **Tier A** surfaces: **iOS, Android, Mac, and Windows**.

**Web-Public** (`Web/`) does **not** implement congregation lockbox crypto or local encrypted databases. It only uses **public** Supabase edge contracts (e.g. invite fingerprinting) documented in `/Databases/` where applicable.

All Tier A apps must use these mathematical primitives so a lockbox encrypted in Swift (iOS or Mac) decrypts identically in Kotlin (Android) and on Windows once the Windows stack is implemented.

## Pioneer / Follower (crypto changes)
- **iOS (Pioneer A):** Defines shared crypto; update this file and `/Databases/*.json` when primitives or lockbox JSON changes.
- **Android:** Follows iOS — no new algorithms.
- **Mac (Pioneer B):** May add desktop-specific packaging; shared math must still match this spec.
- **Windows:** Follows Mac — no new algorithms.

## 1. Cryptographic Primitives
- **Symmetric Encryption:** AES-256-GCM
- **Initialization Vector (IV):** 12 bytes (96 bits) securely and randomly generated for every single encryption.
- **Authentication Tag:** 16 bytes (128 bits) appended to verify ciphertext integrity.
- **Asymmetric Key Pairs:** Elliptic Curve P-256 (prime256v1).
- **Key Exchange:** ECDH (Elliptic Curve Diffie-Hellman) to generate a shared secret between two users.
- **Key Derivation Function (KDF):** HKDF-SHA256 to derive the final 256-bit symmetric AES key from the ECDH shared secret.

### Tier A platform mapping (implementations)
| Surface | APIs (reference) |
|---------|------------------|
| **iOS** | CryptoKit |
| **Mac** | CryptoKit (same algorithms as iOS) |
| **Android** | Android Keystore + `javax.crypto` / Tink-compatible AES-GCM |
| **Windows** | Platform crypto TBD; must produce byte-identical outputs per this spec |

## 2. The JSON Lockbox Payload
When data is encrypted and sent to the Supabase "Bus Station", it MUST match `Databases/lockbox_instruction_schema.json` and be formatted as the following JSON object. All binary data must be Base64 encoded.

```json
{
  "type": "meeting_schedule_update",
  "sender_public_key": "<Base64 encoded P-256 public key of the sender>",
  "iv": "<Base64 encoded 12-byte IV>",
  "ciphertext": "<Base64 encoded encrypted payload>",
  "auth_tag": "<Base64 encoded 16-byte GCM authentication tag>"
}
```

## 3. The Encryption Flow (Sender)
1. Sender retrieves the Recipient's public key from their local database.
2. Sender performs ECDH using their own private key and Recipient's public key to get a shared secret.
3. Sender passes the shared secret through HKDF-SHA256 to derive a 256-bit AES key.
4. Sender generates a random 12-byte IV.
5. Sender encrypts the raw UTF-8 JSON data using AES-256-GCM.
6. Sender packages the ciphertext, IV, auth_tag, and their own public key into the Lockbox JSON.

## 4. The Decryption Flow (Recipient)
1. Recipient receives the Lockbox from Supabase.
2. Recipient reads the `sender_public_key` from the Lockbox.
3. Recipient performs ECDH using their own private key and the Sender's public key to get the shared secret.
4. Recipient passes the shared secret through HKDF-SHA256 to derive the exact same 256-bit AES key.
5. Recipient uses AES-256-GCM with the provided IV and auth_tag to decrypt the ciphertext back into raw JSON data.

## 5. Web-Public boundary
- **Allowed:** HTTPS calls to Supabase edge functions with anon key; public JSON request/response shapes for invites.
- **Forbidden:** Storing decrypted publisher rosters, meeting schedules, or elder directory data in browser storage as part of the product surface.
- If a future public page needs encrypted payloads, the contract must be approved in chat and added under `/Databases/` — it is still not a Tier A local database.
