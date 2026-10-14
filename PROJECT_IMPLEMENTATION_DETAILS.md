# MediExplain - Complete Project Implementation Details

## Project Overview

**MediExplain** is a comprehensive medical literacy platform designed to bridge the gap between complex medical terminology and patient understanding. The system empowers patients to understand their medical conditions, prescriptions, and healthcare instructions through a multi-tiered architecture consisting of a mobile application, backend API service, and administrative web portal.

**Project Name:** MediExplain  
**Project Type:** Multi-platform Healthcare Application  
**Development Period:** Completed August 2026 (Module 4 + 6 final implementation on August 13, 2026)  
**Architecture:** Microservices-based with offline-first mobile client  
**Primary Language Support:** English and Urdu  

---

## System Architecture

### High-Level Architecture

The platform consists of three main components operating as independent but interconnected services:

1. **Mobile Application (Flutter)** - Patient-facing offline-first client
2. **Backend API (FastAPI)** - Core business logic and data management service
3. **Admin Web Portal (Next.js)** - Governance and content management interface

### Architecture Principles

- **Feature-First Design:** Module 1 established feature-first Flutter code organization, with clear module boundaries for terminology, learning, medications, prescriptions, and intelligence features
- **Offline-First Philosophy:** Mobile client operates fully offline with selective synchronization when online
- **Provider Abstraction:** Replaceable interfaces for normalization, patient information, label information, country registry, barcode, interaction, search, and AI explanation
- **Security Boundaries:** Separate authentication domains for patient mobile app and administrative portal (no shared tokens)
- **Medical Information Rule:** Trusted source → structured fact + provenance → optional grounded explanation → validation → user (OCR and language models are never medical sources)

### Module Boundaries

- **features/terminology:** Owns medical records, normalization, search resolution, morphology parsing, local reference-content queries, search history, content updates, and terminology presentation
- **features/learning:** Owns lessons, flashcard schedules, quiz scoring, streaks, progress, and learning screens
- **features/saved:** Owns unified bookmarks while referencing stable terminology IDs
- **features/intelligence:** Owns API DTO conversion, internal medication identities, resolution evidence, source-aware local snapshots, and grounded-answer rendering
- **features/medications:** Medication management, reminders, schedules, and safety checks
- **features/prescription:** OCR scanning, parsing, validation, and prescription management
- **apps/admin:** Separate server-rendered security boundary with independent authentication

### Data Flow Architecture

**Reference Content Flow:**
```
Validated dataset → Transactional importer → Versioned canonical local/server tables
```

**User Data Flow:**
```
Local mutation → Local user table → Module 1 idempotent outbox → Authenticated API
```

**Medication Resolution Flow:**
```
User-confirmed value → Provider adapters → Evidence-ranked candidates → 
Ambiguity/user selection → Stable MedicationIdentity → Structured MedicalFact/provenance
```

**Explanation Flow:**
```
Authenticated context → Structured retrieval → Bounded semantic fallback → 
Optional server-side model → Numeric/name/safety validation → Application-built citations
```

---

## Technology Stack

### Mobile Application (Flutter)

**Framework & Core:**
- **Flutter SDK:** ^3.12.2 (Dart SDK)
- **flutter_riverpod:** ^2.6.1 (State management and dependency injection)
- **go_router:** ^17.5.0 (Declarative routing and navigation)

**Local Storage & Persistence:**
- **drift:** ^2.34.3 (Type-safe SQLite ORM)
- **sqlite3_flutter_libs:** ^0.6.0+eol (SQLite native bindings)
- **path_provider:** ^2.1.6 (File system paths)
- **flutter_secure_storage:** 10.0.0 (Secure credential storage)
- **shared_preferences:** ^2.5.5 (Key-value storage)

**Networking & Connectivity:**
- **dio:** ^5.11.0 (HTTP client with interceptors)
- **connectivity_plus:** ^7.3.1 (Network connectivity monitoring)

**Camera & Image Processing:**
- **camera:** ^0.12.0+2 (Camera access)
- **image_picker:** ^1.2.3 (Gallery/camera image selection)
- **image_cropper:** ^12.2.1 (Image cropping functionality)
- **image:** ^4.9.1 (Image manipulation)
- **mobile_scanner:** ^7.4.0 (Barcode scanning)

**OCR & Machine Learning:**
- **google_mlkit_document_scanner:** ^0.5.0 (Document scanning)
- **google_mlkit_text_recognition:** ^0.16.0 (OCR text extraction)

**Accessibility & User Experience:**
- **flutter_tts:** ^4.2.5 (Text-to-speech)
- **speech_to_text:** ^7.4.0 (Voice input)
- **local_auth:** ^3.0.2 (Biometric authentication)

**Notifications & Scheduling:**
- **flutter_local_notifications:** ^22.3.0 (Local push notifications)
- **timezone:** ^0.11.1 (Timezone support)
- **flutter_timezone:** ^5.1.0 (Device timezone)

**Localization & Internationalization:**
- **flutter_localizations:** SDK (Flutter localization framework)
- **intl:** ^0.20.2 (Internationalization and formatting)

**File & Data Handling:**
- **file_picker:** ^11.0.2 (File selection)
- **share_plus:** ^12.0.2 (Share functionality)
- **pdf:** ^3.13.0 (PDF generation)
- **printing:** ^5.15.0 (PDF printing)
- **json_annotation:** ^4.12.0 (JSON serialization)

**Utilities:**
- **uuid:** ^4.6.0 (UUID generation)
- **crypto:** ^3.0.7 (Cryptographic operations)
- **permission_handler:** ^12.0.3 (Runtime permissions)
- **cupertino_icons:** ^1.0.8 (iOS-style icons)
- **jni_flutter:** ^1.0.2 (Java Native Interface)

**Development Dependencies:**
- **build_runner:** ^2.7.1 (Code generation)
- **drift_dev:** ^2.34.3 (Drift code generation)
- **json_serializable:** ^6.11.1 (JSON serialization generator)
- **mocktail:** ^1.0.4 (Mocking framework for testing)
- **flutter_lints:** ^6.0.0 (Linting rules)
- **flutter_test:** SDK (Testing framework)

### Backend API (FastAPI)

**Framework & Core:**
- **Python:** >=3.12
- **fastapi:** >=0.115,<1 (Web framework)
- **uvicorn[standard]:** >=0.34,<1 (ASGI server)
- **pydantic-settings:** >=2.7,<3 (Settings management)

**Database & ORM:**
- **sqlalchemy:** >=2.0.36,<3 (ORM and database toolkit)
- **alembic:** >=1.14,<2 (Database migrations)
- **psycopg[binary]:** >=3.2,<4 (PostgreSQL adapter)

**Security & Authentication:**
- **pwdlib[argon2]:** >=0.2,<1 (Password hashing with Argon2)
- **pyjwt:** >=2.10,<3 (JWT token generation/validation)
- **cryptography:** >=45,<47 (Cryptographic primitives)

**HTTP & Data Processing:**
- **httpx:** >=0.28,<1 (Async HTTP client)
- **python-multipart:** >=0.0.20,<1 (Multipart form data)
- **email-validator:** >=2.2,<3 (Email validation)
- **defusedxml:** >=0.7,<1 (Safe XML parsing)

**Logging & Observability:**
- **structlog:** >=25.1,<26 (Structured logging)

**Development & Testing:**
- **pytest:** >=8.3,<9 (Testing framework)
- **pytest-cov:** >=6,<8 (Coverage reporting)
- **mypy:** >=1.14,<2 (Static type checking)
- **ruff:** >=0.9,<1 (Fast Python linter and formatter)
- **types-defusedxml:** >=0.7,<1 (Type stubs)

### Admin Web Portal (Next.js)

**Framework & Core:**
- **Next.js:** 16.3.0 (React framework with server-side rendering)
- **React:** 19.2.4 (UI library)
- **react-dom:** 19.2.4 (React DOM renderer)

**Validation & Type Safety:**
- **zod:** 4.1.12 (Schema validation)
- **TypeScript:** 5.9.3 (Static type checking)

**Development & Testing:**
- **eslint:** 9.39.1 (Linting)
- **eslint-config-next:** 16.3.0 (Next.js ESLint configuration)
- **vitest:** 4.0.9 (Testing framework)
- **@types/node:** 24.10.1 (Node.js type definitions)
- **@types/react:** 19.2.2 (React type definitions)
- **@types/react-dom:** 19.2.2 (React DOM type definitions)

### Infrastructure & DevOps

**Containerization:**
- **Docker:** Multi-stage builds for API and Admin
- **Docker Compose:** Local development orchestration

**Database:**
- **PostgreSQL:** 16-alpine (Primary database)
- **SQLite:** Used for testing and mobile local storage

**CI/CD:**
- **GitHub Actions:** Automated testing, building, and validation
- **Workflows:** CI workflow for pull requests and main branch, Release workflow for deployment

**Development Tools:**
- **uv:** Python package manager (used with uvx)
- **npm:** Node.js package manager
- **Flutter CLI:** Mobile app build and testing

---

## Core Features & Modules

### Module 1: Foundation
**Implemented:** Initial project setup

**Features:**
- Feature-first Flutter code organization
- Riverpod state management composition
- GoRouter declarative navigation
- Localized design-system widgets
- Drift local persistence with SQLite
- Secure session storage (flutter_secure_storage)
- Dio network boundary with interceptors
- Authenticated FastAPI services
- Idempotent user-data outbox for sync
- Owner-scoped database queries
- JWT-based authentication with refresh tokens
- Session management and revocation

**Technical Implementation:**
- SQLAlchemy models with proper relationships
- Alembic migration: `0001_module_1_foundation.py`
- Pydantic schemas for API boundaries
- Argon2 password hashing
- Request ID tracking for observability
- CORS configuration with explicit allowed origins

### Module 2: Terminology & Learning
**Implemented:** Medical terminology and educational content

**Alembic Migration:** `0002_module_2_terminology_and_learning.py`

**Terminology Features:**
- Medical term dictionary with definitions
- Plain-language explanations
- Morphology parsing (prefix/root/suffix breakdown)
- Category organization
- Related term linking
- Synonym and alternative meaning support
- Abbreviation disambiguation
- Search history (device-local only)
- Offline-first terminology access
- Content versioning and updates

**Learning Features:**
- Interactive lessons with objectives
- Flashcard system with spaced repetition
- Multiple flashcard formats: term-to-meaning, meaning-to-term, element-to-meaning, abbreviation-to-expansion
- Quiz engine with multiple question types:
  - Multiple choice
  - True/false
  - Matching
  - Morphology identification
  - Meaning/term selection
  - Abbreviation meaning
- Progress tracking and analytics
- Lesson completion tracking with resume capability
- Quiz attempt history with correctness tracking
- Difficulty-based content filtering
- Category-based recommendations
- Streak tracking
- Dashboard with SQL-based aggregates (no placeholder metrics)

**Data Model:**
- Stable UUID-based terminology IDs
- Immutable numbered revisions
- Review state tracking (draft → in review → approved → published → deprecated → archived)
- Author and reviewer metadata
- Bundled canonical content corpus
- `content_versions` tracking for dataset name/version

**Search & Resolution:**
- Fuzzy matching algorithms
- Morphology-based search
- Public API endpoint: `ResolveMedicalTerm` use case
- No medical text sent to analytics

**Offline Synchronization:**
- Bundled JSON corpus imported at startup
- Development-only corpus validation
- Production corpus requires `production_approved` flag
- Drift schema v2 with migration from v1
- PRAGMA integrity_check after upgrades
- User data syncs via Module 1 outbox (saved items, progress, attempts, reports)

### Module 3: Prescriptions
**Implemented:** Prescription scanning and management

**Alembic Migration:** `0003_module_3_prescriptions.py`

**Features:**
- Camera-based prescription scanning
- OCR text extraction using Google ML Kit
- Image processing with privacy controls
- Prescription parsing and validation
- Medication extraction from scanned text
- User confirmation workflow (OCR text preserved until explicit confirmation)
- Prescription history management
- Image storage in private app directory
- Opaque file naming for privacy
- Temporary file cleanup (24-hour retention policy)
- State machine for prescription lifecycle
- Permission handling for camera access

**Privacy & Security:**
- Android backup disabled
- Private file storage only
- No prescription text in analytics
- Conservative image processing
- Optional image retention
- Stale temporary-file cleanup

**Technical Implementation:**
- Integration with camera and image_picker packages
- google_mlkit_text_recognition for OCR
- image_cropper for user editing
- file_picker for manual selection
- Permission handler for runtime permissions
- Local database storage with Drift

### Module 4: Medication Intelligence & Governance
**Implemented:** Medication resolution, provenance, and administrative controls

**Alembic Migration:** `98e5f4666626_module_4_6_intelligence_governance.py`

**Medication Intelligence Features:**
- Trusted medication identity resolution
- Stable UUID-based medication identities
- Multi-provider medication adapters:
  - **RxNorm:** Identity normalization, RxCUI, brand/generic/ingredient, form and strength candidates
  - **MedlinePlus Connect:** Code-first patient-information links (24-hour caching)
  - **DailyMed API v2:** U.S. SPL lookup and bounded parsing of indications, dosage, contraindications, warnings, precautions, adverse reactions, storage
  - **DRAP (Drug Regulatory Authority of Pakistan):** Reviewed import-only (no web scraping), registration ID, ingredients, barcode support
- Provider health monitoring with circuit breakers
- Evidence-ranked candidate resolution
- Ambiguity handling with user selection
- Structured MedicalFact with full provenance
- Source-aware local snapshots
- Offline medication cache (90-day retention after expiry)
- Barcode resolution
- Provider timeout handling with safe fallbacks
- Stale content preservation
- Per-provider cache keys and TTL
- Health event recording

**Medication Data Model:**
- Separate ingredients/strengths from identifiers/mappings
- Resolution signal retention (not single confidence score)
- Set ID, label version, jurisdiction tracking
- Retrieval time and citation URL
- Registration IDs for country-specific data
- Content hash verification

**Governance Features (Admin Portal):**
- Role-based access control (RBAC):
  - Super Admin
  - Editor
  - Reviewer
  - Support
- Permission-based navigation and actions
- Content lifecycle management
- Version control with immutable revisions
- Independent review requirement (authors cannot approve own content)
- Typed confirmation for sensitive operations
- Import management:
  - JSON import with validation
  - Content hash tracking
  - Staged payload storage
  - Add/update/unchanged/deprecated/rejected reporting
  - Dry-run capability
- Audit logging:
  - Actor tracking
  - Permission context
  - Request ID correlation
  - Target and metadata recording
  - Version references
  - Append-oriented events (no overwrites)
- System health monitoring
- User support interface
- Session management dashboard
- Source management
- Feature flag controls
- Report review queue
- Content annotation (does not overwrite registry evidence)

**Admin Portal Pages:**
- Dashboard overview
- Content management (by type)
- Terminology versions
- Providers management
- Sources tracking
- Feature flags administration
- Import jobs
- Reports review
- Resolution review
- User support
- Sessions monitoring
- Roles & permissions
- Audit logs
- System health metrics

**Security Features:**
- Backend-controlled admin sessions
- Multi-factor authentication (MFA) support
- Separate authentication from mobile app
- Server-only API access
- Secure cookie handling
- CSP headers
- Production MFA enforcement
- No shared tokens with mobile

**AI Safety & RAG:**
- Disabled by default
- Requires both server configuration and `ai_assistant` feature flag
- Rejects treatment/injection intent
- Reloads stable identity and approved facts
- Prefers exact structured sections
- Token-overlap retrieval as bounded fallback
- No personal-history embeddings
- No model-memory retrieval
- Response structure includes:
  - Answer/type
  - Grounding state
  - Application-built source references
  - Safety class
  - Limitations
  - Follow-up suggestions
  - Referenced prescription/medication IDs
  - Language
  - Model usage indicator
- Numeric token validation (must exist in trusted context)
- Generated URL blocking
- Unsafe/injection language detection
- Conflicting jurisdiction handling (no automatic "winner")
- Previous assistant output never used as evidence
- Patient and student mode support
- English/Urdu with canonical name retention

**Disallowed AI Intents:**
- Diagnosis
- Prescribing medications
- Starting/stopping/replacing medicine
- Dose changes
- Invented interactions
- Doctor impersonation
- Ignoring sources
- Fabricated citations

**AI Provider Support:**
- OpenAI-compatible endpoints
- Ollama/local models
- Configurable server-only adapters
- No model keys in mobile/admin bundles
- Conversation encryption at rest
- 30-day retention (configurable)
- Omitted from analytics/admin review

**Emergency Controls:**
- `ai_assistant` server flag disable
- Provider secret rotation
- Source/cache/answer review process

### Module 5: Medication Assistant
**Implemented:** Medication schedules, reminders, and tracking

**Alembic Migration:** `0004_module_5_medication_assistant.py`

**Features:**
- Medication schedule creation
- Medication plan management
- Local push notifications for reminders
- Medication history tracking
- Dose logging ("taken" status)
- Medication safety checks
- Schedule engine with recurring events
- Timezone support
- Notification scheduling
- Medication interaction warnings (interface exists, runtime disabled until configured)

**Technical Implementation:**
- flutter_local_notifications for alerts
- timezone and flutter_timezone for proper scheduling
- Drift storage for medication plans and history
- Background notification handling
- Schedule calculation engine
- Safety validation service

### Module 6: Complete Platform Integration
**Implemented:** Full system integration and production readiness

**Features:**
- Flutter schema v5 for complete data model
- Full source/provenance snapshot caching
- Offline copy staleness marking
- Recent/saved state persistence
- Complete UI flows:
  - Search interface
  - Ambiguity resolution
  - Candidate confirmation
  - Detail sections
  - Warning viewer
  - Side-effect viewer
  - Source viewer
  - No-match handling
  - Provider failure states
  - Barcode result display
  - Report submission
  - Grounded chat interface
- Separation of concerns:
  - Prescription values
  - General facts
  - User notes
  - Generated explanations
- Complete admin API integration
- Server actions for mutations
- Backend permission enforcement
- Optimistic UI updates
- Validation/dry-run/apply workflow

**Additional Enhancements:**
- DRAP indexes: `c9ce88999c02_add_drap_indexes.py`
- Performance optimization
- Database query optimization

---

## Database Architecture

### Mobile Database (Drift/SQLite)

**Schema Versions:**
- v1: Module 1 foundation (users, sessions, sync outbox)
- v2: Module 2 terminology and learning tables
- v5: Complete schema with full medication intelligence

**Tables (Representative):**
- User sessions and credentials
- Terminology entries with morphology
- Lessons and learning content
- Flashcard schedules
- Quiz attempts and progress
- Prescriptions and images
- Medications and plans
- Medication history
- Saved bookmarks
- Content versions
- Search history (device-local)
- Sync outbox for idempotent operations

**Features:**
- Type-safe queries via code generation
- Migration support with integrity checks
- Indexed searches
- Foreign key constraints
- Offline-first design

### Backend Database (PostgreSQL)

**Migrations (Alembic):**
1. `0001_module_1_foundation.py` - Users, sessions, auth
2. `0002_module_2_terminology_and_learning.py` - Medical content, learning
3. `0003_module_3_prescriptions.py` - Prescription management
4. `98e5f4666626_module_4_6_intelligence_governance.py` - Medication intelligence, governance, admin
5. `0004_module_5_medication_assistant.py` - Medication schedules, reminders
6. `c9ce88999c02_add_drap_indexes.py` - Performance indexes

**Key Tables:**
- Users with owner-scoped isolation
- Sessions with refresh tokens
- Terminology with versioning
- Lessons and quizzes
- Prescriptions
- Medication identities
- Medical facts with provenance
- Provider cache
- DRAP product registry
- Content governance (drafts, reviews, approvals)
- Admin users and roles
- Permissions
- Audit events
- Feature flags
- Import jobs
- Content reports
- AI conversations (encrypted)

**Features:**
- ACID transactions
- Row-level owner scoping
- Immutable revision tracking
- Cascade deletes for user data
- Policy-driven audit retention
- Parameterized queries (SQL injection prevention)
- Health checks

---

## Security Implementation

### Authentication & Authorization

**Mobile App:**
- JWT-based session tokens
- Refresh token rotation
- Hashed refresh tokens in database
- Token issuer/audience validation
- Session binding
- Secure credential storage (platform keychain)
- Biometric lock option
- No production secrets in binary

**Admin Portal:**
- Separate authentication domain
- Backend-controlled sessions
- MFA support (production-enforced)
- Role-based permissions
- Permission-based UI rendering
- Secure cookie handling
- CSP headers

**API Security:**
- Argon2 password hashing
- Short-lived JWTs
- Session revocation capability
- Owner-scoped database queries
- Strict Pydantic validation
- SQLAlchemy parameterization
- Explicit CORS configuration
- Request ID tracking
- No request body logging
- Structured log redaction (password/token/auth/cookie/prescription/medication)

### Rate Limiting

**Protected Endpoints:**
- Authentication (login, register)
- Password reset
- Admin login
- Terminology search
- Medicine search
- Barcode resolution
- AI assistant
- Content reports
- Import jobs

**Implementation:**
- Fixed-window algorithm
- In-memory adapter (single process)
- Distributed rate limiting required for multi-instance production
- Ingress/shared rate limiting documentation provided

### Privacy Controls

**Data Minimization:**
- Search history stays local (never sent to server)
- Raw search strings not in analytics
- Prescription images in private app directory
- Opaque file naming
- No medical text in analytics
- AI conversations encrypted at rest

**Retention Policies:**
- Temporary scans: 24 hours
- AI conversations: 30 days (configurable)
- Exports: 24 hours
- Provider cache: 90 days after expiry
- Backup retention: 30 days
- Audit retention: Policy-driven (not auto-deleted)

**Account Deletion:**
- Database cascades for user data:
  - Sessions
  - Prescriptions
  - Medication plans/history
  - Saved records
  - Reports
  - AI conversations/messages
- Mobile private images removed locally
- Governance/audit records use actor nulling or controlled retention

**Mobile Security (MASVS-oriented):**
- No production secrets in binary
- Secure credential vault
- HTTPS required in production
- Private file storage
- Android backup disabled
- Explicit runtime permissions
- Biometric lock option
- No direct database access
- Local OCR processing
- No medical-text analytics

### Compliance & Safety

**Medical Information Safety:**
- Trusted source requirement
- Provenance tracking
- Validation before user presentation
- OCR/AI never authoritative medical sources
- Abbreviation ambiguity explicit
- No automatic content synthesis
- Content reports queued for review (no auto-mutation)
- Independent content review requirement

**Source Attribution:**
- NLM/RxNorm attribution preserved
- MedlinePlus title/link intact
- DailyMed set ID and citation URL tracked
- DRAP registration ID and source retained
- All external data marked with retrieval time and jurisdiction

---

## External Integrations

### Medical Data Providers

**RxNorm (NLM):**
- Endpoint: `https://rxnav.nlm.nih.gov/REST/Prescribe/drugs.json`
- Purpose: Medication identity normalization, RxCUI, brand/generic/ingredient mapping
- Limitations: U.S.-centric (Pakistani products may not match)
- Attribution: NLM/RxNorm source licensing preserved
- Implementation: REST client with timeout and circuit breaker

**MedlinePlus Connect:**
- Endpoint: `https://connect.medlineplus.gov/service`
- Purpose: Code-first patient-information links
- Cache: 24-hour (within 12–24-hour guidance)
- Rate Limit: 100 requests/minute/IP (must be respected)
- Attribution: Title/link attribution intact

**DailyMed API v2:**
- Endpoint: `https://dailymed.nlm.nih.gov/dailymed/services/v2`
- Purpose: U.S. SPL lookup, label parsing
- Data Extracted: Indications, dosage, contraindications, warnings, precautions, adverse reactions, storage
- Tracking: Set ID, label version, jurisdiction, retrieval time, citation URL

**DRAP (Drug Regulatory Authority of Pakistan):**
- Implementation: Import-only via reviewed admin jobs
- No web scraping (no stable API found)
- Data: Registration ID, product name, ingredients, optional barcode
- Import Format: Validated CSV with content hash
- File: `data/drap_snapshot.csv`

### Provider Infrastructure

**Common Features:**
- Finite HTTP timeouts
- No automatic redirects
- Circuit breaker pattern
- Source-specific cache keys
- TTL and content hash validation
- Stale content preservation
- Independent health event recording
- Server flags for disable/enable without mobile release

**Error Handling:**
- Safe error codes (no sensitive data leakage)
- Timeout fallbacks
- Provider unavailability states
- No ungrounded fallback content
- Explicit user communication

---

## Testing Strategy

**Total Test Files:** 245+ test files across all platforms

### Mobile Testing (Flutter)

**Test Coverage:**
- Unit tests for business logic
- Widget tests for UI components
- Integration tests for complete flows
- State machine testing
- Repository testing
- Privacy compliance testing
- Permission handling testing
- Notification testing
- Schedule engine testing
- Safety validation testing

**Test Files Include:**
- `session_manager_test.dart`
- `sync_coordinator_test.dart`
- `local_database_test.dart`
- `routing_test.dart`
- `startup_coordinator_test.dart`
- `module2_learning_offline_test.dart`
- `module2_terminology_test.dart`
- `settings_repository_test.dart`
- `medication_repository_test.dart`
- `medication_notification_test.dart`
- `schedule_engine_test.dart`
- `medication_safety_test.dart`
- `medication_intelligence_models_test.dart`
- `prescription_pipeline_integration_test.dart`
- `prescription_state_machine_test.dart`
- `prescription_parser_test.dart`
- `prescription_permission_test.dart`
- `image_processing_privacy_test.dart`
- `auth_controller_test.dart`

**Testing Commands:**
```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed lib test
```

### Backend Testing (FastAPI)

**Test Coverage:**
- Unit tests for services and repositories
- API endpoint tests
- Database model tests
- Authentication flow tests
- Provider adapter tests
- AI safety validation tests (11 red-team prompts)
- Migration tests

**Testing Tools:**
- pytest for test execution
- pytest-cov for coverage reporting
- Deterministic evaluation for AI outputs
- Red-team prompts for safety validation

**Testing Commands:**
```bash
uv run pytest
uv run pytest-cov
uv run mypy app
uv run ruff check app tests alembic
uv run ruff format --check app tests alembic
uv run alembic check
```

**AI Safety Test Scenarios:**
- Prescription/dose manipulation
- Stopping medication
- Diagnosis requests
- Interaction fabrication
- Source bypass attempts
- Citation fabrication
- Doctor impersonation
- Source injection
- Expected result: `unsafe_to_answer` with no model use

### Admin Testing (Next.js)

**Test Coverage:**
- Component tests
- API route tests
- Navigation tests
- Permission tests

**Testing Commands:**
```bash
npm test (vitest run)
npm run lint
npm run typecheck
npm run build
```

### CI/CD Pipeline

**GitHub Actions Workflows:**

**CI Workflow (`.github/workflows/ci.yml`):**
- Triggered on pull requests and main branch pushes
- Three parallel jobs:
  1. **Backend Job:**
     - Python 3.12 setup with uv
     - Dependency installation (locked)
     - Ruff format checking
     - Ruff linting
     - MyPy type checking
     - Pytest execution
     - Alembic migration test (SQLite)
     - Docker build test
  2. **Admin Job:**
     - Node.js 22 setup
     - npm ci (clean install)
     - ESLint
     - TypeScript type checking
     - Vitest tests
     - Production build
     - Docker build test
  3. **Flutter Job:**
     - Flutter stable channel
     - Dependency installation
     - Dart format checking
     - Flutter analyze
     - Flutter test
     - Debug APK build
     - Release app bundle build (production config)
  4. **Dependency Review Job:**
     - Runs on pull requests only
     - Automated dependency vulnerability scanning

**Release Workflow (`.github/workflows/release.yml`):**
- Protected staging/production environments
- Immutable image builds
- Environment-specific deployment
- Approval gates
- Note: Registry/deployment commands intentionally environment-specific

---

## Deployment Architecture

### Local Development

**Docker Compose Stack:**
```yaml
services:
  - postgres (PostgreSQL 16-alpine)
  - api (FastAPI service)
  - admin (Next.js application)
```

**Startup Command:**
```bash
docker compose up --build
```

**Service Access:**
- API: `http://localhost:8000`
- Admin: `http://localhost:3000`
- Database: `localhost:5432`

**Mobile Development:**
```bash
cd apps/mobile
flutter pub get
flutter run --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1/
```

### Production Requirements

**Infrastructure:**
- External managed PostgreSQL (not Docker)
- Unique secrets from secret manager:
  - JWT secret key
  - Database credentials
  - API provider keys
  - Model API keys (if AI enabled)
  - MFA secrets
- TLS/HTTPS endpoints
- Trusted CORS origins
- Production MFA enforcement
- Ingress rate limiting for multiple workers
- Encrypted backup scheduling
- Central logging and metrics
- Health check monitoring

**Deployment Process:**
1. Run `alembic upgrade head` as single pre-deploy job
2. Build Docker images from locks
3. Start replicas with health checks
4. Route traffic only after readiness
5. Never run concurrent migrations
6. Roll back application first (schema downgrades require planning)

**Mobile Production Build:**
```bash
flutter build appbundle --release \
  --dart-define=APP_ENV=production \
  --dart-define=API_BASE_URL=https://api.production.example/api/v1/
```

**Configuration Requirements:**
- `APP_ENV=production` for mobile
- `ADMIN_COOKIE_SECURE=true` (omit false flag)
- `ai_assistant` feature flag enabled (if using AI)
- Validated interaction provider (currently disabled)
- Approved DRAP dataset import

**Docker Images:**
- Deterministic builds from lock files
- Non-root users
- Health check endpoints
- Graceful SIGTERM handling
- Multi-stage builds for size optimization

**Operational Scripts:**
- `ops/retention_cleanup.py`: Deletes expired AI conversations and provider cache (transactional)

---

## Key Design Decisions & Rationale

### 1. Offline-First Architecture
**Decision:** Mobile app operates fully offline with optional sync  
**Rationale:** Healthcare contexts often have poor connectivity; users need reliable access to critical medication information

### 2. Separate Authentication Domains
**Decision:** Mobile and admin use completely separate auth systems  
**Rationale:** Security isolation; admin privileges should never leak to mobile tokens

### 3. Stable UUID Identities
**Decision:** Medications use stable UUIDs separate from text/identifiers  
**Rationale:** Allows medication identity to persist across name changes, provider updates, and ambiguity resolution

### 4. Provenance-First Medical Data
**Decision:** All medical facts include full source provenance  
**Rationale:** Medical information must be traceable to trusted sources; users deserve transparency

### 5. OCR Not Authoritative
**Decision:** OCR text preserved until explicit user confirmation  
**Rationale:** OCR can make mistakes; users must confirm before medication resolution

### 6. Import-Only DRAP
**Decision:** No web scraping; only reviewed admin imports  
**Rationale:** No stable API exists; web scraping is fragile and can violate terms; import allows validation

### 7. AI Disabled by Default
**Decision:** AI assistant requires explicit server config and feature flag  
**Rationale:** AI carries risks; should only be enabled after proper configuration and safety review

### 8. Immutable Content Revisions
**Decision:** Content uses numbered immutable revisions  
**Rationale:** Audit trail for medical content; ability to revert; accountability

### 9. Independent Review Requirement
**Decision:** Authors cannot approve their own content  
**Rationale:** Medical accuracy requires independent validation

### 10. Local Search History
**Decision:** Search history never sent to server  
**Rationale:** Medical searches are sensitive; privacy-first approach

### 11. Owner-Scoped Queries
**Decision:** All database queries automatically scope to authenticated user  
**Rationale:** Prevents data leakage between users; defense in depth

### 12. Multi-Provider Medication Resolution
**Decision:** Multiple medication providers with evidence ranking  
**Rationale:** No single provider has global coverage; evidence-based ranking improves accuracy

### 13. Bounded AI Grounding
**Decision:** AI must ground responses in retrieved structured data  
**Rationale:** Prevents hallucination of medical information; keeps AI as explainer not source

### 14. Idempotent Sync Outbox
**Decision:** User mutations use idempotency keys and retry logic  
**Rationale:** Network can fail; operations must be safely retryable without duplication

### 15. No Test Generation by Default
**Decision:** Tests written explicitly, not auto-generated  
**Rationale:** Medical software requires thoughtful test scenarios; auto-generation insufficient

---

## Project Structure

```
/Users/mm/Medi-Pres/
├── .github/
│   └── workflows/
│       ├── ci.yml                  # CI pipeline
│       └── release.yml             # Release workflow
├── apps/
│   ├── admin/                      # Next.js admin portal
│   │   ├── app/                    # Next.js app directory
│   │   │   ├── (admin)/           # Protected admin routes
│   │   │   ├── api/               # API routes
│   │   │   ├── login/             # Login page
│   │   │   └── layout.tsx         # Root layout
│   │   ├── components/            # React components
│   │   ├── lib/                   # Utilities and API client
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   └── tsconfig.json
│   └── mobile/                     # Flutter mobile app
│       ├── lib/
│       │   ├── app/               # App configuration
│       │   ├── core/              # Core services
│       │   ├── design_system/     # UI components
│       │   ├── domain/            # Domain models
│       │   ├── features/          # Feature modules
│       │   │   ├── auth/
│       │   │   ├── home/
│       │   │   ├── intelligence/
│       │   │   ├── learning/
│       │   │   ├── medications/
│       │   │   ├── onboarding/
│       │   │   ├── prescription/
│       │   │   ├── profile/
│       │   │   ├── saved/
│       │   │   ├── settings/
│       │   │   ├── shell/
│       │   │   └── terminology/
│       │   ├── l10n/              # Localization
│       │   └── main.dart
│       ├── test/                  # Flutter tests
│       ├── assets/                # Asset files
│       ├── android/               # Android config
│       ├── ios/                   # iOS config
│       ├── pubspec.yaml
│       └── analysis_options.yaml
├── services/
│   └── api/                        # FastAPI backend
│       ├── alembic/               # Database migrations
│       │   └── versions/
│       │       ├── 0001_module_1_foundation.py
│       │       ├── 0002_module_2_terminology_and_learning.py
│       │       ├── 0003_module_3_prescriptions.py
│       │       ├── 98e5f4666626_module_4_6_intelligence_governance.py
│       │       ├── 0004_module_5_medication_assistant.py
│       │       └── c9ce88999c02_add_drap_indexes.py
│       ├── app/
│       │   ├── api/               # API routes
│       │   ├── core/              # Core services
│       │   ├── db/                # Database config
│       │   ├── models/            # SQLAlchemy models
│       │   ├── providers/         # External provider adapters
│       │   ├── repositories/      # Data access layer
│       │   ├── schemas/           # Pydantic schemas
│       │   ├── services/          # Business logic
│       │   ├── factory.py
│       │   └── main.py
│       ├── tests/                 # Python tests
│       ├── Dockerfile
│       ├── pyproject.toml
│       └── alembic.ini
├── data/
│   └── drap_snapshot.csv          # DRAP dataset
├── docs/                          # Comprehensive documentation
│   ├── ARCHITECTURE.md
│   ├── MODULE_4_6_FINAL.md
│   ├── MEDICAL_RAG.md
│   ├── MEDICATION_PROVIDERS.md
│   ├── CONTENT_GOVERNANCE.md
│   ├── DEPLOYMENT.md
│   ├── SECURITY.md
│   ├── PRIVACY.md
│   ├── AI_SAFETY.md
│   ├── OFFLINE_TERMINOLOGY.md
│   ├── LEARNING_ENGINE.md
│   └── [20+ additional docs]
├── ops/
│   └── retention_cleanup.py       # Cleanup script
├── docker-compose.yml
├── README.md
├── SCOPE_AND_USE_CASES.md
└── CREDENTIALS.md
```

---

## Use Cases & User Flows

### Primary Use Cases

#### 1. Patient Scanning Prescription
**Actor:** Patient  
**Flow:**
1. Patient opens mobile app
2. Navigates to prescription scanning
3. Grants camera permission
4. Captures prescription image
5. ML Kit extracts text via OCR
6. User confirms extracted text
7. System parses medications and dosages
8. Resolves medications via multiple providers (RxNorm, DRAP, etc.)
9. Presents medication details with sources
10. Option to save prescription and set reminders

#### 2. Understanding Medical Term
**Actor:** Patient  
**Flow:**
1. Patient encounters confusing medical term
2. Opens app search
3. Types or speaks term
4. Fuzzy search matches terminology database
5. Views plain-language definition
6. Sees morphology breakdown (prefix/root/suffix)
7. Reads related terms and synonyms
8. Option to save for later
9. All data available offline

#### 3. Learning Medical Literacy
**Actor:** Patient/Student  
**Flow:**
1. User navigates to learning section
2. Views recommended lessons based on progress
3. Starts lesson with objectives
4. Reads through content sections
5. Answers review questions
6. Completes lesson, progress tracked
7. Receives flashcard recommendations
8. Reviews flashcards with spaced repetition
9. Takes quiz to test knowledge
10. Views results with mistake review
11. Dashboard shows streaks and progress

#### 4. Setting Medication Reminders
**Actor:** Patient  
**Flow:**
1. User has prescription in system
2. Navigates to medication plans
3. Sets up schedule (time, frequency, duration)
4. App schedules local notifications
5. User receives reminder at specified time
6. Taps notification to view details
7. Marks medication as taken
8. History logged for adherence tracking

#### 5. Asking About Medication
**Actor:** Patient  
**Flow:**
1. User views medication details
2. Taps AI assistant (if enabled)
3. Asks question about medication
4. System retrieves structured facts from trusted sources
5. Optionally generates grounded explanation
6. Validates answer for safety
7. Presents answer with source citations
8. Shows grounding state and limitations
9. Conversation encrypted and retained per policy

#### 6. Content Editor Publishing Medical Term
**Actor:** Content Editor  
**Flow:**
1. Editor logs into admin portal with MFA
2. Navigates to content management
3. Creates new terminology entry
4. Adds definition, morphology, sources
5. Submits for review
6. Reviewer receives notification
7. Reviewer checks medical accuracy
8. Approves content (cannot approve own)
9. Publisher publishes to production
10. Content syncs to mobile users
11. Audit log records all actions

#### 7. Admin Importing DRAP Data
**Actor:** Super Admin  
**Flow:**
1. Admin receives updated DRAP dataset CSV
2. Logs into admin portal
3. Navigates to import jobs
4. Uploads DRAP CSV file
5. System validates format and content
6. Generates import report (added/updated/rejected)
7. Admin reviews dry-run results
8. Confirms apply operation
9. System imports to medication registry
10. Audit event recorded
11. Data available for medication resolution

#### 8. Reviewer Handling Content Report
**Actor:** Content Reviewer  
**Flow:**
1. User submits content report from mobile
2. Report queued in admin system
3. Reviewer views reports dashboard
4. Selects report for review
5. Views reported content and user feedback
6. Investigates accuracy with sources
7. Creates correction if needed
8. Updates content status
9. Optional user communication
10. Resolution tracked in audit log

---

## Known Limitations & Future Work

### Current Limitations

1. **Interaction Checking:** Interface exists but runtime disabled; no validated licensed interaction database configured
2. **DRAP API:** No stable public machine API found; relies on manual import of approved datasets
3. **AI Providers:** Disabled by default; requires explicit configuration and feature flag
4. **MFA Provisioning:** Production admin MFA must be provisioned (not included)
5. **Release Signing:** Mobile app signing and production infrastructure credentials not in repository
6. **Geographic Coverage:** RxNorm is U.S.-centric; Pakistani products may not match
7. **Rate Limiting:** In-memory adapter for single process; production requires distributed rate limiting
8. **Telemedicine:** No video/audio consultation features
9. **EHR Integration:** No direct hospital EHR system integration
10. **Pharmacy Integration:** No prescription fulfillment or medication ordering

### Production Checklist Items

From `docs/PRODUCTION_CHECKLIST.md`:
- External managed PostgreSQL configuration
- Secret manager integration
- TLS/HTTPS setup
- Trusted CORS origins configuration
- Production MFA provisioning
- Distributed rate limiting
- Encrypted backup scheduling
- Central logging and metrics
- Approved DRAP dataset import
- Validated interaction provider (future)
- AI safety review and configuration
- Mobile app store deployment
- Release signing certificates

---

## Development & Contribution Guidelines

### Code Quality Standards

**Backend (Python):**
- Type hints required (mypy strict mode)
- Ruff formatting and linting
- 100-character line length
- Structured logging with structlog
- Comprehensive docstrings

**Mobile (Flutter):**
- Dart format compliance
- Flutter analyze passing
- Feature-first organization
- Riverpod for state management
- Design system components

**Admin (Next.js):**
- TypeScript strict mode
- ESLint compliance
- Server components by default
- Zod validation for all inputs

### Testing Requirements

- Unit tests for business logic
- Integration tests for critical flows
- Type checking must pass
- Linting must pass
- Code coverage tracked
- AI safety validation included

### Git Workflow

- Feature branches from main
- Pull request required
- CI must pass (all jobs green)
- Dependency review for PRs
- No direct commits to main

### Documentation Standards

- Architecture decisions documented
- API endpoints documented
- Security controls documented
- Privacy policies documented
- Deployment procedures documented
- 25+ comprehensive documentation files in `/docs`

---

## Observability & Monitoring

### Logging

**Structured Logging:**
- Request ID correlation across services
- Actor/user context
- Timestamp with timezone
- Log level (DEBUG, INFO, WARNING, ERROR)
- Safe error codes (no sensitive data leakage)

**Redaction:**
- Automatic redaction of sensitive keys: password, token, auth, cookie, prescription, medication
- No request bodies logged
- Metrics use bounded normalized labels
- AI/provider errors are safe codes

**Log Aggregation:**
- Production requires central logging
- Log retention policies
- Search and filtering capabilities

### Metrics

**Application Metrics:**
- Request rate and latency
- Error rates by endpoint
- Provider health events
- Cache hit/miss rates
- Database query performance
- Circuit breaker state

**Business Metrics:**
- User registration and activation
- Prescription scans performed
- Medication lookups
- Learning progress
- Quiz completions
- Content report submissions

### Health Checks

**API Health Endpoints:**
- `/api/v1/ready`: Readiness probe (database connectivity)
- `/api/v1/health`: Liveness probe

**Database Health:**
- Connection pool monitoring
- Query performance tracking
- Migration status

**External Provider Health:**
- Response time tracking
- Timeout monitoring
- Circuit breaker state
- Cache staleness

### Alerts

**Recommended Alerts:**
- API error rate threshold
- Database connection failures
- Provider timeout rate
- Authentication failures
- Migration failures
- Disk space warnings
- Memory usage warnings

---

## Compliance & Governance

### Medical Information Governance

**Content Lifecycle:**
1. Draft (editor creates)
2. In Review (editor submits)
3. Approved (reviewer approves)
4. Published (publisher publishes)
5. Deprecated (marked for replacement)
6. Archived (removed from active use)

**Review Requirements:**
- Independent review (author ≠ reviewer)
- Medical accuracy validation
- Source verification
- Jurisdiction tracking
- Version control

### Audit Trail

**Audit Events Include:**
- Actor (user/admin who performed action)
- Permission context
- Request ID
- Timestamp
- Target (affected resource)
- Metadata (safe, non-sensitive)
- Version references
- Action type

**Audit Scope:**
- Content creation/modification
- Admin permission changes
- Import job execution
- Feature flag changes
- User account actions
- Sensitive configuration changes

### Data Retention

**User Data:**
- Temporary scans: 24 hours
- AI conversations: 30 days (configurable)
- Exports: 24 hours
- Provider cache: 90 days after expiry
- Backups: 30 days

**Governance Data:**
- Audit logs: Policy-driven retention (not auto-deleted)
- Content versions: Retained indefinitely
- Import jobs: Retained for compliance

**Account Deletion:**
- Cascading deletes for user-owned data
- Policy-driven actor nulling for governance records
- Preservation of referential integrity

---

## Summary

MediExplain is a production-ready, multi-platform medical literacy application with a comprehensive architecture spanning mobile, backend, and administrative interfaces. The system demonstrates:

- **Robust Engineering:** 245+ tests, CI/CD pipeline, type safety, comprehensive error handling
- **Medical Safety:** Provenance tracking, trusted sources, independent review, AI safety controls
- **Privacy-First Design:** Local-first storage, encryption, minimal data collection, retention policies
- **Scalable Architecture:** Microservices, offline-first, provider abstraction, feature flags
- **Complete Feature Set:** Prescription scanning, terminology lookup, learning engine, medication reminders, AI assistant, governance portal
- **Production-Ready:** Docker deployment, migration system, health checks, observability, security controls
- **International Support:** English/Urdu localization, multiple medication registries (RxNorm, DRAP, DailyMed, MedlinePlus)

The implementation spans 6 major modules, uses 50+ third-party libraries, includes 6 database migrations, and contains extensive documentation covering architecture, security, privacy, deployment, and governance.

**Key Technologies:**
- **Mobile:** Flutter 3.12.2, Riverpod, Drift, Google ML Kit
- **Backend:** Python 3.12, FastAPI, SQLAlchemy, PostgreSQL 16
- **Admin:** Next.js 16, React 19, TypeScript 5.9
- **Infrastructure:** Docker, Docker Compose, GitHub Actions

**Development Status:** Module 4 + 6 final implementation completed August 13, 2026. System is functional for development and ready for production deployment with appropriate infrastructure provisioning.
