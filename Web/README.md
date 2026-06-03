# Shepherd — Web-Public (invite & public URLs)

Static web pages for deferred deep-link onboarding and other **public-domain** needs. This folder is **not** the full Shepherd app (no Meetings, Congregation, or Ministry UI here).

Desktop/laptop users get the **Mac** and **Windows** Tier A apps for full functionality.

Host this folder on your domain (e.g. GitHub Pages or any static file host).

## URL format

| URL | Works on |
|-----|----------|
| `https://your-domain/i/?code=ABC12345` | All static hosts |
| `https://your-domain/i/ABC12345` | Requires `404.html` (included for GitHub Pages) |

The elder app should share links in the first format until Universal Links are configured.

## Setup

1. Copy `config.example.js` → `config.js` (or edit the included `config.js`).
2. Set `inviteHost` to your public URL (e.g. `https://join.yourdomain.com`).
3. Set real `appStoreUrl` / `playStoreUrl` when listings exist (Mac/Windows store URLs when those apps ship).
4. Deploy the Supabase edge function **`invite-click`** (see below).
5. Upload this `Web/` folder to your static host.

## What the page does

1. Reads the invite code from the path or query string.
2. Collects a device fingerprint (OS, screen size, user agent, timezone).
3. `POST`s to Supabase `invite-click` → records the publisher click on `invite_sessions`.
4. Tries to open the app (`shepherd://invite?code=…`).
5. After ~2.5s, redirects to the App Store (iOS) or Play Store (Android).

When the publisher installs and opens Shepherd, `invite-resolve` downloads the welcome package (retry-safe until ack). The app calls **`invite-ack`** after confirming the package applied locally; only then is the cloud copy deleted.

## Supabase: deploy `invite-click`

From the repo root (with Supabase CLI logged in):

```bash
supabase functions deploy invite-click --project-ref zrtinnhwfrygizuagsqz --no-verify-jwt
```

Or deploy via the Supabase dashboard. The function lives at:

`supabase/functions/invite-click/index.ts`

Use **`--no-verify-jwt`** (same as the other Shepherd bus functions) so the static page can call it with the anon key.

## GitHub Pages

1. Enable Pages for this repo (root or `/Web` folder depending on your layout).
2. If serving from repo root, copy `Web/*` to root or set Pages source to `/Web`.
3. Custom domain → your `inviteHost` value.
4. `404.html` enables pretty URLs `/i/CODE`.

## Universal Links (later, iOS)

1. Edit `.well-known/apple-app-site-association` with your Apple Team ID + bundle ID.
2. Ensure the host serves it at `https://your-domain/.well-known/apple-app-site-association` (no file extension).
3. Add Associated Domains entitlement in Xcode.

## Local preview

```bash
cd Web
python3 -m http.server 8080
```

Open `http://localhost:8080/i/?code=TEST1234` (invite-click will fail locally unless the function is deployed).

## Devlogs

- `Shared_Specs/Web/daily_devlog.md` (Web-Public)
- `Shared_Specs/Web/master_devlog.md` — do not edit manually (Secretary Protocol)
