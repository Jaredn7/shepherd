# Feature: The "My Roles" Hub (Admin Access)

> **Surfaces:** Tier A only (iOS, Android, Mac, Windows).

Rather than cluttering the app with a jarring "Elder Mode" toggle or burying administrative features inside the publisher tabs, the app uses an elegant **"Role-Based Hub"**.

This UX pattern perfectly matches the highly structured organizational nature of Jehovah's Witnesses, where appointed men have very specific jobs (e.g., Secretary, Public Talks Coordinator, Group Overseer).

## 1. The 5th Navigation Tab
For regular publishers, the app has a minimalist 4-tab layout. 
For appointed men (Elders and Ministerial Servants), a **5th Tab** dynamically appears at the far right of the navigation bar. 
- **Proposed Names:** *"My Roles"*, *"Privileges"*, or a simple, intuitive briefcase/badge icon.

## 2. The Spotify-Style Modal
When an Elder or Ministerial Servant taps this 5th tab, they do not go to a massive, confusing dashboard of every possible admin tool. Instead, a clean, fluid pop-up modal appears from the bottom (similar to the Spotify "plus" button).
- The modal dynamically lists *only* the specific organizational roles assigned to that user in the Master Directory.
- **Example:** If Brother John is both the Coordinator of the Body of Elders (COBE) and the Public Talks Coordinator, his modal shows exactly two large, friendly buttons:
  - `[ Coordinator (COBE) ]`
  - `[ Public Talks Coordinator ]`

## 3. Dedicated Workspaces
Tapping a role routes the user into a dedicated, highly focused workspace specifically designed for that exact job:
- **Secretary Workspace:** Clicking this opens the Field Service dashboard, showing all submitted reports, the escalation ladder, and pioneer tracking.
- **Public Talks Coordinator:** Clicking this opens the interface to assign guest speakers and schedule the Weekend Meetings for the next 3 months.
- **Group Overseer:** Clicking this opens the list of their specific group members to check on missing reports, trigger WhatsApp nudges, or update contact info.

## 4. The Benefits
- **Hyper-Focused UI:** Users only see the tools they actually need for their specific job, completely removing UI clutter and preventing older brothers from getting lost.
- **Scalability:** If the app later expands to include Kingdom Hall Accounts or Literature, we simply add an "Accounts Servant" or "Literature Servant" workspace.
- **Built-in Security:** The UI acts as a natural permission system. If you aren't officially assigned the role of Secretary by the COBE, you physically cannot see the Secretary button in your modal.

## 5. UX Edge Cases & Solutions
To ensure the "My Roles" hub doesn't create fragmented workflows or navigation traps, the app employs the following UX fixes:
- **The "General Elder" Fallback:** Not all elders have specific titles (like Secretary). Every appointed Elder automatically receives a base-level **"Elder Tools"** (or "Shepherding") button in their modal. This guarantees they always have read-access to the Field Service totals and Master Directory.
- **The Universal Publisher Card:** To prevent "siloing" between roles, tapping a publisher's name *anywhere* in the app (whether in the Secretary view or the Schedule view) pulls up their **Universal Publisher Card**. This card displays their contact info, recent field service reports, and upcoming meeting assignments all in one place, removing the need to switch roles just to cross-reference data.
- **Anchor Navigation (The Bottom Bar Never Changes):** To solve the "Double Navigation Trap", the bottom 5 tabs **never** disappear or change when you enter a Role workspace. They act as a persistent anchor. 
  - Instead, the Role workspace loads in the main screen area *above* the tabs. 
  - If a role (like Secretary) needs multiple sub-pages, it uses "Segmented Controls" (tabs at the top of the screen) or sleek cards. 
  - This allows an Elder to be deep inside the Secretary workspace, but instantly tap the "My Roles" tab at the bottom to jump to his COBE workspace in exactly two taps.
- **Notification Deep-Linking:** Tapping an administrative push notification bypasses all modals and drops the user directly into the relevant workspace to take immediate action.
