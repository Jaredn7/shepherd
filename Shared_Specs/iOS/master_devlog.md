# iOS Master Devlog

*This file contains the comprehensive, finalized log of all architectural changes and features added to the iOS app, separated by day. It is updated at the end of each coding session from the `daily_devlog.md`, filtering out iteration noise.*

## [2026-05-28] - Initialization & Phase 1-3 Completion

**1. Project Setup:**
- Initialized Xcode project `Shepherd` using SwiftUI. Target set to iOS 15+ for maximum backward compatibility.

**2. Core Sync & Cryptography Engine (`CryptoManager.swift`):**
- Implemented full End-to-End Encryption (E2EE) using Apple CryptoKit.
- Established P-256 Elliptic Curve key pairs, stored securely in the Keychain.
- Implemented ECDH key agreement to derive shared secrets.
- Implemented AES-256-GCM encryption/decryption using HKDF-SHA256 derived keys.
- Created `MockNetworkService` to simulate receiving encrypted JSON lockboxes from a Supabase backend.

**3. Database Schema (Core Data):**
- Pivoted from SwiftData to programmatic Core Data (`NSManagedObjectModel`) to support older iPhones.
- Defined three core models:
  - `Publisher`: Represents a congregation member. Includes string raw values for Enums (`privilege`, `pioneerStatus`).
  - `ServiceGroup`: Represents field service groups.
  - `PendingLockbox`: Represents raw encrypted payloads waiting for ECDH decryption.

**4. UI & UX (VibeMove Aesthetic):**
- Built out the 4-tab shell (`MainTabView`) with a custom floating capsule tab bar (native tab bar hidden).
- Implemented the "Liquid VibeMove" aesthetic: Dark Slate background (`#16181A`), matte card surfaces with frosted glass (`.ultraThinMaterial`), Coral Orange active accents (`#FF5D47`), and Olive Green toggle accents (`#4D6356`).
- Integrated Apple System Serif fonts for primary headers to give an editorial feel.
- Redesigned `CongregationView.swift` with custom animated segmented controls and squircle avatars.
