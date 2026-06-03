# Database, Security, & Data Flow Architecture

> **Surfaces:** This architecture applies to **Tier A** apps (iOS, Android, Mac, Windows). **Web-Public** only touches Supabase for **public** invite/config endpoints—not local congregation databases.

## Goal
To ensure maximum privacy for sensitive congregation and publisher data. The application will use a **"Local-First"** architecture where the backend server acts merely as a temporary relay ("bus station") to transport data updates between devices. Data will not be stored persistently on any central backend server.

## 1. Local Storage (The True Database)
All persistent data will live exclusively on the user's device. 
- Data is accessed instantly from the local device database, allowing 100% functionality without an internet connection.
- When offline, changes (like logging a report or updating a territory) are saved locally and queued for synchronization.

## 2. The Relay Server (The "Bus Station")
The backend (**Supabase**) acts strictly as the transport layer and public edge functions (invites, bus).
- **End-to-End Encryption (E2EE):** Before data leaves a user's device, it is encrypted. The server **cannot** read the data; it only sees encrypted blobs of text.
- **Temporary Holding (Limbo):** The server maintains an "Inbox" for every registered device in the congregation. It holds the encrypted messages in limbo only until the receiving device comes online.

## 3. The Data Flow & Sync Mechanism
Because an update (like an Elder publishing a new schedule) must reach many publishers, the data flows as follows:
1. **Send:** An Elder makes a schedule change. Their app encrypts the update and pushes an individual message to the server Inbox for *each* device in the congregation.
2. **Hold:** The server holds these messages in limbo.
3. **Receive & Delete:** As Publisher A opens the app, their device downloads all messages in their personal Inbox, updates their local database, and then tells the server to **delete** those messages. 
4. Publisher B's Inbox still contains the message until Publisher B comes online. This ensures data is deleted the exact moment the intended recipient downloads it.

## 4. Device Onboarding & Restores (The "Welcome Package")
Because data is not stored on the backend, any time a device needs to be populated with data, it is handled securely via peer-to-peer transmission from an Elder's device.
- **Elders as Supernodes:** The Elder body devices store the *full* encrypted congregation database. 
- **Publishers as Lite Nodes:** Regular publishers only store their personal slice of data (their own schedules, reports, etc.).
- **The Welcome Package:** Whether a publisher is brand new, moving in from another congregation, or restoring data to a lost phone, the process is unified. The publisher logs in and requests access (displaying "Waiting for elders to approve your access").
- Once an Elder approves the request, the Elder's app automatically compiles a systemized "Welcome Package" (containing the current schedule, territory maps, and any applicable historical records) and transmits it securely through the bus station to the publisher's device.

## 5. Multi-Device Sync & The Device Directory
To support users with multiple devices without storing unencrypted user records on the backend, we use a zero-knowledge "Blind Routing" model:
- The backend server only holds anonymous, random "Device IDs" with no names attached.
- **Full Directory (Elders):** Every Elder's device securely stores the full directory mapping every publisher to their anonymous Device IDs. When an Elder publishes a schedule on their computer, the computer creates a box for every single device in the congregation—**including boxes addressed to the Elder's own phone and iPad**. This guarantees their personal devices stay perfectly synced.
- **Lite Directory (Publishers):** Regular publishers only hold their own information and the Device IDs of the Elders. When a publisher submits a report, their phone only creates boxes for the Elders' devices, plus their own alternate devices.

## 6. Advanced Cryptography & Performance
To ensure maximum security without degrading app performance or stressing the backend server, the system relies on the following mechanisms:
- **Asymmetric Encryption (Padlock & Key):** We use Public/Private Key pairs. Publishers generate a Private Key (kept permanently hidden on the device) and a Public Key (an open padlock shared with the Elders' master directory). Even if the backend is hacked, data cannot be read without the private keys.
- **In-Person Verification:** To prevent man-in-the-middle attacks, Elders can scan a QR code on a publisher's phone to permanently verify their Public Key in person.
- **Hybrid Encryption for Large Payloads:** If sending a large file (like a PDF) to 100 people, the app generates a single temporary "Message Key", encrypts the file once, and then encrypts the tiny Message Key 100 times. This prevents the phone from freezing during encryption and keeps the payload tiny.
- **API Batching:** When sending updates to a large congregation, the app does not make 100 separate API calls. It batches all 100 encrypted boxes into a single data array and makes *one* API POST request to the server, protecting the backend from being overloaded.

## 7. Sync Strategy & Server Efficiency
To maximize the backend Free Tier (avoiding concurrent connection limits) and preserve device battery life, the app uses a simple, highly efficient sync strategy instead of WebSockets or continuous polling:
- **Fetch-on-Open:** When a user physically opens the app or brings it to the foreground, it makes one single API call to the bus station to download any pending encrypted boxes.
- **Manual Pull-to-Refresh:** If a user leaves the app open on their screen and wants to check for updates, they simply swipe down on the screen ("Pull-to-Refresh") to trigger a new fetch.
- This guarantees near-zero battery drain in the background and ensures the app will not hit backend connection limits, comfortably accommodating scaling on a free tier.

## 8. Data Parsing & Payload Structure
When a device downloads and decrypts a locked box, the payload inside is structured as an "Instruction Manual" (a JSON object) rather than raw text. 
- **The Shipping Label (Unencrypted):** The outside of the box contains the sender's anonymous Device ID. The app checks this against its local directory to verify the sender is an authorized Elder before accepting it.
- **The Decryption:** The app uses its own Private Key to unlock the box.
- **The Instruction Manual (Encrypted Payload):** Inside, the data contains specific commands for the local database:
  1. `Action`: What to do (e.g., `INSERT` a new record, `UPDATE` an existing one, or `DELETE` it).
  2. `Table`: Which local database table to modify (e.g., `Meeting_Schedules`).
  3. `Record_ID`: The unique ID of the exact record being changed.
  4. `Data`: The actual changes (e.g., just the new Chairman's name).
- By sending structured actions rather than full files, the app knows exactly how to edit the local database. It also includes a timestamp to resolve conflicts if two people edit the same record while offline.

## 9. Edge Case: Revocation & Remote Wipe
Handling the removal of a publisher (e.g., a lost device, or moving to a new congregation) requires a specialized offline-first approach since the server holds no centralized database.
- **The Disconnect:** When an Elder revokes access, their app deletes the user's Public Key from the Master Directory and broadcasts that deletion to all other Elders. The revoked user will instantly stop receiving new lockboxes.
- **The Poison Pill:** The Elder's device generates one final lockbox addressed to the revoked user containing the command `Action: WIPE_DATABASE`. The next time the revoked phone checks the bus station, it processes this command and instantly deletes its entire local database.
- **The Time Bomb:** To prevent a user from simply turning off Wi-Fi forever to avoid the Poison Pill, the app contains an offline "Time Bomb." If the app is unable to successfully ping the bus station for 30 consecutive days, the UI locks completely and hides all data until an internet connection verifies their active status.

## 10. Edge Case: App Updates & Schema Migrations
Handling version updates in a decentralized app requires strict rules to prevent older apps from crashing when receiving newer data structures.
- **Message Acknowledgements (ACKs):** To guarantee zero data loss, the app uses a strict two-step queue. It downloads the lockboxes, successfully saves them to the local database, and *only then* makes a second API call to tell the backend to delete the boxes.
- **Server-Side Filtering (Minor Updates):** Every lockbox has an unencrypted `min_app_version` on its Shipping Label. The server only delivers lockboxes compatible with the querying app's version. If there are newer lockboxes waiting, the server holds them and sends a flag telling the app to display a gentle "Update Available" badge.
- **Forced Upgrades (Major Updates):** For massive, breaking schema changes, the backend holds a global `minimum_required_version` setting. On launch, every app checks this setting. If their version is too old, the app completely blocks access with a hard pop-up ("Major Update Required. Please update now.") and refuses to query or send any messages until the user updates via the App Store.

