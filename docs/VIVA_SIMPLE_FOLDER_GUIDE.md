# MediExplain simple folder and file guide

Read this guide first. It explains the project **folder by folder**, then the important files inside each folder. The longer `VIVA_PROJECT_CODE_GUIDE.md` is a reference if you need more detail.

## 1 First understand the whole project

Your project has two main programs:

**The phone app:** what the patient sees and taps. Written in Dart using Flutter.

**The backend:** a program running on the server/laptop. It handles login, online medicine information, AI calls, and supported data uploads. Written in Python using FastAPI.

```text
Patient uses the phone app
          ↓ sends a request when needed
Backend processes the request
          ↓ reads or saves information
Server database or external AI/reference service
          ↓ returns the result
Phone app shows the result
```

The phone also has its own local database, so many saved records and learning features work offline.

**Say in your viva:** “Flutter handles the interface. FastAPI handles server work. SQLite stores local phone data, and PostgreSQL stores server data.”

## 2 Main folders

```text
meddex/
├── apps/mobile/     The phone application
├── services/api/    The Python backend
├── data/            Medicine reference files for import
├── scripts/         Tools to start, build, install, and check the project
├── ops/             Database backup, restore, and cleanup tools
├── docs/            Explanations and project documentation
└── downloads/       Built application packages and their information
```

| Root file | Easy meaning |
| --- | --- |
| [README.md](/Users/mahdiahrari/Developer/meddex/README.md) | The project's introduction and setup instructions. |
| [docker-compose.yml](/Users/mahdiahrari/Developer/meddex/docker-compose.yml) | Starts the local backend, PostgreSQL database, and development email service. |
| [docker-compose.ai.yml](/Users/mahdiahrari/Developer/meddex/docker-compose.ai.yml) | Adds backend AI configuration and the connection to laptop Ollama. |
| [docker-compose.ocr.yml](/Users/mahdiahrari/Developer/meddex/docker-compose.ocr.yml) | Adds the optional server handwriting reader. It is separate from normal cloud reading. |

## 3 Inside apps/mobile

```text
apps/mobile/
├── lib/         Your main Dart application code
├── assets/      Bundled dictionary and learning information
├── test/        Automated checks for the mobile code
├── android/     Android permissions, native code, and build setup
├── ios/         iPhone permissions, native code, and build setup
└── macos/       Mac desktop runner files
```

[pubspec.yaml](/Users/mahdiahrari/Developer/meddex/apps/mobile/pubspec.yaml) lists the packages the phone app uses and the content files included in the app. `pubspec.lock` records the resolved package versions.

### A lib/main.dart — where the phone app starts

[main.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/main.dart) initializes Flutter and logging, then starts the application inside Riverpod's `ProviderScope`.

**Remember:** `main.dart` starts the app. It does not contain all its screens or medicine logic.

### B lib/app — preparing and connecting the application

| Important file | What it does |
| --- | --- |
| [app.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/app/app.dart) | Builds the overall application: language, theme, startup screen, navigation, and optional biometric lock. |
| [bootstrap/bootstrap_provider.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/app/bootstrap/bootstrap_provider.dart) | Prepares the app before normal use: reads settings/login, opens the database, cleans temporary files, and initializes reminders. |
| [bootstrap/startup_coordinator.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/app/bootstrap/startup_coordinator.dart) | Runs those startup jobs in order and reports which job failed. |
| [router/app_router.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/app/router/app_router.dart) | Connects screen addresses to screen widgets. For example, a prescription review address opens the review screen. |
| [router/app_routes.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/app/router/app_routes.dart) | Keeps the list of screen addresses in one place. |
| [config/app_config.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/app/config/app_config.dart) | Reads the app environment and backend address. |

**Bootstrap** simply means “prepare the things needed to start.” **Routing** means “decide which screen to open.”

### C lib/core — shared tools used by different features

| Folder and important file | What it does |
| --- | --- |
| [logging/app_logger.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/core/logging/app_logger.dart) | Writes technical events/errors for debugging. Hides structured fields whose names match sensitive words such as password or token. |
| [auth/auth_repository.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/core/auth/auth_repository.dart) | Sends registration/login/reset/logout requests and connects returned sessions to storage. |
| [network/api_client.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/core/network/api_client.dart) | Shared HTTP communication code. Adds login tokens, handles requests, and supports refreshing an expired session. |
| [storage/session_vault.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/core/storage/session_vault.dart) | Saves session credentials using the phone's secure storage. |
| [database/app_database.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/core/database/app_database.dart) | Defines the local SQLite database and its shared operations. |
| [database/database_provider.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/core/database/database_provider.dart) | Supplies the correct local database for the current account or guest. |
| [sync/sync_coordinator.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/core/sync/sync_coordinator.dart) | Keeps supported changes in a queue and uploads them when allowed/connected. Failed uploads can retry later. |
| [notifications/notification_service.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/core/notifications/notification_service.dart) | Talks to the phone's notification system to schedule/cancel reminders and receive actions. |
| [errors/error_mapper.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/core/errors/error_mapper.dart) | Converts network/server failures into error types the app can understand. |

Other `core/` folders handle connectivity, biometric locking, speech recognition, text-to-speech, and safe file locations.

**Say in your viva:** “Core contains shared services. Login, scanning, and medicine features can reuse the same network client or database.”

### D lib/features — the actual application features

Each folder represents a feature, such as login, prescriptions, medications, or learning.

Inside many features you will see:

| Folder | Easy meaning |
| --- | --- |
| `presentation/` | Screens and buttons the user sees. |
| `application/` | Decisions and steps performed after a user action. |
| `data/` | Code that reads/writes the database or calls a service. |
| `domain/` | Data types and rules describing the feature, such as a prescription item or medication plan. |

Example: the **screen** receives a tap → the **controller** coordinates work → the **repository** reads/writes data → the screen displays the result.

#### features/auth — accounts and login

| Important file | What it does |
| --- | --- |
| [presentation/auth_screen.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/auth/presentation/auth_screen.dart) | Shows the sign-in/register form and checks the entered fields. |
| [application/auth_controller.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/auth/application/auth_controller.dart) | Runs sign-in/register/logout actions and updates whether the app is loading, signed in, or has an error. |

These files use the shared `core/auth/auth_repository.dart` to contact the backend.

#### features/prescription — scanning and reviewing prescriptions

| Important file | What it does |
| --- | --- |
| [presentation/prescription_scan_screen.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/prescription/presentation/prescription_scan_screen.dart) | Scan starting page: capture/import an image or continue a draft. |
| [presentation/camera_capture_screen.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/prescription/presentation/camera_capture_screen.dart) | Opens the camera and takes the photograph. |
| [presentation/prescription_preview_screen.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/prescription/presentation/prescription_preview_screen.dart) | Shows the selected image and supports adjustment before processing. |
| [application/prescription_workflow_controller.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/prescription/application/prescription_workflow_controller.dart) | The main coordinator: loads the draft, prepares images, calls recognition/structuring, saves results, and handles review/confirmation. |
| [data/server_handwriting_ocr_provider.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/prescription/data/server_handwriting_ocr_provider.dart) | Sends the image to the backend handwriting reader and receives recognized text. |
| [data/api_prescription_text_structurer.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/prescription/data/api_prescription_text_structurer.dart) | Sends recognized text for separation into medicine fields. |
| [data/local_prescription_repository.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/prescription/data/local_prescription_repository.dart) | Saves and loads local prescriptions, medicine items, corrections, and confirmation state. |
| [presentation/prescription_review_screen.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/prescription/presentation/prescription_review_screen.dart) | Shows recognized medicines with Check/Confirm actions and the whole-list explanation action. |
| [presentation/prescription_explanations_screen.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/prescription/presentation/prescription_explanations_screen.dart) | Shows all explanations on a separate page under medicine-name headings. |
| [data/api_medicine_batch_overview.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/prescription/data/api_medicine_batch_overview.dart) | Sends all confirmed medicines together for explanation and checks that results match the requested items. |

**OCR means reading text from an image.** It does not mean the medicine has been medically verified.

#### features/medications — My Medications and reminders

| Important file | What it does |
| --- | --- |
| [presentation/medication_screens.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/medications/presentation/medication_screens.dart) | Contains medication list/detail, reminder setup, history, and other medication screens. |
| [data/local_medication_repository.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/medications/data/local_medication_repository.dart) | Saves medicines, schedules, Taken/Skip records, notes, and related data; handles deletion. |
| [application/schedule_engine.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/medications/application/schedule_engine.dart) | Calculates the actual times when a confirmed medicine reminder is due. |
| [application/medication_reminder_service.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/medications/application/medication_reminder_service.dart) | Uses those times to schedule alerts and handles notification actions. |
| [application/adherence_calculator.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/medications/application/adherence_calculator.dart) | Counts recorded taken, skipped, and unrecorded scheduled doses. |

**Remember:** the schedule engine calculates times; the reminder service organizes alerts; the notification service talks to the phone OS.

#### features/terminology — dictionary and word meanings

| Important file | What it does |
| --- | --- |
| [presentation/terminology_search_screen.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/terminology/presentation/terminology_search_screen.dart) | Search box, matching terms, suggestions, and recent searches. |
| [presentation/term_detail_screen.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/terminology/presentation/term_detail_screen.dart) | Shows a term's simple meaning, other available definitions, sources, and word parts. |
| [application/resolve_medical_term.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/terminology/application/resolve_medical_term.dart) | Finds and ranks possible dictionary matches. |
| [application/word_decoder.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/terminology/application/word_decoder.dart) | Breaks supported words into prefixes, roots, and suffixes. |
| [data/local_terminology_repository.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/terminology/data/local_terminology_repository.dart) | Reads terms, definitions, abbreviations, and word parts from the local database. |

#### features/learning — lessons flashcards quizzes and progress

| Important file | What it does |
| --- | --- |
| [presentation/learn_home_screen.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/learning/presentation/learn_home_screen.dart) | Learning home page and links to the learning activities. |
| [data/local_learning_repository.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/learning/data/local_learning_repository.dart) | Loads content and saves lesson/flashcard/quiz progress. |
| [application/quiz_engine.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/learning/application/quiz_engine.dart) | Checks selected answers and calculates quiz results. |
| [application/spaced_repetition.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/learning/application/spaced_repetition.dart) | Decides when a flashcard should be reviewed again based on the user's performance. |
| [application/daily_term.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/learning/application/daily_term.dart) | Chooses the term for the calendar day and refreshes it after midnight/resume. |

#### Other feature folders

| Folder | Important file | What it does |
| --- | --- | --- |
| `home/` | [home_screen.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/home/presentation/home_screen.dart) | Dashboard, next reminder, dose actions, and navigation. |
| `intelligence/` | [api_medication_intelligence_repository.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/intelligence/data/api_medication_intelligence_repository.dart) | Online medicine lookup, source information, and assistant requests. |
| `saved/` | [local_saved_content_repository.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/saved/data/local_saved_content_repository.dart) | Stores bookmarks for terminology content. |
| `profile/` | [profile_screen.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/profile/presentation/profile_screen.dart) | Account hub with medication/settings/session/sign-out options. |
| `settings/` | [settings_controller.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/settings/application/settings_controller.dart) | Loads and updates preferences. Other app code must use a preference for it to affect behavior. |
| `shell/` | [app_shell.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/shell/presentation/app_shell.dart) | Bottom navigation between Home, Scan, Learn, Saved, and Profile. |
| `onboarding/` | [onboarding_screen.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/onboarding/presentation/onboarding_screen.dart) | First-run introduction/setup screens. |

### E Other folders inside lib

| Folder | Important files | Easy meaning |
| --- | --- | --- |
| `design_system/` | `app_theme.dart`, `tokens.dart`, `widgets/` | Shared colors, spacing, corner styles, buttons, cards, and loading/error widgets. Keeps the interface consistent. |
| `domain/` | `models/session.dart`, `models/user.dart`, `providers/medical_providers.dart` | Shared data shapes and service contracts used across features. A contract says what a service must provide. |
| `l10n/` | `app_en.arb`, `app_ur.arb` | English and Urdu text. Flutter generates Dart translation code from these files. |

### F assets and native folders

| Location | Important files | What they do |
| --- | --- | --- |
| `assets/terminology/` | `starter_dataset_v1.json`, `learning_expansion_v1.json` | Bundled dictionary and learning content imported into local storage. |
| `android/` | [MainActivity.kt](/Users/mahdiahrari/Developer/meddex/apps/mobile/android/app/src/main/kotlin/com/mediexplain/mediexplain/MainActivity.kt) | Android bridge for document scanning and on-device ML Kit text recognition. |
| `android/` | [AndroidManifest.xml](/Users/mahdiahrari/Developer/meddex/apps/mobile/android/app/src/main/AndroidManifest.xml) | Android permissions and platform component declarations. |
| `ios/` | [AppDelegate.swift](/Users/mahdiahrari/Developer/meddex/apps/mobile/ios/Runner/AppDelegate.swift) | iPhone startup/native bridge, document scanning, Apple Vision text recognition, and image handling. |
| `ios/` | [Info.plist](/Users/mahdiahrari/Developer/meddex/apps/mobile/ios/Runner/Info.plist) | iPhone app metadata and permission descriptions. |

**About your open `MLKit.h` tab:** it is an installed third-party library header under `ios/Pods/`, not your main prescription code. Its presence does not decide which OCR reader is used. The native iPhone reader in your code uses Apple Vision; the normal prescription image workflow uses the backend cloud reader.

## 4 Inside services/api

```text
services/api/
├── app/          Backend Python code
├── alembic/      Database structure changes
├── tests/        Automated backend checks
└── scripts/      Import and live-check utilities
```

### A app — backend starting point

| Important file | What it does |
| --- | --- |
| [main.py](/Users/mahdiahrari/Developer/meddex/services/api/app/main.py) | Starts the backend application by calling `create_app()`. |
| [factory.py](/Users/mahdiahrari/Developer/meddex/services/api/app/factory.py) | Builds FastAPI and connects routes, database access, error handling, and shared services. |

### B app/api — where phone requests arrive

A **route** is a server address that performs a particular operation, such as login.

| Important file | What it handles |
| --- | --- |
| [api/v1/routers/auth.py](/Users/mahdiahrari/Developer/meddex/services/api/app/api/v1/routers/auth.py) | Registration, login, refresh, logout, password reset, and sessions. |
| [api/v1/routers/prescription_ocr.py](/Users/mahdiahrari/Developer/meddex/services/api/app/api/v1/routers/prescription_ocr.py) | Image reading, text structuring, and medicine explanation requests. |
| [api/v1/routers/prescriptions.py](/Users/mahdiahrari/Developer/meddex/services/api/app/api/v1/routers/prescriptions.py) | Saving, reading, correcting, and deleting prescription records. |
| [api/v1/routers/medications.py](/Users/mahdiahrari/Developer/meddex/services/api/app/api/v1/routers/medications.py) | Personal medication plans and dose records. |
| [api/v1/routers/terminology.py](/Users/mahdiahrari/Developer/meddex/services/api/app/api/v1/routers/terminology.py) | Terms, meanings, abbreviations, and word parts. |
| [api/v1/routers/admin.py](/Users/mahdiahrari/Developer/meddex/services/api/app/api/v1/routers/admin.py) | Permission-protected content/import/review/administration operations. |
| [api/dependencies.py](/Users/mahdiahrari/Developer/meddex/services/api/app/api/dependencies.py) | Supplies shared resources and checks current user/admin identity and permissions. |

### C app/services — the actual server work

| Important file | What it does |
| --- | --- |
| [auth.py](/Users/mahdiahrari/Developer/meddex/services/api/app/services/auth.py) | Creates accounts, checks login, creates/refreshes/revokes sessions, and handles password reset. |
| [gemini_handwriting.py](/Users/mahdiahrari/Developer/meddex/services/api/app/services/gemini_handwriting.py) | Coordinates cloud reading of prescription images and supported uncertain-line checks. |
| [prescription_structuring.py](/Users/mahdiahrari/Developer/meddex/services/api/app/services/prescription_structuring.py) | Separates recognized text into medicine names, strengths, forms, and instructions, then validates the result. |
| [medicine_name_resolution.py](/Users/mahdiahrari/Developer/meddex/services/api/app/services/medicine_name_resolution.py) | Tries to connect a medicine name to a supported reference identity. |
| [medicine_batch_overview.py](/Users/mahdiahrari/Developer/meddex/services/api/app/services/medicine_batch_overview.py) | Prepares evidence and requests explanations for the complete confirmed list together. |
| [medical_rag.py](/Users/mahdiahrari/Developer/meddex/services/api/app/services/medical_rag.py) | Uses trusted facts as AI context, checks supported output/citations, and returns source-backed information. |
| [drap_parser.py](/Users/mahdiahrari/Developer/meddex/services/api/app/services/drap_parser.py) | Reads a DRAP-format CSV, checks columns/rows, and organizes product and ingredient fields. |
| [governance.py](/Users/mahdiahrari/Developer/meddex/services/api/app/services/governance.py) | Manages content revisions, review/publication, import jobs, and audit records. |

**Remember:** the route receives the request; the service performs the work.

### D app/providers — talking to outside services

| Important file | What it does |
| --- | --- |
| [ai.py](/Users/mahdiahrari/Developer/meddex/services/api/app/providers/ai.py) | AI adapters, including Gemini and local Ollama, with response parsing and supported fallback behavior. |
| [cloud_fallback.py](/Users/mahdiahrari/Developer/meddex/services/api/app/providers/cloud_fallback.py) | Tries Gemini and switches supported requests to Groq after quota/temporary availability problems. |
| [medication.py](/Users/mahdiahrari/Developer/meddex/services/api/app/providers/medication.py) | Adapters for medicine reference sources such as RxNorm, MedlinePlus, DailyMed, and imported DRAP data. |

**Gemini/Groq generate or organize text. Medical reference providers supply evidence. These are different jobs.** The small local Ollama Qwen3 1.7B model supports text fallback; it does not read images in this setup.

### E app/models and app/schemas — two different kinds of structure

| Folder | Easy meaning | Examples |
| --- | --- | --- |
| `models/` | How records are stored in database tables. | `user.py`: accounts/sessions; `prescription.py`: prescriptions/items; `medication.py`: plans/doses; `module2.py`: terms/learning; `intelligence.py`: reference identities/facts. |
| `schemas/` | What fields are allowed in an incoming request or outgoing response. | `auth.py` validates login/registration fields; `prescription.py` describes prescription payloads. |

**Example:** a registration schema checks whether the submitted email/password are valid. The user model describes the database row that stores the account.

### F app/core app/db and app/repositories

| Important file | What it does |
| --- | --- |
| [core/config.py](/Users/mahdiahrari/Developer/meddex/services/api/app/core/config.py) | Reads environment settings: database address, AI keys/model choices, timeouts, and security options. |
| [core/security.py](/Users/mahdiahrari/Developer/meddex/services/api/app/core/security.py) | Password hashing/checking, token creation/verification, and related security helpers. |
| [db/session.py](/Users/mahdiahrari/Developer/meddex/services/api/app/db/session.py) | Opens and manages server database connections/sessions. |
| [repositories/users.py](/Users/mahdiahrari/Developer/meddex/services/api/app/repositories/users.py) | Reusable database operations for users, sessions, consent, and reset records. |

`services/api/.env` contains local backend settings/keys. Do not show real keys during your viva.

### G alembic tests and package setup

| Location | Easy meaning |
| --- | --- |
| `alembic/versions/` | Files that upgrade the database structure when tables/columns/indexes change. |
| `tests/` | Checks authentication, prescriptions, provider behavior, medicine explanations, permissions, and other server behavior. |
| `pyproject.toml` | Python package requirements and code-checking/test settings. |
| `Dockerfile` | Instructions for building the backend container. |

## 5 The remaining root folders

| Folder | Important files | What they do |
| --- | --- | --- |
| `data/` | `rxnorm_reference.json`, `drap_snapshot.csv` | Medicine reference/import inputs. A file name alone does not prove every record has verified provenance. |
| `scripts/` | [dev.py](/Users/mahdiahrari/Developer/meddex/scripts/dev.py) | Helps start/configure local services and supported device workflows. |
| `scripts/` | [install-ios-device.py](/Users/mahdiahrari/Developer/meddex/scripts/install-ios-device.py) | Builds/signs/installs an iPhone Release app using the supplied Apple team/device. |
| `scripts/` | [build_mobile.py](/Users/mahdiahrari/Developer/meddex/scripts/build_mobile.py) | Builds application packages and records checksums/build details. |
| `scripts/` | [check-android-apk.py](/Users/mahdiahrari/Developer/meddex/scripts/check-android-apk.py) | Checks required native libraries are inside the Android package. |
| `scripts/` | [test_drap_import_db.py](/Users/mahdiahrari/Developer/meddex/scripts/test_drap_import_db.py) | Manual database-changing import experiment, not normal app execution. Has a stale user-creation branch; do not present it as a passing automated test. |
| `ops/` | `backup_postgres.sh`, `restore_postgres.sh`, `retention_cleanup.py` | Database backup/restore and removal of supported expired server records. |
| `docs/` | Architecture, setup, audits, and viva guides | Explanations/evidence. Documentation does not itself implement a feature. |
| `downloads/` | Application packages and manifests | Build outputs for installation/distribution. |

## 6 Four flows to memorize

### Login

```text
auth_screen.dart
    → auth_controller.dart
    → auth_repository.dart
    → api_client.dart
    → backend routers/auth.py
    → services/auth.py
    → database and returned session
```

**Say:** “The screen collects details. The controller starts login. The repository sends the request. The backend checks the password and returns a session.”

### Prescription scanning

```text
Camera/import → image preview
    → prescription_workflow_controller.dart
    → backend cloud reader → recognized text
    → prescription_structuring.py → medicine fields
    → review screen → patient checks and confirms
```

**Say:** “Reading the page and organizing medicine fields are separate steps. The user reviews the result because handwriting recognition can be wrong.”

### Medicine explanations

```text
All medicines confirmed → Explain medicines button
    → prescription_explanations_screen.dart
    → api_medicine_batch_overview.dart
    → backend medicine_batch_overview.py
    → reference facts + one AI batch → named explanations
```

**Say:** “The complete confirmed list is sent together. The backend uses trusted information and checks which explanation belongs to each medicine.”

### Reminders

```text
Set reminder → save medication schedule
    → schedule_engine.dart calculates times
    → medication_reminder_service.dart organizes alerts
    → notification_service.dart schedules them on the phone
    → Taken/Skip saves a dated event
```

**Say:** “The phone schedules local notifications. Taking or skipping a medicine creates a history record.”

## 7 What to study first

1. Understand sections **1 and 2**: the whole project and root folders.
2. Read section **3**: the phone app folders and important files.
3. Read section **4**: backend folders and important files.
4. Practice section **6** aloud until you can explain the four flows without looking.

For the tabs currently open in your IDE: **`app_logger.dart` logs technical events, `auth_repository.dart` handles account requests, `bootstrap_provider.dart` prepares startup, `MLKit.h` belongs to an installed library, and `test_drap_import_db.py` is a manual import utility.**

You do not need to memorize generated code, downloaded packages in `Pods/`, or build outputs. Focus on the files that connect a user action to processing, storage, and a displayed result. The admin website source is absent here, and some auxiliary features remain incomplete; do not describe every screen/setting as fully operational.
