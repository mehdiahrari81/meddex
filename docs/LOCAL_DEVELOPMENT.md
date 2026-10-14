# Local development

## Requirements

- Docker Desktop or Docker Engine with Compose v2.
- Flutter stable with Dart 3.12 or newer; Android SDK and JDK 17 for Android builds.
- A complete Android NDK installation is required, including its compiler and JNI build support. A successful Gradle build alone does not verify native-library packaging; `--android` also inspects the APK for required JNI and SQLite libraries.
- Python 3.12 or newer with `uv`, and Node.js 22 with npm for checks outside Docker.
- Chrome or Playwright Chromium for browser verification. iOS requires full Xcode 26.1.1+ (26.2 in CI), CocoaPods, and device signing where applicable.

Run from the project root:

```sh
docker compose up -d --build
docker compose ps
```

| Service | Default URL |
| --- | --- |
| API documentation | http://localhost:8000/docs |
| API readiness | http://localhost:8000/api/v1/ready |
| Admin | http://localhost:3000 |
| Development inbox (Mailpit) | http://localhost:8025 |
| PostgreSQL | localhost:5432 |

Compose migrates PostgreSQL and installs the development reference dataset **only when no reference release exists**. Restarts preserve subsequently published datasets and the named database volume. The development credentials and HTTP settings in Compose are for local use. Mailpit captures messages locally; it does not deliver to real inboxes.

No default administrator is created. Provision your named account interactively, replacing the example email and name:

```sh
docker compose exec api python -m app.cli provision-admin \
  --email you@example.com --name "Your Name" --role SUPER_ADMIN --mfa
```

The CLI prompts for a password and confirmation, then displays a one-time authenticator enrollment secret and verifies a current code before saving. Passwords are never command arguments. Existing user credentials must match; existing administrative memberships are never overwritten. Supported roles are `SUPER_ADMIN`, `PLATFORM_ADMIN`, `CONTENT_EDITOR`, `CONTENT_REVIEWER`, and `SUPPORT_READ_ONLY`. Editors and reviewers should be separate named people for independent approval.

For populated FYP demonstrations, the [admin dashboard guide](ADMIN_DASHBOARD.md) documents the explicit `seed-demo` command. It adds labeled editorial records, synthetic reports, and failed-import examples only in development/testing. Repeated runs preserve existing edits, and startup never creates these examples automatically.

For the locally running AI assistant, use the [AI and voice setup guide](AI_FEATURES.md). It documents the optional Ollama Compose override, audited feature flag, exact medicine lookup, source-backed responses, and repeatable live input/output checks. Keep both Compose files when restarting the AI-enabled workspace instance.

To avoid occupied ports, set `MEDIEXPLAIN_DB_PORT`, `MEDIEXPLAIN_API_PORT`, `MEDIEXPLAIN_ADMIN_PORT`, `MEDIEXPLAIN_MAIL_PORT`, and `MEDIEXPLAIN_SMTP_PORT` when running Compose. A separate project name (`docker compose -p mediexplain-local …`) gets its own containers and volume. Use the same project name in subsequent `exec`, `logs`, and `down` commands. `down` preserves data; removing the volume deletes it.

## Mobile

```sh
cd apps/mobile
flutter pub get
flutter run --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1/
```

Android Emulator uses `10.0.2.2` to reach the host. For a physical phone use the computer's reachable LAN address and API port; the API port is exposed for this local workflow. Use `localhost` for an iOS Simulator. Preserve the trailing `/api/v1/` slash. Production requires HTTPS.

Guest and signed-in accounts have separate local databases. Signing in does not silently upload or reassign guest prescriptions, bookmarks, or medication plans. Returning to an account restores its local data. Remote synchronization is opt-in. Existing legacy `mediexplain.sqlite` files are preserved but not automatically assigned to any account because their owner cannot be established safely; migrate them only through an explicit, verified ownership process. New files use a SHA-256 account identifier in their filename.

Password reset: request a reset in the app, open Mailpit, copy the single-use code, choose **Enter reset code** in the app, and set a new password. A successful reset revokes existing sessions. Without a configured SMTP service the API gives the same private, non-enumerating response but does not claim delivery.

## Reference releases and DRAP imports

Use **Reference releases → Create draft** for a complete dataset. Start with `apps/mobile/assets/terminology/starter_dataset_v1.json`, change `dataset_version`, supply source attribution and a change reason, then submit for review. An independent reviewer inspects the revision and sources, approves, and publishes it. Publication installs canonical API content and makes the complete dataset downloadable at `/api/v1/content/dataset`. Mobile checks for releases on startup, connectivity recovery, and account changes; validation/import failure preserves the previous offline cache and user progress.

Individual terminology, lesson, quiz, and translation drafts retain their editorial history. Include their reviewed changes in a complete reference release to distribute them to mobile. The bundled corpus is marked development-only. Production publication and downloads require `production_approved: true` after actual content/source review; changing this field does not itself constitute that review.

Use **Imports** for DRAP products. Upload UTF-8 CSV (up to 5 MB and 10,000 rows) with registration ID, brand name, and composition/ingredient columns. Header aliases include `Registration Number`, `Brand Name`, `Composition`, and `Dosage Form`. Review added/updated/unchanged/rejected counts and row warnings, then enter the validated job ID twice to apply. Invalid rows block application. An already applied job cannot be applied again.

## Host development and checks

```sh
cd services/api
uv sync --group dev --locked
cp .env.example .env
uv run alembic upgrade head
uv run uvicorn app.main:app --reload
```

The example environment connects to default Compose PostgreSQL/Mailpit ports. For source-only development, start those two services with `docker compose up -d postgres mailpit`. Configure the environment before running migrations. Provision an administrator with `uv run python -m app.cli provision-admin …`.

```sh
cd apps/admin
npm ci
cp .env.example .env.local
npm run dev
```

The admin API URL is server-side. Local HTTP requires `ADMIN_COOKIE_SECURE=false`; production must use secure cookies. For a built local admin, run `npm run build && npm start`. The start command copies static assets into the standalone output before starting it. Set `PORT` and `HOSTNAME` as environment variables to change its address.

After installing dependencies, from the project root:

```sh
./scripts/verify-local.sh
PLAYWRIGHT_CHANNEL=chrome ./scripts/verify-local.sh --browser --android
```

To use bundled Playwright Chromium instead of Chrome, run `npx playwright install chromium` in `apps/admin` and omit `PLAYWRIGHT_CHANNEL`. Browser tests start isolated temporary API/admin servers at ports 18080/13000, run real login/import/review/publication flows, and remove their test database. Their synthetic account credentials are confined to that fixture. No configured database is used.

For a running local Compose stack, verify real SMTP delivery and password-reset revocation:

```sh
cd services/api
.venv/bin/python -m tests.smoke_local_stack
```

Use `--api http://127.0.0.1:18000/api/v1 --mail http://127.0.0.1:18025` for the alternate verification ports. This check accepts localhost URLs only and removes its synthetic user and captured message.

Verify the running API's account, prescription, medication, learning, bookmark, and session flows against real PostgreSQL:

```sh
cd services/api
.venv/bin/python -m tests.smoke_live_api --url http://127.0.0.1:18000
```

This paced localhost-only check creates unique synthetic accounts and deletes them afterward. See the [runtime smoke report](SMOKE_TEST_REPORT.md) for coverage and device-test limits.

See [release evidence](RELEASE_VERIFICATION.md), [architecture graph](PROJECT_GRAPH.md), and [production requirements](PRODUCTION_CHECKLIST.md).
