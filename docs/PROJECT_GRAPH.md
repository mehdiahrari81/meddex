# MediExplain project graph

This graph maps the implementation in this checkout. It separates patient data, reviewed reference content, administrative governance, and external services.

```mermaid
flowchart TB
  Patient[Patient · English / Urdu]
  Staff[Editor / Reviewer / Support / Administrator]

  subgraph Mobile[apps/mobile · Flutter]
    Router[GoRouter + Riverpod]
    Auth[Authentication + secure session vault]
    Terms[Terminology search + word decoder]
    Learn[Lessons + quizzes + flashcards + progress]
    Scan[Camera / files / barcode → on-device OCR]
    Confirm[Prescription review + explicit confirmation]
    Meds[Medication plans + dose history + export]
    Remind[Schedule engine + local notifications]
    Intelligence[Medication resolution + cited explanations]
    Local[(Account-scoped Drift / SQLite + private images)]
    Outbox[Idempotent sync outbox]
    Settings[Accessibility + privacy + biometric lock]
  end

  subgraph Admin[apps/admin · Next.js]
    SignIn[Admin sign-in + HttpOnly cookie]
    Actions[Server actions + permission-based navigation]
    Content[Inspect revisions → draft → independent review → publish]
    Imports[Source import → dry run → apply]
    Ops[Reports + sessions + flags + audit + health]
  end

  subgraph API[services/api · FastAPI]
    Boundary[Validation + rate limits + request IDs]
    Identity[JWT audiences + sessions + permission checks]
    UserAPI[Owner-scoped patient resources]
    Reference[Reviewed terminology + learning APIs]
    Governance[Governance service + audit events]
    Resolve[Evidence-ranked medication resolution]
    RAG[Structured retrieval + grounding + output validation]
    Cache[Provider cache + provenance + freshness]
    DB[(PostgreSQL · Alembic migrations)]
    Mail[SMTP password reset → local Mailpit inbox]
  end

  subgraph Sources[External source boundaries]
    Trusted[RxNorm / MedlinePlus / DailyMed]
    DRAP[Reviewed DRAP dataset]
    Model[Optional configured language model]
  end

  Patient --> Router
  Router --> Auth & Terms & Learn & Scan & Meds & Intelligence & Settings
  Scan --> Confirm --> Meds --> Remind
  Terms & Learn & Confirm & Meds & Intelligence --> Local
  Local --> Outbox --> Boundary
  Auth & Intelligence --> Boundary
  Staff --> SignIn --> Actions
  Actions --> Content & Imports & Ops
  Content & Imports & Ops --> Boundary
  Boundary --> Identity
  Identity --> UserAPI & Governance & Resolve & RAG
  Boundary --> Reference
  Governance -->|Published reference release| Reference
  Reference -->|Validated atomic offline refresh| Local
  UserAPI & Reference & Governance & Resolve & RAG & Cache --> DB
  Resolve & RAG --> Cache --> Trusted
  DRAP --> Imports
  RAG --> Model
  Identity --> Mail
```

## Ownership and acceptance checks

| Area | Implementation | Verification |
| --- | --- | --- |
| Authentication and sessions | `core/auth`, `core/network`, `features/auth`; API auth service and routers | Register, login, refresh, offline recovery, logout, session revocation, audience separation |
| Terminology and learning | Mobile terminology/learning features; API terminology/learning/module2 routers | Reviewed-only search, ambiguity, saved content, quizzes, spaced repetition, offline data |
| Prescription pipeline | Mobile prescription feature; API prescriptions router | Capture permissions, private files, OCR correction, confirmation state machine, owner-scoped sync |
| Medication management | Mobile medications feature; API medications router | Confirmed plans, schedule boundaries, dose conflicts, reminders, export, privacy |
| Medication intelligence | Mobile intelligence feature; API providers, medication intelligence, medical RAG | Evidence, stable identities, citations, stale cache, safe unavailable states |
| Administration | Next.js routes/actions; API admin auth and governance | Permissions, MFA, editorial transitions, imports, reports, sessions, audit |
| Delivery and operations | Compose, Dockerfiles, CI, `ops`, deployment documents | Fresh migrations, schema check, deterministic builds, readiness, backup/restore |

## Runtime boundaries

- Patient and admin tokens use separate audiences. The API enforces access independently of visible navigation.
- OCR extracts text. The user confirms it before medication plans are created.
- External reference providers supply medical evidence. Optional AI explains retrieved evidence and cannot create medical facts.
- Reference datasets and patient mutations have separate update paths.
- Bundled seeds populate fresh databases only; startup preserves downloaded or published releases. A failed reference update preserves bookmarks and learning progress.
- Authenticated accounts and guests have separate local data and outboxes. A transport bound to one account rejects requests after the account changes.
- Device camera, biometrics, notifications, speech, Android/iOS signing, source licensing, and deployed infrastructure require checks in their actual runtime environments.

See [release verification](RELEASE_VERIFICATION.md) for measured results and remaining release requirements.
