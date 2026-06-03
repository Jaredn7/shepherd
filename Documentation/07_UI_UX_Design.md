# UI/UX Design Architecture

> **Surfaces:** Tier A apps follow `Shared_Specs/design_system_spec.md`. **Web-Public** uses a subset of brand tokens for marketing and invite pages. Detailed Windows native patterns are defined when the Windows stack is chosen.

## 1. Core Aesthetic Principles
The app must feel like a premium, native application, rejecting clunky web-wrapper designs in favor of world-class interface standards.
- **Apple "Liquid Gloss" (iOS & Mac):** Modern Apple aesthetics—clean, minimal, intuitive. Mac reuses the shared dark palette and glass/matte patterns from the design system spec.
- **Android:** Material You–aligned native components while honoring the same hex palette and spacing rules from the shared spec.
- **Windows:** Native Windows shell (stack TBD) with the same color system and information hierarchy as Mac where practical.
- **Web-Public:** Simpler, marketing- and form-focused layouts; may use **React** for richer public pages. Not required to mirror the full in-app tab chrome.
- **Glassmorphism:** Frosted glass and translucent surfaces on Apple platforms; equivalent depth on Android/Windows without copying iOS controls literally.
- **Light & Dark Mode:** Tier A apps support system Light and Dark modes.

## 2. Micro-Animations (The Premium Polish)
We avoid big, in-your-face, distracting animations. Instead, the app relies on subtle, high-frame-rate micro-animations to provide tactile feedback and a premium "polished" feel.
- **Spring Physics:** Buttons should have a subtle, satisfying spring-bounce when tapped.
- **Smooth Transitions:** Opening a lockbox, switching tabs, or expanding a card should feature soft, seamless fade-and-slide transitions.

## 3. The Home Dashboard ("Up Next" Action Center)
To prevent cognitive overload, the home screen rejects the traditional "static dashboard of charts." Instead, it functions as a highly contextual **Action Center**.
- **Dynamic Anticipation:** The top card changes based on the user's immediate needs. 
  - If it's a meeting night, it prominently displays their assignment (e.g., *"You have a Bible Reading tonight at 7:30 PM"*).
  - If it's the 1st of the month, the top card transforms into a call-to-action: *"It is a new month! Tap here to submit your report."*
- **Minimalism:** By showing only what the publisher needs at that exact moment, the app feels incredibly simple and easy to use, especially for older users.

## 4. Desktop Considerations (Mac & Windows)
- **Secretary / elder workflows:** Larger screens should prioritize roster editing, schedule building, and report review without changing the mobile information architecture unnecessarily.
- **Input:** Keyboard and pointer interactions (right-click, shortcuts) may be added on desktop where they improve elder efficiency; mobile gestures remain the baseline for shared flows.
