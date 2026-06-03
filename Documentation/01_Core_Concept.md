# Congregation Management App: Core Concept

## 1. Core Purpose & Target Audience
A modern, all-in-one congregation management platform built specifically for Jehovah's Witnesses. It streamlines how congregations function by replacing scattered tools or older software (like NW Scheduler and Hourglass) with a unified, user-friendly system.

## 2. Platform Availability
Shepherd ships on **five surfaces**. Four are **Tier A** full native apps with the same product capabilities (meetings, congregation data, field service, CLMM secretary workflows). The fifth is **Web-Public**—a public website for landing pages, invites, and other URL-based needs—not a replacement for the desktop apps.

### Tier A (full app)
- **iOS:** Native app for iPhone and iPad (App Store).
- **Android:** Native app for phones and tablets (Google Play).
- **Mac:** Native macOS desktop app (Mac App Store).
- **Windows:** Native Windows desktop app (Microsoft Store when listed).

### Web-Public (public website)
- **Purpose:** Marketing, deferred deep-link invite landing, universal links, and other features that require a **public domain** in the browser.
- **Not in scope:** Full congregation UI (no Meetings / Congregation / Ministry tabs as a browser-based product). Desktop and laptop users use **Mac** and **Windows** for that.
- **Implementation:** Expected to use a modern web stack (e.g. **React**); exact architecture may evolve as public-site needs grow.

## 3. Account Structure & User Base
- **Universal Access:** Every member of the congregation gets their own individual login and dashboard on Tier A apps.
- **Role-Based Access (Proposed):** 
  - *Publishers:* Can view their personal schedules, submit their own field service reports, and access their currently assigned territories.
  - *Elders/Admins:* Have secure, elevated access to manage congregation data, generate overall reports, assign territories, and configure schedules.

## 4. Commercial Model (Congregation Licensing)
- **Pricing:** **R50 per month per congregation** (South African Rand), billed through the **App Store** (and equivalent store flows on Android / Mac / Windows when live).
- **Free trial:** **Three months** free so the whole congregation can evaluate the product before paying.
- **Billing choice:** Each congregation chooses what fits its cash flow:
  - **Monthly:** R50 per month, or
  - **Annual:** **R600 per year** (R50 × 12), paid once for the year.
- **Renewal:** Annual licenses are **renewed manually** each year (not an open-ended auto-deduct subscription the user forgets about).
- **Not offered:** Donation-based pricing, pay-what-you-want, or a separate in-app “hardship / poor congregation” waiver product—the commercial model is a single low monthly price with the trial and payment options above.

## 5. Growth & Rollout Strategy
- **Phase 1 (South Africa first):** Pilot and early adoption focused on South African congregations—product, support, and culture fit are validated here before wider rollout.
- **Phase 2 (Global expansion):** Grow deliberately over multiple years. Congregations worldwide can adopt over time; engineering prioritizes reliability and trust over rushing every market at once.
- **Architecture note:** Congregation **data** remains **local-first and E2EE** on devices (see §6). The backend (Supabase) is a blind relay and public onboarding layer—not a central database of readable publisher records for all congregations.

## 6. Core Principle: Decentralized Backups (The Supernode Model)
A foundational principle of this app's architecture is that the central backend server **never** stores readable congregation data. To prevent data loss while maintaining End-to-End Encryption, the app relies on a "Decentralized Backup" model.
- **Elders as Supernodes:** Every Elder in the congregation holds a complete, synchronized copy of the entire congregation's database on their local device. 
- **The Redundancy Rule:** If a congregation has 8 Elders, the congregation effectively has 8 secure, physical backups of their data. If the Secretary loses his iPad, no data is lost. He simply buys a new iPad, links it, and the other 7 Elders' devices automatically re-populate his new device with the complete congregation database.
