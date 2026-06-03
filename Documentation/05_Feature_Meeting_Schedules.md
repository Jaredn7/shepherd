# Feature: Meeting Schedules

> **Surfaces:** Tier A only (iOS, Android, Mac, Windows).

## 1. The Global CLMM Workbook (System Sync)
To save Elders from manually typing out every part and topic for the Midweek Meeting, the app utilizes a centralized template system. 
- **Monthly Updates:** Every month, our engineering team publishes the upcoming Christian Life and Ministry Meeting (CLMM) Workbook data to a public, unencrypted storage bucket on the backend.
- **Smart Tags:** Our team tags every single meeting part with precise privilege requirements based on the organization's instructions. Examples include:
  - `Service Overseer Only`
  - `Elder Only` (For specific sensitive topics)
  - `Elders & MS`
  - `Brothers Only` (e.g., Bible Reading)
  - `Everyone` (e.g., Student Presentations)
- **The Sync:** When an Elder opens their app to plan the month, the app automatically downloads this global workbook template. The Elder only has to assign the names to the pre-filled topics.
- **Local Overrides (The Starting Draft):** The Global Sync is NOT a rigid dictator; it merely acts as the "Starting Draft". Once the template is unpacked into local database rows, the Elder has complete control. If the congregation needs to rename "Local Needs", delete a part to save time, or add a custom 5-minute part, the Elder can do so. The app simply sends a granular `UPDATE`, `DELETE`, or `INSERT` lockbox to the congregation, perfectly updating their schedules without destroying the rest of the night's data.

## 2. Auto-Scheduling (The Local Algorithm)
Because the Elder's device contains the global Workbook template (with the Smart Tags) and the full Publisher Directory (with their privileges and past assignments), the auto-scheduling happens entirely locally.
- The Elder taps **"Auto-Fill Month"**.
- The algorithm matches the `Smart Tags` from the Workbook against the publisher privileges (e.g., ensuring a `Service Overseer Only` part is only assigned to the Service Overseer).
- It looks at past history to ensure brothers aren't used too frequently.
- The Elder reviews the generated schedule, makes any manual drag-and-drop tweaks, and clicks "Publish".

## 3. Swaps & The Attendance Check-In (UX Psychology)
To ensure the schedule stays accurate and publishers don't just bypass the app with a text message, the system uses UX nudges to capture cancellations at the source.

- **The Attendance Check-In:** Instead of a passive reminder, the app sends a warm, supportive check-in notification: *"Just checking in! You have a Bible Reading tomorrow. Will you still be able to make it?"* (This avoids any strict, policing language about being "prepared" and feels like a friendly nudge).
- **The Timing:** The check-in is scheduled specifically for **12:30 PM the day before**. This deliberately catches publishers right in the middle of their lunch break (avoiding the busy 12:00 PM rush to wrap up morning tasks), while still giving the Chairman 30 hours of notice if there is a cancellation.
- **The "Yes" Flow:** If the publisher taps "I will be there," the app logs their confirmation in the system for the Chairman to see.
- **The "No" Flow (WhatsApp Bridge):** If they tap "I need to cancel," the app instantly flags their assignment as 'Cancelled' in the Master Directory (sending a lockbox to the Chairman). It then automatically launches WhatsApp, pre-filling a polite message to the Chairman so the publisher can explain why. This perfectly blends the app's database logic with normal human social behavior.

## 4. Replacements & Quick-Swaps (The Chairman Flow)
For theological and organizational order, a publisher does not have the authority to swap or choose their own replacement. That responsibility lies with the Chairman of the meeting (or the Life and Ministry Overseer).
- **The Reassignment:** When the Chairman receives the cancellation lockbox (or the WhatsApp message), he opens his app. He taps a highly prominent **"Quick-Swap"** button on his home screen, selects a replacement from a filtered list of available brothers, and hits Save (designed to take less than 3 taps). 
- **The Broadcast:** A new lockbox is sent out updating the entire congregation's schedule instantly.
