# iOS Daily Devlog
**Date:** 2026-05-29

## Tier 1 Infrastructure Session

### Supabase Backend
- Applied migration `create_invite_sessions_and_app_config` to remote Shepherd project.
- Deployed 5 edge functions: `bus-fetch`, `bus-send`, `bus-ack`, `invite-record`, `invite-resolve`.
- `lockboxes` table already live from prior session; RLS stays enabled, all client access routed through edge functions with service role.

### iOS — Real Sync (replaces MockNetworkService for production path)
- Created `SupabaseConfig.plist` wired to project `https://zrtinnhwfrygizuagsqz.supabase.co`.
- Built `SupabaseBusService`: fetch-on-open GET, batch POST send (max 100), ACK-delete POST.
- Built `SyncCoordinator`: download → ingest PendingLockbox with `remoteId` → `LockboxProcessor` → ACK.
- Fetch-on-open + pull-to-refresh on `MainTabView`; scenePhase foreground trigger in `RootView`.

### iOS — Lockbox Processing Pipeline
- Built `LockboxProcessor`: decrypt via CryptoManager → apply instruction manual (`INSERT`/`UPDATE`/`DELETE`).
- Supports batch `instructions` arrays (welcome packages), legacy `publishers` arrays, `ACCESS_REQUEST`, `LINKED`, `WIPE_DATABASE`.

### iOS — Device Identity & Directory
- Built `DeviceIdentityManager`: anonymous device UUID in Keychain, onboarding state in UserDefaults.
- Added Core Data models: `DeviceDirectoryEntry`, `AccessRequest`.
- Extended `PendingLockbox` with `remoteId` + `senderDeviceId`.

### iOS — Onboarding Flow
- Built `OnboardingService`: invite resolve, access request send, elder approve + welcome package, elder bootstrap.
- UI: `OnboardingView`, `WaitingForApprovalView`, `ElderAccessRequestsView`, `RootView` state router.
- Elder pilot path: bootstrap elder account → generate invite code → approve publisher → welcome package lockbox.

### Schema Files Added
- `device_directory_entry_schema.json`, `access_request_schema.json`, `lockbox_instruction_schema.json`
- Updated `pending_lockbox_schema.json`, `database_schema_spec.md`

### Notes
- `MockNetworkService.swift` kept for offline crypto pipeline testing; production path uses `SupabaseBusService`.
- xcodebuild unavailable in this environment (Command Line Tools only); compile verification pending on device.

### UI — Liquid Glass Refresh (2026-05-29)
- Added `LiquidGlassChrome.swift`: mesh background, floating tab bar fallback, native nav bar styling.
- iOS 18+: native `TabView` + `Tab` with `.tabBarMinimizeBehavior(.onScrollDown)` for system Liquid Glass tab bar.
- iOS 26+: `.glassEffect()` on cards, buttons, and chrome when SDK available.
- iOS 15–17: custom `FloatingLiquidTabBar` with icon + label pill bar.
- Updated Home, Meetings, Ministry, Congregation, Onboarding screens to `NavigationStack` + mesh background.
- Refreshed `ShepherdTheme.swift` with navy mesh palette + electric blue liquid accent for nav chrome.

### Remove Mock Data (2026-05-29)
- Deleted `MockNetworkService.swift` and unused `ContentView.swift`.
- Home, Meetings, Ministry now show real empty states (`ShepherdEmptyState`) — no fake schedules or events.
- Home greeting uses linked publisher's first name from Core Data (or "Welcome" if none).
- Congregation tab reads live `Publisher` / `ServiceGroup` from Core Data — no hardcoded roster.

### Publisher-first onboarding + congregation broadcast (2026-05-29)
- **`CongregationSyncService`**: elder adds publisher locally, then `INSERT Publisher` lockbox broadcast to every `DeviceDirectoryEntry` (except self) so connected phones get the record before invite.
- **Invite tied to `publisher_id`**: `invite_sessions.publisher_id` migration; `invite-record` / `invite-resolve` return it; `OnboardingService` sends it on access request.
- **Approve flow**: links existing `Publisher` (no placeholder "New Publisher"); elder saves locally; welcome package + `UPDATE` broadcast to other devices.
- **UI**: `AddPublisherSheet` (+ on Congregation), `PublisherDetailView` (status + per-person invite), generic invite removed from `ElderAccessRequestsView`.
- **`AccessRequest.publisherId`** in Core Data + lockbox handler; schema updated in `access_request_schema.json`.

### Pre-approved invite + cloud welcome package (2026-06-05)
- **Invite = approval**: elder `createInviteSession` uploads full welcome package to `invite_sessions.welcome_package`.
- **Single-use link**: landing page sets `clicked_at` + device fingerprint; `invite-resolve` delivers package once then sets `claimed_at`.
- **Auto join**: publisher opens app → fingerprint match → welcome package applied → linked (no waiting for elder).
- **`DEVICE_LINKED` lockbox** notifies elder + broadcasts publisher public key to congregation.
- **`INVITE_HOST`** in SupabaseConfig.plist for shareable invite URLs from publisher profile.

### Invite ack + retry-safe welcome package (2026-06-05)
- **`invite-resolve`** returns welcome package but does not consume it (retry if download interrupted).
- **`invite-ack`** edge function: phone confirms safe local apply → clears `welcome_package`, sets `claimed_at`, marks fingerprint completed.
- iOS `joinWithPreApprovedInvite`: resolve → apply → verify → ack (user can retry until ack succeeds).

### Deep link auto-join + Vercel invite host (2026-06-03)
- **`InviteDeepLinkHandler`**: `shepherd://invite?code=…`, auto `joinWithPreApprovedInvite` on cold start / foreground (fingerprint or code).
- **`AppInfo.plist`**: URL scheme `shepherd`; bundle `app.shepherd.Shepherd`, team `W3TV52BXQ2` (Xcode).
- **`INVITE_HOST`**: `https://shepherd-pi-nine.vercel.app` (iOS plist + Web `config.js`).
- **Root `vercel.json`**: `outputDirectory: Web`, rewrite `/i/:code` → invite page.
- **Web-Public**: JW Library App Store URL as temporary install proxy until Shepherd ships.
