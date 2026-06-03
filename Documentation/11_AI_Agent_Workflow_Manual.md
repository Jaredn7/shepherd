# AI Agent Workflow & Architecture Manual

## 1. The Pioneer / Follower Paradigm
This project uses a multi-surface AI architecture. **Tier A** apps share one product; **Web-Public** is a separate public website.

### Pioneers (decide first)
- **iOS (Pioneer A):** Primary **mobile** build. Product decisions, crypto, database schemas, and mobile UX are solved here first.
- **Mac (Pioneer B):** Primary **Apple desktop** build. Desktop UX and Mac-specific behavior are solved here for the Mac/Windows chain.

### Followers (replicate, do not invent)
- **Android → follows iOS**
- **Windows → follows Mac**

### Web-Public (not a Tier A follower)
- Builds **landing, invites, and public-domain** features only (`Web/`).
- Does **not** replicate the full iOS feature set. Gap analysis is invite/deep-link/public-config only.

For day-to-day agent rules (surface picker, devlog format, schema approval), use the **Secretary Protocol** (`.cursor/rules/secretary.mdc` and the Secretary skill).

---

## 2. Directory Structure
Two critical non-code areas in the repo root:

### `/Documentation/` (The "What" and "Why")
Product foundation: features, personas, onboarding concepts, commercial model.
- **When to read:** Before deciding *what* to build.

### `/Shared_Specs/` (The "How")
Engineering ledger: crypto math, schemas, design tokens, devlogs.
- **When to read:** Before writing code. Never guess hex codes, algorithms, or field types.

### Tier A source folders
`iOS/`, `Android/`, `Mac/`, `Windows/`

### Web-Public source folder
`Web/` (devlogs still live under `Shared_Specs/Web/`)

---

## 3. The Devlog System (Logging Your Work)
Under `/Shared_Specs/`, each surface has **`daily_devlog.md`** and **`master_devlog.md`**:

| Surface | Devlog folder |
|---------|----------------|
| iOS | `Shared_Specs/iOS/` |
| Android | `Shared_Specs/Android/` |
| Mac | `Shared_Specs/Mac/` |
| Windows | `Shared_Specs/Windows/` |
| Web-Public | `Shared_Specs/Web/` |

### A. `daily_devlog.md` (Scratchpad)
Live timeline for the current session: errors, pivots, experiments.
Log continuously while coding (Secretary **5-field** contract, including **Cross-Platform Constraints** for other surfaces).

### B. `master_devlog.md` (Immutable ledger)
Clean summaries appended at end of session from `daily_devlog.md`.
**AI agents must not edit `master_devlog.md` manually**—automation maintains it (Secretary Protocol).

**5-Bucket Rule** (when consolidating into master summaries):
1. **Architectural Changes**
2. **Logic & Math Formulas**
3. **Granular UI/UX Specs**
4. **Data Model Structures**
5. **Edge Cases & State Handling**

After a finalized transfer, clear `daily_devlog.md` for the next session.

---

## 4. Instructions for Follower Agents (Tier A)

### Android (follows iOS)
1. **Baseline:** `Shared_Specs/Android/master_devlog.md` — last entry timestamp.
2. **Pioneer timeline:** Read `Shared_Specs/iOS/master_devlog.md` (and `daily_devlog.md` if needed) for everything after your baseline.
3. **Specs:** `cryptography_spec.md`, `database_schema_spec.md`, relevant `Databases/*.json`.
4. **Replicate** in Kotlin; log in Android devlogs with cross-surface constraints for iOS/Mac/Windows.

### Windows (follows Mac)
1. **Baseline:** `Shared_Specs/Windows/master_devlog.md`.
2. **Pioneer timeline:** Read `Shared_Specs/Mac/master_devlog.md` for everything after your baseline.
3. **Specs:** Same shared specs as Android followers.
4. **Replicate** on Windows; log constraints for iOS/Android/Mac.

### Mac (Pioneer B)
When pioneering new desktop behavior, update Shared Specs when shared contracts change, and log constraints so **Windows** can follow.

---

## 5. Instructions for Web-Public Agents
1. Read `Web/README.md` and existing invite assets.
2. Read iOS/Mac devlogs only where **public flows** depend on app behavior (invite-resolve, deep links, store URLs).
3. Do **not** implement Tier A tabs or local congregation DB in the browser.
4. Log in `Shared_Specs/Web/daily_devlog.md`; constraints should name which Tier A surfaces must align for public API contracts.

---

## 6. Gap Analysis (Quick Reference)
- **Tier A agent:** Compare iOS vs Android vs Mac vs Windows; report leading/trailing and code gaps.
- **Web-Public agent:** Compare public URL/invite/AASA/config support—not full app parity.
