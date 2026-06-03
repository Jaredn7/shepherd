# Onboarding & Invite System

> **Surfaces:** Invite landing and fingerprinting live on **Web-Public** (`Web/`). Full onboarding and congregation data live on **Tier A** apps (iOS, Android, Mac, Windows).

## The Bootstrapping Challenge
Because the backend is a "blind" relay server with no readable user data, new publishers cannot simply search for a congregation and click "Join". The initial connection and exchange of cryptographic keys must be established securely out-of-band.

## The Custom Invite Link Flow
To create a seamless user experience while avoiding expensive third-party tracking SDKs (like Branch.io), we use a custom **Deferred Deep Linking** system: **Web-Public landing pages** plus **Supabase edge functions**.

Here is the exact technical flow:

1. **The Invite Generation:** An Elder taps "Invite Publisher" in their Tier A app. The app generates a temporary invite link containing the congregation's anonymous ID and the Elder's Public Key (padlock).
2. **The Share:** The Elder texts, emails, or AirDrops this link to the publisher.
3. **Web-Public landing:** When the publisher clicks the link, they hit the **public invite page** (static or React-hosted under `Web/`).
    - The page collects a device fingerprint (OS, screen size, user agent, timezone, etc.) and calls Supabase **`invite-click`** to bind the click to the invite session.
    - The page attempts to open the app (`shepherd://invite?code=…`) and falls back to the **App Store** or **Play Store** (Mac/Windows store links when those apps are listed).
4. **App installation & deep linking:**
    - **Android:** Google Play Install Referrer can pass the invite into the app on launch when configured.
    - **iOS:** On first open, the app resolves the invite via **`invite-resolve`** (fingerprint / code), downloads the **welcome package**, and **`invite-ack`** after local apply.
5. **The Lockbox:** The app absorbs the Elder's Public Key from the invite flow, generates its own key pair, locks its Public Key in a box addressed to the Elder, and drops it at the bus station.
6. **Welcome package:** Pre-approved invites can ship the welcome package from the elder at link creation; the publisher's device applies schedules, territory data, and elder public keys locally after resolve.

## Adding Secondary Devices (Mobile-First Rule)
To maximize security, **initial publisher onboarding** uses a **smartphone** (iOS or Android) via the invite link. **Mac**, **Windows**, and **iPad** are added later as **linked Tier A devices**—not via a browser login that pulls congregation data from the cloud.

Because the backend does not hold unencrypted congregation data, users **cannot** sign into a website with email/password to download their roster. Secondary devices must be authorized from an already-linked primary device.

Flow for linking a secondary device (Mac, Windows, iPad, or additional phone):
1. **QR code:** On the secondary device, the user opens the Tier A app and chooses **Link to Existing Account**. The device generates a new Public Key and shows a QR code with a secure temporary **Meeting Room ID**.
2. **Scan:** On the primary phone, the user taps **Link New Device** and scans the QR code.
3. **Data transfer:** The phone connects via the bus station, encrypts the relevant local payload, and transmits it to the secondary device.
4. **Directory update:** The phone notifies elders' device directory that a new device public key exists.

From then on, elder-published updates create lockboxes for every registered device—including the new Mac, Windows, or tablet.

## Universal Links (iOS, later)
- Host `apple-app-site-association` on the Web-Public domain.
- Add Associated Domains in the iOS Xcode project when ready.
