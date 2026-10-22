# MediExplain

MediExplain is an offline-first Flutter medical-literacy application with a FastAPI/PostgreSQL service and an Next.js administration application. Its medical-information rule is fixed: trusted source → structured fact + provenance → optional grounded explanation → validation → user. OCR and language models are never medical sources.

For the implemented authentication fixes, CPU handwriting recognition, 78 NLM-verified medicine records, measured tests, and setup, see [delivery details](docs/AUTH_OCR_REFERENCE_DELIVERY.md). Default on-device OCR stays offline; cloud image reading requires separate approval and human review.

Gemini-first medical-assistant routing, automatic Ollama quota fallback, and iOS setup are documented in [Gemini, Ollama, and iOS](docs/GEMINI_OLLAMA_IOS.md). Put the server key in `services/api/.env`; the mobile application contains no API keys.

For medicine-only prescription reviews, optional Gemini handwriting image reading, explained abbreviations and cited Betaloc/ingredient references, see the [prescription workflow](docs/PRESCRIPTION_GEMINI_STRUCTURING.md).

## Applications

- `apps/mobile`: Flutter/Riverpod/Drift client; English/Urdu, local OCR, prescription confirmation, trusted medication resolution, offline source cache, reminders/history, and grounded assistant UI.
- `services/api`: FastAPI/SQLAlchemy/Alembic service; user sessions, owner-scoped resources, RxNorm/MedlinePlus/DailyMed adapters, approved DRAP dataset adapter, RAG safety, governance, metrics, and retention.
- `apps/admin`: Next.js 16 server-rendered admin; backend-controlled admin sessions, permission-based navigation/actions, content lifecycle, imports, reports, sources, health, and audit records.

For FYP preparation, use the [project and presentation guide](docs/FYP_PRESENTATION_GUIDE.md) or its [editable Word copy](docs/FYP_PRESENTATION_GUIDE.docx). It includes the core concept, functionality catalogue, scope, implementation workflows, six diagrams, testing evidence, an 18-slide outline, demo script, and viva answers.

## Run on another laptop

Install **Git, Docker with Compose v2, and Python 3.10+**. Start Docker, then run:

```sh
git clone https://github.com/asjadyousaf05/Medi-Term-Explainer.git
cd Medi-Term-Explainer
python3 scripts/dev.py start --ocr
python3 scripts/dev.py admin
```

On Windows, use `py -3` in place of `python3`. The helper waits for service readiness and prints the local URLs. Create your own administrator at the interactive prompt; passwords and existing account data are not shipped. Local admin MFA is optional (`admin --mfa`); production requires MFA. Populate the dashboard with labeled examples using `python3 scripts/dev.py demo --email YOUR_ADMIN_EMAIL`.

**Android download:** install a bundled [APK](downloads/android/README.md) without Flutter. Connect an authorized Android phone/emulator with Android Platform-Tools installed, then run:

```sh
python3 scripts/dev.py install-android
```

The helper chooses the device's APK, connects its API port to this laptop, installs, and opens the app. The connection uses USB/ADB port forwarding; repeat `connect-android` after reconnecting. The local-demo APK targets `http://127.0.0.1:8000/api/v1/` on the device. Guest features remain usable without the API connection.

**iOS download:** [Intel Simulator and unsigned iPhone archives](https://github.com/asjadyousaf05/Medi-Term-Explainer/releases/tag/v1.0.1-demo), with [build and installation instructions](downloads/ios/README.md). Both compiled successfully on Xcode 26.2. An iPhone installation requires your Apple signing identity; an unsigned archive cannot be installed directly.

See the [complete laptop setup and troubleshooting guide](docs/RUN_ON_ANOTHER_LAPTOP.md), [handoff verification](docs/GITHUB_HANDOFF.md), [downloadable releases](https://github.com/asjadyousaf05/Medi-Term-Explainer/releases), and [mobile build workflow](https://github.com/asjadyousaf05/Medi-Term-Explainer/actions/workflows/mobile-builds.yml). Local AI is optional and needs [Ollama setup and an enabled admin flag](docs/AI_FEATURES.md).

## Local start

```sh
docker compose up --build
```

This starts PostgreSQL, migrates/seeds the API at `http://localhost:8000`, installs the verified medicine reference snapshot, and captures password-reset messages in Mailpit at `http://localhost:8025`. Restarts preserve installed reference releases. It creates no default administrator. Provision your named account interactively:

```sh
docker compose exec api python -m app.cli provision-admin \
  --email you@example.com --name "Your Name" --role SUPER_ADMIN --mfa
```

See [local development](docs/LOCAL_DEVELOPMENT.md) for complete setup, alternate ports, account storage, reference publication, and password recovery.

The [admin-to-mobile data flow guide](docs/ADMIN_MOBILE_DATA_FLOW.md) covers the current portal, existing reference catalogue, publication workflow, and exhibition setup. The [older admin dashboard report](docs/ADMIN_DASHBOARD.md) records historical UI checks and demonstration seeding for a different installation.

For mobile:

```sh
cd apps/mobile
flutter pub get
flutter run --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1/
```

For service-only development, copy `.env.example`, use external secrets, then run `uv sync --group dev`, `uv run alembic upgrade head`, and `uv run uvicorn app.main:app --reload` from `services/api`.

## Verification

Install each application's dependencies, then run the repeatable checks from the project root:

```sh
./scripts/verify-local.sh
PLAYWRIGHT_CHANNEL=chrome ./scripts/verify-local.sh --browser --android
```

Individual checks:

```sh
cd apps/mobile
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test

cd ../../services/api
uv run ruff format --check app tests alembic
uv run ruff check app tests alembic
uv run mypy app
uv run pytest
uv run alembic check

cd ../../apps/admin
npm ci
npm run lint && npm run typecheck && npm test && npm run build
```

See the [project graph](docs/PROJECT_GRAPH.md), [verified results](docs/RELEASE_VERIFICATION.md), [runtime smoke report](docs/SMOKE_TEST_REPORT.md), [AI and voice guide](docs/AI_FEATURES.md), [Module 4 + 6 documentation](docs/MODULE_4_6_FINAL.md), [deployment](docs/DEPLOYMENT.md), and [production checklist](docs/PRODUCTION_CHECKLIST.md). The bundled terminology corpus remains explicitly development-only unless a reviewed release marks it production-approved.
