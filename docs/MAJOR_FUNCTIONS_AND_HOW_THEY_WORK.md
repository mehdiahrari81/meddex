# MediExplain: major functions and how they work

Updated: 21 October 2026

MediExplain helps patients understand prescriptions, medicines and medical terms. Its main parts are a **Flutter mobile app**, a **FastAPI backend**, and a **PostgreSQL server database**. The phone also has a **local SQLite database**, so many features work without an internet connection.

## 1. Account registration, login and logout

**What it does:** Creates personal accounts and keeps each user's information separate.

**How it works:** The app sends registration/login requests to the backend. Passwords are stored as **Argon2id hashes**, rather than readable passwords. Successful login creates an authentication session. The phone stores session credentials in secure storage and refreshes an expired access token when possible. Logout clears local credentials and requests server-side session revocation. Password recovery uses a single-use, expiring reset code.

**Why it feels quick:** The app restores an existing session instead of requiring a fresh login each time. Personal records are available from the account's local database.

## 2. Prescription scanning and medicine extraction

**What it does:** Turns a prescription photograph into separate medicine entries containing the medicine name, strength, form, dose quantity, frequency and other instructions when readable.

**How it works:**

1. The patient captures or selects an image.
2. The app prepares the image and sends it to the backend for Gemini image reading, with automatic Groq fallback for quota or temporary availability failures.
3. Gemini reads the prescription text. A separate structuring step separates medicine details from headings and unrelated writing.
4. The backend validates the structured response against the recognized text.
5. The app displays each medicine for review. **Check** opens the manual editor; **Confirm** records the patient's review and displays a tick. After confirming the entire list, **Explain medicines** at the bottom opens a separate page with all medicine names and explanations. Editing requires another review and Explain action.
6. Reviewed medicines can be added to **My Medications**. Reminder times are configured separately.

The default cloud reader and structurer are **Gemini 3.5 Flash-Lite**, with **Gemini 3.5 Flash** available for recovery/detail reading. Groq uses **Qwen3.8 27B vision** for images and **GPT-OSS 120B** for text structuring in the cloud; neither model runs on the Mac. The project also has on-device OCR support: Apple Vision on iOS and Google ML Kit on Android. Those local readers do not have the same handwriting capabilities as the current Gemini image workflow.

**Why it is faster:** Flash-Lite handles the first pass; additional detail reading is reserved for uncertain results. Recovery has time limits, and duplicate recovery-model attempts are avoided. Cloud recognition runs remotely, so the Mac does not need to run a large handwriting model for this workflow.

**Important behavior:** Missing or unreadable details are not invented. Confirmation records patient review; it is not proof that the prescription was read perfectly.

## 3. Simple medicine explanations

**What it does:** Explains in a few patient-friendly lines what a recognized medicine is and what it generally does.

**How it works:** The backend resolves the medicine name or a verified brand-to-ingredient relationship, retrieves trusted reference information, and produces an explanation tied to those sources. References include **RxNorm, MedlinePlus and DailyMed**, where supported. For example, an explanation for the brand **Betaloc** can identify **metoprolol** as its active ingredient.

**Why it is faster:**

- Prescription explanations use **one app request and one AI batch** for the complete confirmed list.
- Every batch result is matched to its original medicine ID and name; incomplete model answers cannot drop medicines from the page.
- The page retains its batch result while open. Saved-medication screens separately reuse successful single-medicine explanations for **five minutes**, scoped to the same account.
- Exact installed references and verified brand mappings can avoid unnecessary online searches.

Ambiguous identities and missing references can still require correction or selection. The app cannot safely promise an explanation for every possible spelling or regional brand.

## 4. My Medications, reminders and dose history

**What it does:** Stores reviewed medicines, lets patients choose reminder times, and records doses marked **Taken** or **Skipped** with dates.

**How it works:** Medicines, schedules and dose events are saved locally. **Set reminder** saves and activates the schedule. Home reads the saved plans and shows the nearest upcoming fixed reminder. A schedule engine calculates occurrences, including supported weekday and interval schedules. The phone's notification service schedules alerts without needing a server request for every dose.

Patients can pause, resume, complete, archive or delete medication records. Deleting a medication also removes its related reminders, history, notes and refill records. Corrected dose records retain revision history.

**Why it is quick:** Most medication actions use the phone's database. Notifications are scheduled ahead of time, and database updates refresh the relevant screens.

As-needed medicines have no fixed dose reminder. System alerts require notification permission and the app's notification setting.

## 5. Medical terminology and learning

**What it does:** Explains medical terms and word parts, offers lessons and flashcards, runs quizzes, and tracks progress.

**How it works:** The installed catalog contains **30 lessons, 60 flashcards, four quiz questions and 34 medical terms**. Terminology features include search, abbreviations, prefixes, roots and suffixes. Lessons store the section reached; flashcards store review schedules; quizzes save scored results. Progress and streaks use actual recorded learning activity. Today's term changes with the local calendar day.

**Why it is quick:** Installed content, search and progress are available locally. Learning does not need a Gemini request for every lesson or flashcard. Flashcards use a spaced-repetition schedule to decide when a review is due.

## 6. Medical assistant and Gemini → Groq → Ollama fallback

**What it does:** Answers supported general medicine-information questions using trusted reference context.

**How it works:** The backend tries **Gemini first**. For supported quota, timeout or temporary availability failures, it switches to **Groq**; if both cloud providers are unavailable, text explanations can use **Ollama running Qwen3 1.7B on the Mac**. A cooldown prevents repeatedly calling an unavailable primary provider. Grounding checks constrain the response to supplied reference information.

**Why it is lighter:** Gemini handles normal cloud requests. The local fallback uses the smaller **1.7B model**, rather than the previous 8B model.

**Scope:** Qwen3 1.7B is the assistant's text fallback. It is **not** a replacement vision model for prescription photographs. Both cloud keys belong in `services/api/.env`, not in the mobile app.

## 7. Saved data, offline use and synchronization

**What it does:** Keeps prescriptions, medication records, bookmarks and learning progress available on the device, with supported changes queued for server synchronization.

**How it works:** Drift manages the local SQLite database. Changes create pending operations in an **outbox**, which the app retries when synchronization is available and enabled. Idempotency prevents supported repeated requests from creating duplicate records. Account-specific databases separate guest and signed-in profiles.

**Why it is quick:** Local actions do not wait for an upload to finish. The interface uses Riverpod providers to refresh affected views when their data changes.

Cloud scanning and online assistant requests still need a reachable backend. The present development setup uses the Mac's Bonjour `.local` address, which avoids hardcoding a Wi-Fi IP; the phone and Mac must still be on a reachable local network.

## 8. Supporting features

- **Barcode scanning:** Captures a package code and attempts supported trusted-registry resolution. A barcode alone is not treated as verified medicine identity.
- **Notes and exports:** Stores personal medication notes and generates reviewed text/PDF summaries for sharing.
- **Accessibility:** Includes English/Urdu, RTL layout, text scaling, readability/theme controls, pronunciation and voice-related screens.
- **Account/privacy management:** Includes sessions, consent, biometric app locking, local data deletion and account deletion.
- **Backend administration:** Provides APIs for content governance, sources, reports and administration. The admin web frontend source is absent from this checkout, so its screens were not verified.

## What “fast” means in the current project

| Mechanism | Benefit |
|---|---|
| Local database and installed reference content | Immediate access to many everyday features; offline learning and records |
| Fast cloud reader with bounded recovery | Avoids repeated long model attempts |
| Two concurrent explanation requests | Reduces waiting when a scan contains several medicines |
| Caching and shared in-flight requests | Avoids repeating the same successful lookup |
| Background synchronization outbox | Keeps ordinary local actions independent of upload delays |
| Scheduled device notifications | Reminders do not require a live backend call at delivery time |

In the latest recorded live check, a **synthetic printed three-medicine image** reached structured fields in **9.97 seconds**, and the complete API pipeline including three sourced explanations took **20.85 seconds**. An earlier run took **11.24 seconds** overall. These are measured examples, not guaranteed scan times; handwriting, network speed, reference retrieval and provider load affect the result.

## Current limits to keep in mind

The audit passed **250 mobile tests, 194 backend tests and 30 live API scenarios**, but it also found incomplete options. Refill alerts and daily-summary alerts are not connected to scheduling. Some privacy/accessibility preferences are stored without applying their intended behavior. Medication exports omit some schedule distinctions, and Home's next-reminder label can become stale while idle. These findings are documented in [the full functional audit](FULL_FUNCTIONAL_AUDIT_2026-10-20.md).

Physical camera behavior, Face ID, microphone recognition, share-sheet completion and real background alert delivery still need hands-on device checks. Difficult handwriting always requires review. The app explains medical information; it does not independently verify a prescription or decide a patient's treatment.

## Main code locations

| Part | Location |
|---|---|
| Flutter screens and feature logic | `apps/mobile/lib/features/` |
| App startup and routing | `apps/mobile/lib/app/` |
| Local database, secure sessions, networking and notifications | `apps/mobile/lib/core/` |
| API endpoints | `services/api/app/api/v1/routers/` |
| Authentication, OCR, structuring and medicine-information services | `services/api/app/services/` |
| Cloud fallback integration | `services/api/app/providers/cloud_fallback.py` |
| Backend configuration | `services/api/app/core/config.py` |
| Test suites | `apps/mobile/test/` and `services/api/tests/` |
