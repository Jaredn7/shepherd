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
