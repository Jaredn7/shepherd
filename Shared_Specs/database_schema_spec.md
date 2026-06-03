# Database Schema Specification
**Last Updated:** 2026-06-03

## Overview
This document defines the strict, unified **local database schema** for Shepherd on **Tier A** surfaces: **iOS, Android, Mac, and Windows**.

Congregation data lives on device (local-first). Supabase holds encrypted lockboxes and public invite/bus traffic only—not a readable global congregation database.

**Web-Public** does **not** host this schema in the browser. Public JSON contracts live in `/Users/jarednaidoo/Documents/Apps/CLMM/Databases/*.json` (three silos: `_metadata`, `field_dictionary`, `example_payload`).

To preserve backward compatibility (e.g. iOS 15), Tier A models must not rely on proprietary-only wrappers (e.g. SwiftData) without a migration plan.

## Tier A storage mapping

| Surface | Local persistence |
|---------|-------------------|
| **iOS** | Programmatic **Core Data** (`NSManagedObject`) — Pioneer A |
| **Mac** | **Core Data** (or equivalent SQLite) — same logical models as iOS; Pioneer B for desktop packaging |
| **Android** | **Room** (SQLite) — follows iOS |
| **Windows** | SQLite-based store TBD — follows Mac |

## Pioneer / Follower (schema changes)
- **iOS:** Defines model changes; update this file and `/Databases/*.json` after user approval (Secretary Protocol).
- **Android:** Replicates iOS schema in Room.
- **Mac:** Replicates iOS schema unless a desktop-only extension is approved.
- **Windows:** Replicates Mac/iOS logical schema on Windows storage.

## Core Models

Authoritative field names and example payloads: see `/Databases/publisher_schema.json`, `service_group_schema.json`, `pending_lockbox_schema.json`, `device_directory_entry_schema.json`, `access_request_schema.json`.

### 1. Publisher
Represents a baptized or unbaptized publisher in the congregation.
- `id` (UUID) - Primary Key
- `firstName` (String)
- `lastName` (String)
- `phoneNumber` (String, Optional)
- `email` (String, Optional)
- `privilegeRaw` (String) - Enum: "Publisher", "MS", "Elder"
- `pioneerStatusRaw` (String) - Enum: "None", "Auxiliary", "Regular", "Special"
- `serviceGroupId` (UUID, Optional)
- `roles` (Data / JSON Array) - Array of string identifiers (e.g., "secretary", "publicTalksCoordinator")
- `publicKey` (String, Optional) - Base64 encoded P-256 public key for E2EE
- `isActive` (Bool)
- `createdAt` (Date)
- `updatedAt` (Date)

### 2. ServiceGroup
Represents a field service group within the congregation.
- `id` (UUID) - Primary Key
- `name` (String)
- `overseerId` (UUID, Optional)
- `assistantIds` (Data / JSON Array) - Array of UUIDs
- `createdAt` (Date)

### 3. PendingLockbox
Represents an incoming encrypted payload that has not yet been processed by the local CryptoManager.
- `id` (UUID) - Primary Key
- `type` (String) - Payload identifier (e.g., "directory_update", "schedule_update")
- `senderPublicKey` (String) - Base64 encoded P-256 public key of the sender
- `iv` (String) - Base64 encoded 12-byte initialization vector (nonce)
- `ciphertext` (String) - Base64 encoded encrypted AES-256-GCM data
- `authTag` (String) - Base64 encoded 16-byte authentication tag
- `receivedAt` (Date)
- `isProcessed` (Bool)
- `remoteId` (UUID, Optional) - Supabase lockboxes row ID for ACK deletion
- `senderDeviceId` (UUID, Optional) - Anonymous sender device shipping label

### 4. DeviceDirectoryEntry
Maps publishers to anonymous device IDs for blind routing.
- `id` (UUID) - Primary Key
- `publisherId` (UUID, Optional)
- `deviceId` (UUID)
- `publicKey` (String)
- `isElder` (Bool)
- `updatedAt` (Date)

### 5. AccessRequest
Local elder queue for publisher onboarding approvals.
- `id` (UUID) - Primary Key
- `requesterDeviceId` (UUID)
- `requesterPublicKey` (String)
- `requestedAt` (Date)
- `statusRaw` (String) - Enum: "pending", "approved", "rejected"

## Supabase (server-side, not local schema)
SQL tables and edge functions are defined under `/supabase/migrations/` and `/supabase/functions/`. They support invite sessions, lockbox relay, and bus inboxes—not replacement of the Tier A models above.
