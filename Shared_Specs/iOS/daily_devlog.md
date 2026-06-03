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

### Universal Links + invite URL handling (2026-06-03)
- **`Shepherd.entitlements`**: `applinks:shepherd-pi-nine.vercel.app`.
- **`InviteDeepLinkHandler`**: parses `https://…/i/{code}` and `?code=`; calls `recordInviteClick` then auto-join.
- **`OnboardingService.recordInviteClick`**: mirrors web `invite-click` when app opens from Universal Link.

### Log out (2026-06-03)
- **`SessionService.logout()`**: batch-deletes Core Data, `resetOnboarding`, regenerates crypto keys, clears invite auto-join state.
- **Home** toolbar + **Waiting for approval** screen: Log Out with confirmation → returns to onboarding.

## 2026-06-03 — Installed-app path: Universal Link first

### Session intent
- **Goal:** App installed → tap invite → open Shepherd with code → welcome package; Safari landing only for install-later.
- **Trigger:** Boss approved product split (Path 1 deferred vs Path 2 direct).
- **Status:** complete — **rebuild required on device**.

### Context & decisions
- **Decision:** Elder shares `https://host/i/CODE` (path URL); `onContinueUserActivity` + `onOpenURL`; app `recordInviteClick` + join; deferred fingerprint join only when no URL.
- **Reason:** Query-only `/i/?code=` did not match AASA `/i/*`; in-page UL navigation caused Safari loops.
- **Rejected:** Website auto-open for installed users — cannot detect install from web; OS Universal Link is the correct gate.
- **Discussed with user:** Yes — fingerprint is for App Store path, not when app already on phone.

### Technical contract
1. **High-Level Summary:** WhatsApp tap with app installed should skip Safari. App claims invite in-app. Web remains install + fingerprint + 6s store fallback.
2. **File Paths:** `OnboardingService.inviteURL`, `InviteDeepLinkHandler.swift`, `ShepherdApp.swift`, `RootView.swift`, `Web/.well-known/apple-app-site-association`.
3. **Public Interfaces Exported:** `inviteURL(for:)` → `https://{inviteHost}/i/{CODE}`; `attemptDeferredFingerprintJoinIfNeeded`.
4. **State Mutations:** Fresh user opening `https://…/i/CODE` → linked after welcome package (same as before, entry is app not Safari).
5. **Cross-Platform Constraints:** **Web-Public:** landing copy clarifies install-only role. **Android:** needs `assetlinks.json` for parallel direct-open later.

### Open questions
- Boss must reinstall from Xcode after entitlements change.

## 2026-06-03 — Fix EXC_BREAKPOINT on publisher detail link status

### Session intent
- **Goal:** Stop crash when opening publisher detail (`isDeviceLinked` line).
- **Trigger:** Runtime `EXC_BREAKPOINT` on `CongregationSyncService.shared.isDeviceLinked` from `PublisherDetailView.linkStatus`.
- **Status:** complete.

### Context & decisions
- **Decision:** Read `DeviceDirectoryEntry` via view `managedObjectContext` in `PublisherDetailView`; same for `ElderAccessRequestsView.publisherTitle`.
- **Reason:** `CongregationSyncService` is `@MainActor`; SwiftUI computed properties are not — cross-actor call traps at runtime.
- **Rejected:** Removing `@MainActor` from entire sync service — async bus paths still need main isolation.

### Technical contract
1. **High-Level Summary:** Publisher detail and elder requests list no longer call `@MainActor` service from synchronous view code.
2. **File Paths:** `PublisherDetailView.swift`, `ElderAccessRequestsView.swift`.
3. **Public Interfaces Exported:** `deviceLinkExists(for:)` private helper on detail view only.
4. **State Mutations:** None.
5. **Cross-Platform Constraints:** Pattern for Tier A: do not call `@MainActor` singletons from SwiftUI computed `var` bodies — use `@Environment` context or `.task` on MainActor.

## 2026-06-03 — Universal Link reliability (AppDelegate + developer mode)

### Session intent
- **Goal:** Tap invite link opens Shepherd when app is installed (Xcode/dev builds included).
- **Trigger:** Boss — link opens Safari only; app never launches.
- **Status:** complete — rebuild iOS; wait for AASA CDN; verify Apple Developer Associated Domains on App ID.

### Context & decisions
- **Decision:** `AppDelegate` for `continue userActivity` + `open url`; `applinks:…?mode=developer` entitlement; modern AASA `components`; web always retries `shepherd://` even if fingerprint already saved.
- **Reason:** SwiftUI-only UL handlers miss some deliveries; dev builds need developer associated domain; `flowStorageKey` skipped scheme retry on reload.
- **Rejected:** In-page Universal Link navigation (reload loop).

### Technical contract
1. **High-Level Summary:** OS should open app from WhatsApp https link; Safari fallback always attempts scheme + manual link.
2. **File Paths:** `AppDelegate.swift`, `ShepherdApp.swift`, `Shepherd.entitlements`, `Web/.well-known/apple-app-site-association`, `Web/assets/invite.js`.
3. **Public Interfaces Exported:** `AppDelegate` UIApplicationDelegate methods.
4. **State Mutations:** None.
5. **Cross-Platform Constraints:** Enable **Associated Domains** on App ID `app.shepherd.Shepherd` in Apple Developer portal if still failing after rebuild.

### Open questions
- Confirm portal capability + delete/reinstall app after entitlement change.
