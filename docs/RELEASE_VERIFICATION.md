# Release verification

## Acceptance standard

The release must start from documented setup, compile all applications, pass automated checks, preserve offline data during transient failures, enforce patient/admin boundaries, and expose honest success/error states. Production readiness additionally requires deployment credentials, reviewed content, signing, and physical-device verification.

## Scope and results · 2026-10-12

The agreed scope is a working local development build and documented production requirements. No external deployment was performed. This checkout has no `.git` directory; changes are present directly in the workspace.

| Check | Result |
| --- | --- |
| API lint, formatting, strict typing | Pass; 63 typed application source files |
| API tests | 99 passed after AI fixes |
| SQLite migration upgrade and schema comparison | Pass; no new upgrade operations |
| PostgreSQL 16 migrations | Fresh upgrade, final index downgrade/re-upgrade, and schema comparison pass; no new upgrade operations |
| Flutter formatting and analysis | Pass; no analyzer issues |
| Flutter tests | 134 passed after AI/voice fixes |
| Android debug APK | Built at `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk` |
| Admin ESLint, TypeScript, unit test, production build | Pass; 1 navigation unit test |
| Real Chrome browser workflows | 9 passed against an isolated API database and built standalone admin |
| Runtime Node dependency audit | 0 vulnerabilities reported by `npm audit --omit=dev` |
| Local Docker stack: PostgreSQL + API + admin + Mailpit | All four healthy; migrations, seed preservation, SMTP reset, browser admin login/dashboard/logout verified |
| Live API smoke scenarios against running PostgreSQL | 26 passed; synthetic accounts removed |
| Live AI source retrieval and model input/output | 9 passed; real English/Urdu generation and safety fallbacks, disposable account removed |
| Android API 36 emulator | Runtime smoke testing performed; see the [smoke report](SMOKE_TEST_REPORT.md) for exact coverage and fixes |

The root `scripts/verify-local.sh --browser` command was run successfully with `PLAYWRIGHT_CHANNEL=chrome`. The final APK was rebuilt after the mobile changes. The SMTP check exercised registration, real captured mail, reset-code single use, old-password rejection, successful new-password login, and revocation of the previous session. Synthetic smoke-test users were deleted afterward.

After the [admin dashboard redesign](ADMIN_DASHBOARD.md), API and admin checks were rerun separately: 75 API tests, 9 Chrome workflows, lint/formatting/types, the admin unit test, and its production build passed. The actual Docker portal was rebuilt and visually checked at phone and desktop widths. It now contains labeled demonstration content, reports, and invalid-import examples. Seeding twice against PostgreSQL confirmed that repeat runs add no duplicates; the API suite also verifies preservation of edits.

The later [AI and voice pass](AI_FEATURES.md) reran the API suite (99 passed), Flutter suite (134 passed), analysis, typing, formatting, and Android build/native-library inspection. Nine live API scenarios exercised the actual local Ollama model and official medicine sources. The prior admin browser evidence remains from the dashboard pass; admin code was not changed by the AI fixes. Exact outputs and remaining device/clinical limits are in the [smoke report](SMOKE_TEST_REPORT.md).

## Running workspace instance

The isolated Compose project `mediexplain-local` was left running with admin at http://localhost:13001, API documentation at http://localhost:18000/docs, and Mailpit at http://localhost:18025. PostgreSQL uses loopback port 15432 and SMTP uses 16025. The API's port 18000 is also available to a local mobile device. Android Emulator should use `http://10.0.2.2:18000/api/v1/` for this instance.

Create your own administrator interactively (replace the example identity):

```sh
docker compose -p mediexplain-local exec api python -m app.cli provision-admin \
  --email you@example.com --name "Your Name" --role SUPER_ADMIN --mfa
```

No default account or temporary verification administrator remains. Named accounts requested for manual testing are preserved in this workspace; their credentials are recorded only in the private, ignored `CREDENTIALS.md`. The general [local setup guide](LOCAL_DEVELOPMENT.md) also documents starting a separate instance on default ports.

## Completed fixes

The later [runtime smoke pass](SMOKE_TEST_REPORT.md) also repaired Android release internet permission, an incomplete local NDK/native-library packaging gap, navigation dead ends, a repeated-learning streak crash, navigation reset during settings changes, and a stranded session list after current-device revocation. The root Android verification and CI now reject APKs missing required native libraries.

- Added the [architecture graph](PROJECT_GRAPH.md), [local setup guide](LOCAL_DEVELOPMENT.md), interactive administrator/MFA provisioning, and repeatable verification command.
- Implemented mobile session listing/revocation and English/Urdu password-reset screens, backed by real API routes and SMTP delivery.
- Preserved signed-in local access during transient refresh failures, prevented an in-flight refresh from resurrecting a logged-out session, and made logout clear credentials when offline.
- Separated guest/account databases and sync transports, recovered interrupted outbox operations, drained batches larger than 50 entries, and rebuilt reminders on account changes.
- Connected reviewed reference publication to canonical API content and validated mobile offline updates. User bookmarks/progress survive updates, failed downloads preserve the previous cache, and startup cannot replace a newer release with the bundled seed.
- Added revision/source inspection, revised-draft editing, independent approval, return-to-draft review, and production approval guards for reference releases.
- Repaired admin CSP hydration with request nonces, retained native Origin validation for server actions, corrected role-based landing pages, and added pending/error/success states for administrative operations.
- Implemented accessible mobile navigation, active-page indication, skip navigation, readable dates/JSON/booleans, and contained responsive tables. The phone-sized import screen was inspected from the real browser screenshot.
- Redesigned the admin dashboard and login, added permission-scoped aggregate metrics and activity charts, searchable/filterable/paginated tables, report inbox links, and explicit repeatable local demo seeding. Added browser checks for these flows and corrected dashboard overflow at phone widths.
- Hardened CSV/JSON imports with UTF-8/size/row/header validation, complete change fingerprints, accurate change counts, existing-record updates, concentration preservation, and actionable errors.
- Fixed provider-cache JSON persistence and timestamp consistency. Medication mapping now requires one complete ingredient/strength/form equivalent; first search position never verifies a mapping.
- Made SQLite/PostgreSQL migrations agree with ORM metadata, retained shared PostgreSQL extensions on downgrade, locked container dependencies, and expanded CI with browser and PostgreSQL migration checks.

## Browser coverage

1. Password-only local login, optional authenticator input, wrong-password feedback, hydration under CSP, HttpOnly/SameSite cookie, logout, and protected redirect.
2. Editor/support landing pages and role-filtered navigation.
3. CSV validation, confirmed import application, and recoverable repeat-apply rejection.
4. All permitted administrator navigation pages against real API responses.
5. Reference draft inspection, independent reviewer approval, publication, and public dataset delivery.
6. Phone-sized menu interaction and absence of page-width overflow.
7. Full persisted dashboard totals, activity periods, recent-content filters, refresh, and phone width.
8. Workspace page search, management-table search/status filters, and pagination.
9. Report inbox selection, confirmed audited resolution, and refreshed dashboard counts.

Browser fixtures create only synthetic accounts inside a disposable database. They never use the configured local or production database.

## Remaining production requirements and measured limitations

- The bundled reference corpus is development-only. Production needs content/source licensing review and an independently approved reference release. Individual editorial records distribute through complete reference releases.
- Interaction checking intentionally reports unavailable until a licensed, validated provider is integrated. Local AI is configured and tested; production AI still requires independent medical/translation review, deployment configuration, and an audited feature-flag decision. Provider outages preserve safe unavailable/cache states. Live retrieval was tested for the recorded medicine example and does not certify every medicine or continued provider availability.
- `npm audit` reports five high-severity **development** findings in the Next ESLint → fast-glob → micromatch → braces chain. The root advisory is [GHSA-vfj7-8cjw-p6xm](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm). Registry versions checked were braces 3.0.3, micromatch 4.0.8, and fast-glob 3.3.3; no compatible fix was available. The proposed automatic fix downgrades the lint configuration to Next 14 and was not applied. Runtime dependencies have zero reported findings. Reassess before release.
- Android builds pass with a Flutter warning that several plugins still apply the Kotlin Gradle Plugin and will require upstream support for built-in Kotlin in a future Flutter version. The first build also reported Android SDK XML tooling-version mismatch. These are recorded build warnings, not test failures.
- API tests emit one Starlette/httpx TestClient deprecation warning. Admin unit tests emit a Vitest configuration-loader migration warning. Both suites pass.
- Camera/OCR/barcode, notification delivery/reboot/timezone behavior, speech, biometrics, real-device accessibility, release signing, and iOS were not verified on physical devices in this pass. Full Xcode/signing are not configured here.
- Production still needs TLS, external secrets, named MFA administrators, real SMTP/sender configuration, shared rate limiting, deployment origins, backups/restore drills, retention scheduling, monitoring, and operational ownership. See the [production checklist](PRODUCTION_CHECKLIST.md).
- Legacy unscoped mobile databases are preserved without automatic assignment to an account. See the local guide before migrating existing installations.

Automated checks establish the behavior they exercise; they do not establish that every possible device, network, dataset, and deployment is defect-free.
