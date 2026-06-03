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
