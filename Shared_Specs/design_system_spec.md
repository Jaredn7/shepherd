# UI/UX Design System Specification
**Last Updated:** 2026-06-03
**Aesthetic Theme:** "Liquid VibeMove" (Editorial Matte + Frosted Glass)

## Overview
The Shepherd **Tier A** apps (iOS, Android, Mac, Windows) share one visual language: editorial matte layouts plus native OS depth (glass on Apple, Material on Android, native Windows chrome when defined).

**Web-Public** (`Web/`) uses a **subset** of this palette for marketing and invite pages. It may be built with **React** (or similar) and does not replicate the full in-app tab bar or congregation UI chrome.

## Surface scope

| Surface | Design system adherence |
|---------|-------------------------|
| **iOS** | Full spec (Pioneer A for mobile UI) |
| **Mac** | Full spec — same hex tokens; Apple Liquid Glass / materials (Pioneer B for desktop) |
| **Android** | Full hex + typography; Material You components |
| **Windows** | Full hex + typography; native Windows controls (stack TBD) |
| **Web-Public** | Brand colors, typography, and layout principles only |

## Color Palette (Dark Mode Primary)

### Backgrounds & Surfaces
- **App Background (Dark Slate):** `#16181A` - `Color(red: 0.09, green: 0.09, blue: 0.10)`
- **Solid Matte Surfaces:** `#242629` - `Color(red: 0.14, green: 0.15, blue: 0.16)`
- **Glass Surfaces:** Native OS frosted glass (iOS/Mac: `.ultraThinMaterial` / `.glassEffect` where available). Subtle white overlay/blur.

### Accents
- **Primary Accent (Coral Orange):** `#FF5D47` - `Color(red: 1.0, green: 0.36, blue: 0.28)`
  - Used for active tab highlights, primary buttons, and critical alerts.
- **Secondary Accent (Olive Green):** `#4D6356` - `Color(red: 0.30, green: 0.39, blue: 0.34)`
  - Used for toggles, segmented controls, and secondary active states.

### Text & Borders
- **Primary Text:** White (`#FFFFFF`)
- **Secondary Text:** White at 65% opacity
- **Glass Border:** White at 12% opacity (subtle 0.5px stroke outlining glass cards)

## Typography
- **Headers & Titles:** System serif (Apple System Serif, Georgia, or platform equivalent). Used for large titles and editorial headers.
- **Body & Labels:** System sans-serif (SF Pro, Roboto, Segoe UI, Inter on Web-Public). Used for lists, captions, and functional text.

## Core Components (Tier A)

### iOS
1. **Glass Cards:** Corner radius **32px**. Liquid Glass on iOS 26+ (`.glassEffect`) or `.ultraThinMaterial` on older OS.
2. **Tab Bar:** Native floating Liquid Glass tab bar on iOS 18+ (`TabView` + `Tab`). Custom floating glass capsule on iOS 15–17.
3. **Navigation:** System navigation bar with Liquid Glass on iOS 26+; ultra-thin material on iOS 18–25.

### Mac
- Reuse iOS tokens (same hex table). Prefer AppKit/SwiftUI native toolbars, sidebars, and window chrome appropriate to macOS.
- Desktop: favor pointer/keyboard affordances for elder workflows without changing mobile information architecture.

### Android
- Same hex palette; implement with Material 3 components (cards, navigation bar, FABs).

### Windows
- Same hex palette and hierarchy as Mac; native WinUI or chosen stack TBD.

### Shared visual elements (all Tier A)
4. **Background:** Deep navy mesh gradient with blue/violet ambient blobs.
5. **Avatars:** Squircles tinted with accent at 12–18% opacity.

## Web-Public
- Use **Primary Accent**, **Dark Slate** background, and typography alignment for brand consistency on invite/marketing pages.
- Simpler layout: no requirement for floating glass tab bars or congregation module chrome.
- Invite landing (`Web/i/`) already uses the dark mesh + coral CTA pattern — treat as reference implementation.
