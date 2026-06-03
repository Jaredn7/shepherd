# Web-Public Daily Devlog
**Date:** 2026-06-05

## Invite landing page (`web/`)

- Added static invite landing at `web/i/index.html` — Shepherd dark mesh UI, fingerprint capture, app open attempt, store fallback.
- Added `web/assets/invite.js` + `invite.css`, `config.js` / `config.example.js`, GitHub Pages `404.html` for `/i/{code}` pretty URLs.
- Added `.well-known/apple-app-site-association` template for future Universal Links.
- Added Supabase edge function `invite-click` — records publisher click fingerprint on `invite_sessions` (deployed v1, verify_jwt off).
- README in `web/` covers deploy, config, and GitHub Pages setup.

## Pre-approved invite flow (2026-06-05)

- Landing page `invite-click` binds first device fingerprint (`clicked_at`); second click → 410.
- Elder `invite-record` uploads `welcome_package` JSON at link creation (invite = approval).
- `invite-resolve` returns welcome package once; sets `claimed_at` (single use).
- iOS publisher onboarding applies welcome package immediately — no elder approve step.
- Publisher notifies elder via `DEVICE_LINKED` lockbox after join.

## 2026-06-03 — Cancel App Store redirect when Shepherd opens

### Session intent
- **Goal:** If the publisher already has Shepherd and taps **Open** on the iOS “Open in Shepherd?” sheet, do not also send them to the JW Library App Store proxy.
- **Trigger:** Boss report — invite flow works; Safari still redirects to App Store ~2.5s after successful app open.
- **Status:** complete — Web-Public fix only; redeploy via GitHub → Vercel.

### Context & decisions
- **Decision:** Cancel the store fallback timer when the page goes to background (`visibilitychange`, `pagehide`, `blur`).
- **Reason:** `storeRedirect` always fired after `redirectDelayMs` even when `shepherd://` succeeded; iOS hides Safari when the native app opens.
- **Rejected:** Removing the store fallback entirely — still needed when Shepherd is not installed and the user stays on the landing page.
- **Rejected:** `document.hasFocus()` only — unreliable on iOS when the system sheet is showing.
- **Discussed with user:** Yes — JW Library remains the install proxy only when the app is missing; installed app must not trigger store navigation.

### Technical contract
1. **High-Level Summary:** Invite landing still records fingerprint and tries `shepherd://`, but the App Store redirect runs only if the user remains on the page after the delay. **Plus:** manual “Open in Shepherd” link cancels any pending store redirect; Universal Link retry on iOS also skips if the page is already hidden.
2. **File Paths:**
   - `Web/assets/invite.js` — added `cancelPendingRedirects`, `installRedirectCancellation`, `scheduleStoreRedirectIfStillOnPage`; guarded iOS universal fallback and manual link click.
3. **Public Interfaces Exported:** None (static client script). Behavior: store redirect conditional on `!document.hidden` at timer fire.
4. **State Mutations:** None server-side. **Before → after:** User with app installed saw Safari jump to App Store after open. **After:** Safari stays put or goes to background without store redirect.
5. **Cross-Platform Constraints:**
   - **iOS / Android / Mac / Windows:** No app changes required — still handle `shepherd://invite?code=…` and fingerprint resolve as before.
   - **Web-Public:** Android follower must keep the same cancel-on-hidden pattern when copying `invite.js`, because otherwise installed-app users on Android would hit Play Store incorrectly.

### Implementation notes
- Timers cleared on `visibilitychange` (hidden), `pagehide`, and `blur`.
- **Verification:** Boss to retest on two iPhones — open invite in WhatsApp → **Open** on system dialog → Shepherd only, no JW Library store.
- **Friction:** None.

### Open questions
- None.

## 2026-06-03 — Universal Links open order + 6s store delay

### Session intent
- **Goal:** Prefer Universal Links on iOS (no scheme sheet when possible); wait **6 seconds** before App Store proxy.
- **Trigger:** Boss — 2.5s too short; enable full Universal Link path.
- **Status:** complete — Web deployed via push; iOS requires rebuild/install on device.

### Context & decisions
- **Decision:** iOS tries `https://…/i/{code}` first, `shepherd://` after 800ms if still on page; store redirect at **6000ms**.
- **Reason:** Apple shows “Open in app?” for custom schemes; Universal Links open installed apps without that sheet when tapping from external apps.
- **Rejected:** Removing scheme entirely — same-domain Safari navigation often cannot UL-open; scheme remains fallback.
- **Discussed with user:** Yes — six seconds; do Universal Links; high-level enablement list for boss.

### Technical contract
1. **High-Level Summary:** Store fallback is now six seconds. iOS invite open tries Universal Link URL before custom scheme. **iOS app** gains Associated Domains + https invite URL handling (records `invite-click` when opened directly from link).
2. **File Paths:**
   - `Web/config.js`, `Web/config.example.js` — `redirectDelayMs: 6000`.
   - `Web/assets/invite.js` — Universal-first `tryOpenApp`, default delay 6000.
   - `iOS/Shepherd/Shepherd/Shepherd.entitlements` — `applinks:shepherd-pi-nine.vercel.app`.
   - `iOS/Shepherd/Shepherd.xcodeproj/project.pbxproj` — `CODE_SIGN_ENTITLEMENTS`.
   - `iOS/.../InviteDeepLinkHandler.swift` — parse https `/i/` URLs; `recordInviteClick` before join.
   - `iOS/.../OnboardingService.swift` — `recordInviteClick(inviteCode:)`.
3. **Public Interfaces Exported:** `OnboardingService.recordInviteClick(inviteCode: String) async throws`.
4. **State Mutations:** None server schema. **Before → after:** Longer wait before JW Library redirect; WhatsApp tap with app installed may open Shepherd directly without Safari sheet.
5. **Cross-Platform Constraints:**
   - **iOS:** Must rebuild with entitlements; `INVITE_HOST` must match AASA host (`shepherd-pi-nine.vercel.app`).
   - **Web-Public:** `Web/.well-known/apple-app-site-association` must stay served as JSON on deploy.
   - **Android/Mac/Windows:** No change until followers add `assetlinks.json` / platform UL equivalents.

### Implementation notes
- **Verification:** Reinstall Shepherd from Xcode; tap invite from WhatsApp (not Safari address bar).
- **Friction:** Universal Links from a page already on the same domain may not hand off to the app — scheme fallback still applies.

### Open questions
- None.
