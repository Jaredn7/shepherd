# Engineering Framework: Spec-Driven Development

To successfully build the CLMM App across **Tier A native surfaces** (iOS, Android, Mac, Windows) plus **Web-Public** using AI (LLMs), we employ a strict **"Spec-Driven Development"** framework.

This document prevents **Context Window Collapse** (one model juggling Swift, Kotlin, and desktop stacks at once) and keeps **End-to-End Encryption (E2EE)** compatible everywhere congregation data is stored.

## 1. The Core Problem
If a single LLM writes and debugs every surface in one session, it will hallucinate. If iOS encrypts a payload differently than Android expects, the app crashes and data can be corrupted.

## 2. The Solution: Shared Spec Documents
We maintain central engineering specs in `/Shared_Specs/` and JSON contracts in `/Databases/`. They are the source of truth for:
- Cryptography (`cryptography_spec.md`)
- Local data models (`database_schema_spec.md`, `Databases/*.json`)
- UI tokens (`design_system_spec.md`)

**Tier A** apps must follow these specs exactly. **Web-Public** only implements **public** contracts (invite payloads, marketing pages, config)—not the full encrypted congregation database.

## 3. Surface Tiers

| Tier | Surfaces | Parity expectation |
|------|----------|-------------------|
| **Tier A** | iOS, Android, Mac, Windows | Full feature + crypto + schema parity |
| **Web-Public** | Public website (`Web/`) | URL-facing flows only; may use **React** (or similar) for richer pages over time |

## 4. Pioneer / Follower Chains (Tier A)

We use **two Pioneer lines**, not one generic “web follower” for the full app.

### Pioneer A — iOS (Swift)
- Built first on mobile. Owns foundational mobile architecture (CryptoKit, Core Data, SwiftUI).
- **Rule:** When the iOS agent finalizes a crypto primitive or shared JSON schema, update `/Shared_Specs/` and `/Databases/` before continuing.

### Follower — Android (Kotlin)
- **Follows iOS.** Replicates Pioneer A decisions in Kotlin (Jetpack Compose, Android Keystore, Room).
- Does not invent new architecture; reads Shared Specs and iOS devlogs.

### Pioneer B — Mac (Swift / SwiftUI)
- Owns the **Apple desktop** experience and any Mac-specific UX or OS integrations.
- **Rule:** Same spec-update discipline as iOS when Mac introduces shared contract changes.

### Follower — Windows
- **Follows Mac.** Replicates Pioneer B’s desktop patterns on Windows once the Windows stack is chosen.
- Does not invent cross-platform schema or crypto changes independently.

## 5. Web-Public (Separate Workflow)
- **Not** a Tier A follower for Meetings, Congregation, or Ministry features.
- Builds invite landing, marketing, legal/compliance pages, and other **browser-only** capabilities.
- **Stack:** **React** is the preferred direction for a capable public site (advanced pages, future growth). The exact framework may change as requirements evolve.
- Uses **Supabase edge functions** and public JSON contracts where needed (e.g. `invite-click`). Does **not** implement full E2EE congregation storage in the browser.

## 6. Benefits
1. **No context collapse:** Separate agent sessions per surface (Secretary Protocol locks one surface at a time).
2. **Perfect cryptography on Tier A:** Lockboxes encrypted on iOS decrypt on Android, Mac, and Windows when all follow the same spec.
3. **Native UI:** Each Tier A surface uses OS-appropriate UI (Liquid Glass on Apple, Material on Android, native Windows shell when defined).
4. **Clear public boundary:** Web-Public never becomes a shadow “fifth full app” by accident.

## 7. Backend
- **Supabase** is the current backend: SQL migrations, edge functions (bus, invites), and config.
- Tier A devices sync via the encrypted **bus station** model documented in `02_Database_and_Security.md`.
