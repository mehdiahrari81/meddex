# MediExplain: Project Scope and Use Cases

## 1. Project Overview
**MediExplain** is a comprehensive software platform designed to bridge the gap between complex medical terminology and patient understanding. It empowers patients to better understand their medical conditions, prescriptions, and healthcare instructions while providing a robust administrative backend for content governance and system management.

The platform consists of three main components:
1. **Mobile Application (Flutter):** A patient-facing, offline-first application designed for scanning prescriptions, explaining medical terms, and managing medication reminders.
2. **Backend API (FastAPI):** A high-performance RESTful API that handles data synchronization, authentication, and core business logic.
3. **Admin Web Portal (Next.js):** A secure, role-based governance dashboard for administrators and medical content reviewers to manage the platform's medical dictionary and user operations.

---

## 2. Project Scope

### In-Scope Features
- **Mobile Client:**
  - **Prescription Scanning:** Utilize device cameras and OCR technology (via ML Kit) to scan and extract text from physical prescriptions.
  - **Medical Terminology Translation:** Translate complex medical jargon into easily understandable, plain-language explanations.
  - **Medication Reminders:** Schedule and track upcoming medication times with local push notifications.
  - **Offline-First Architecture:** Store user data, settings, and terminology locally (via SQLite/Drift) so the app remains fully functional without an internet connection.
  - **Settings & Accessibility:** Granular controls for text scaling, high readability, text-to-speech (TTS), biometric lock, and user explanation levels.

- **Admin Web Portal:**
  - **Content Management:** Create, review, and publish medical terminology definitions.
  - **Role-Based Access Control (RBAC):** Distinct permission levels (Super Admin, Editor, Reviewer, Support).
  - **Multi-Factor Authentication (MFA):** Enhanced security for administrative logins.
  - **System Health & Audit:** View system health metrics, manage user support requests, and audit content changes.

- **Backend & Infrastructure:**
  - **Data Synchronization:** Sync patient data between the local mobile database and the cloud PostgreSQL database when online.
  - **Authentication System:** Secure JWT-based session management for both patients and administrators.
  - **Database Management:** Alembic migrations and scalable PostgreSQL schema design.

### Out of Scope (For Initial Release)
- Direct integration with hospital Electronic Health Record (EHR) systems.
- Telemedicine video/audio consultations.
- Pharmacy prescription fulfillment or medication ordering.

---

## 3. Primary Use Cases

### Patient / End-User Use Cases
1. **Scanning a New Prescription**
   - *Actor:* Patient
   - *Flow:* The patient receives a physical prescription. They open the app, navigate to the "Scan" tab, and take a photo. The app extracts the text, identifies the medication and dosage, and adds it to their profile.
2. **Understanding Medical Jargon**
   - *Actor:* Patient
   - *Flow:* The patient encounters a confusing medical term on their diagnosis sheet. They use the "Learn" or "Search" tab to look up the term and receive a simplified, plain-English explanation of what it means.
3. **Managing Daily Medications**
   - *Actor:* Patient
   - *Flow:* The patient sets up their daily medication schedule. The app sends a local notification when it is time to take a pill. The patient taps the notification and logs the medication as "taken" in the app.
4. **Using the App Offline**
   - *Actor:* Patient
   - *Flow:* The patient is in a hospital with poor cellular reception. They can still search for medical terms, view their saved prescriptions, and receive scheduled medication reminders because all data is stored locally on the device.

### Administrator & Governance Use Cases
1. **Reviewing and Publishing Medical Content**
   - *Actor:* Content Editor / Medical Reviewer
   - *Flow:* An editor logs into the Admin portal and drafts a new simplified explanation for a medical condition. A user with the "Reviewer" role checks the draft for medical accuracy and approves it. The term is then published and synced to mobile users.
2. **Managing Administrative Access**
   - *Actor:* Super Admin
   - *Flow:* A new support staff member joins the team. The Super Admin creates an account for them, assigns the "Support" role, and enforces MFA for their account to ensure security.
3. **Monitoring System Health**
   - *Actor:* Super Admin
   - *Flow:* The admin navigates to the System Health dashboard to ensure the FastAPI backend and database are operating correctly and to review recent audit logs for security purposes.
