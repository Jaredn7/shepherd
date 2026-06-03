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

## 2026-06-03 — Stop invite page reload loop

### Session intent
- **Goal:** End Safari cycling “Saving invite / Opening Shepherd”; app must open via `shepherd://` once.
- **Trigger:** Boss — page reloads, app never opens; UL attempt from JS was reloading the page.
- **Status:** complete — pushed to Vercel.

### Context & decisions
- **Decision:** Remove in-page Universal Link navigation entirely; one `sessionStorage` flow flag per code; scheme-only auto-open; no `blur` timer cancel.
- **Reason:** Programmatic UL click navigated to `/i/CODE` → full reload → `run()` again → infinite loop. Apple UL from WhatsApp is OS-level only.
- **Rejected:** Hidden anchor + scheme after 800ms — still caused reloads and cancelled timers on dialog blur.
- **Discussed with user:** Yes — installed app never opened due to loop, not missing welcome package.

### Technical contract
1. **High-Level Summary:** Invite page runs once per code per tab, records click, triggers single `shepherd://` open, 6s store fallback. Reload shows “Tap Open in Shepherd below.”
2. **File Paths:** `Web/assets/invite.js` — simplified open path, `flowStorageKey` guard.
3. **Public Interfaces Exported:** None.
4. **State Mutations:** None server-side.
5. **Cross-Platform Constraints:** Universal Links still work when user taps https invite from WhatsApp **before** Safari loads (iOS + entitlements). Web must not self-navigate to `/i/CODE`.

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

## 2026-06-03 — Fix false “another device” on invite reload

### Session intent
- **Goal:** Stop scary error when the same phone opens the invite twice; explain UL vs web behavior.
- **Trigger:** Boss test — error on web but Open in Shepherd + welcome package still worked.
- **Status:** complete — web pushed; `invite-click` v4 deployed.

### Context & decisions
- **Decision:** Remove `location.replace(/i/CODE)`; `sessionStorage` dedupe; backend same-fingerprint re-click returns 200.
- **Reason:** First load recorded click; universal retry reloaded page and hit `invite-click` again → 410.
- **Discussed with user:** Yes — UL did not fire from in-page nav (Apple same-domain rule); scheme link still worked.

### Technical contract
1. **High-Level Summary:** False “another device” on same phone fixed. UL from WhatsApp is OS-level; in-Safari universal attempt no longer reloads the page.
2. **File Paths:** `Web/assets/invite.js`, `supabase/functions/invite-click/index.ts` (deployed v4).
3. **Public Interfaces Exported:** `invite-click` may return `{ ok: true, already_recorded: true }`.
4. **State Mutations:** Same-device re-click does not change `clicked_at`.
5. **Cross-Platform Constraints:** iOS unchanged.

### Open questions
- None.

## 2026-06-03 — Landing page = install path only (copy + AASA paths)

### Session intent
- **Goal:** Align web with “Safari only when app not installed”; fix AASA for `/i/CODE` links.
- **Trigger:** Same session as iOS installed-app path.
- **Status:** complete — pushed.

### Context & decisions
- **Decision:** AASA paths `["/i", "/i/", "/i/*"]`; page copy says direct open if app installed; web still fingerprint + scheme try + 6s store.
- **Reason:** Elders now share path URLs; web is deferred-install safety net.
- **Discussed with user:** Yes.

### Technical contract
1. **High-Level Summary:** Web explains install-first role; does not replace OS Universal Link for installed users.
2. **File Paths:** `Web/i/index.html`, `Web/assets/invite.js`, `Web/.well-known/apple-app-site-association`.
3. **Public Interfaces Exported:** None.
4. **State Mutations:** None.
5. **Cross-Platform Constraints:** iOS must share `/i/CODE` links (path, not query-only) for reliable AASA.

### Open questions
- None.
