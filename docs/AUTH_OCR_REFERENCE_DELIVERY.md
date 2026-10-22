# Authentication, prescription OCR, and reference data delivery

Verified locally on 18 October 2026. This checkout contains Flutter/Riverpod/Drift mobile and FastAPI/SQLAlchemy/Alembic/PostgreSQL API sources. The Next.js admin source described in historical documentation is absent. Existing app styling, routes, printed OCR, reminders, learning, and account-specific databases are retained.

The subsequent [Gemini/Ollama and iOS delivery](GEMINI_OLLAMA_IOS.md) documents the assistant provider routing, native Apple Vision/VisionKit support, and final expanded verification results.

## Changes

- Registration and login use the existing Argon2id password hashes, normalized email, strict validation, JWT access tokens, hashed rotating refresh tokens, and database session revocation. Whitespace-only names now fail validation. Mobile refresh and protected resources reject admin sessions. PostgreSQL locks refresh rows during rotation.
- Authentication rate limits cannot be bypassed by changing an Authorization header. Authentication and OCR responses have `Cache-Control: no-store`. Flutter shows useful localized duplicate-account, invalid-credential, connection, and throttling errors in the existing error component.
- Secure-vault mutations are serialized. Logout cannot be undone by a pending credential write. Guest mode clears the existing session. Existing account-specific local databases and server ownership checks remain in place.
- Printed recognition stays on-device with Apple Vision on iOS and ML Kit on Android. A **Recognize handwriting** action is available in OCR text review and after recognition failure. It requires sign-in and explicit approval to send images to the configured API. Images are processed in memory and are not saved by the OCR endpoint. Existing image-retention settings still govern the mobile originals.
- Handwriting runs sequentially per page, with a single CPU inference slot per API process, two Torch threads, maximum 6 MB encoded / 16 million decoded pixels / 24 detected lines per request, 2,200-pixel preprocessing, adaptive ink segmentation, and bounded greedy decoding. No model or external AI service receives patient images beyond the configured API.
- OCR output always requires review; confidence is explicitly unknown. No name, dose, or medication identity is automatically confirmed. The existing editable text and per-field confirmation workflow applies. Model ID and revision are retained when recognized text is saved. Previously confirmed items cannot be overwritten by reparsing.

## Model decision and measured evidence

| Option | Assessment |
| --- | --- |
| SimpleHTR | Small CNN/LSTM/CTC implementation; word/line input. Its project reports around 10% character error on its IAM evaluation. Older TensorFlow session/checkpoint tooling adds a separate runtime. |
| TrOCR-small-handwritten | **Selected**: 62 million parameters; Microsoft reports 4.22% cased IAM character error. Pinned public weights and existing Python API integration; dynamic INT8 linear layers on supported CPU engines. |
| TrOCR-base / large | Microsoft reports lower IAM error but 334M / 558M parameters; too large for this project's lightweight target. |
| Native platform OCR | Apple Vision on iOS and ML Kit on Android provide fast offline recognition and document geometry. They do not replace the server handwriting-specific line model. |

The published metrics use their authors' evaluation setups and are not a controlled comparison or a prescription accuracy estimate. TrOCR is trained on English IAM handwriting, not medical prescriptions or Urdu. Overlapping writing, slant, stamps, mixed layouts, ambiguous abbreviations, and unfamiliar drug names can fail or produce plausible incorrect text. Users must compare against the image or obtain pharmacist/prescriber clarification.

Pinned model: `microsoft/trocr-small-handwritten`, revision `b4648cfa171985a6745f37ddd637e98c0da958ac`. Original weights download is about 235 MiB; the measured serialized INT8 state is 108.25 MiB (QNNPACK), reducing the model representation but does not eliminate the PyTorch runtime. The phone receives no transformer weights. CPU wheel selection avoids CUDA dependencies on Linux x86-64. Engines are selected from x86/fbgemm/qnnpack; platforms without those engines use FP32.

Actual tests on this Apple Silicon host:

- Hugging Face's public IAM fixture: correctly read **industry**. Authenticated HTTP cold inference 5.417 s; warm inference 0.239 s.
- Docker CPU deployment, same IAM fixture: authenticated cold 15.839 s; warm 0.435 s. PostgreSQL/API/Mailpit reported healthy. Model cache was writable by the non-root service user.
- SimpleHTR's public handwritten line fixture: correctly read **or work on line level**. Cold 5.184 s; warm 0.412 s.
- These are engineering smoke tests, not a representative handwriting benchmark. No real patient prescription image was supplied, so prescription accuracy and clinical fitness remain unvalidated.

Sources: [Microsoft TrOCR model and benchmarks](https://github.com/microsoft/unilm/tree/master/trocr), [model card](https://huggingface.co/microsoft/trocr-small-handwritten), [SimpleHTR](https://github.com/githubharald/SimpleHTR), [Google ML Kit](https://developers.google.com/ml-kit/vision/text-recognition/v2), [public IAM fixture](https://huggingface.co/datasets/hf-internal-testing/fixtures_ocr).

## Verified reference data

`data/rxnorm_reference.json` contains **78 genuine RxNorm records: 20 ingredients and 58 clinical drug concepts**, fetched directly from NLM's public API on 18 October 2026, release **05-Oct-2026**. Each record was rechecked against its individual `/rxcui/{id}/properties.json` response, including active/non-suppressed status, exact canonical name, concept type, and identifier. Each has its own source URL. Topics include acetaminophen, ibuprofen, amoxicillin, metformin, omeprazole, cetirizine, loratadine, atorvastatin, amlodipine, losartan, levothyroxine, azithromycin, doxycycline, ferrous sulfate, folic acid, albuterol, aspirin, naproxen, pantoprazole, and hydrochlorothiazide.

The importer adds missing identities, identifiers, and provider mappings; links an existing identity where possible; and preserves existing mappings and patient data. Installed identities remain searchable during an upstream outage. These are US vocabulary concepts, not evidence of Pakistan registration, local availability, an appropriate treatment, or an individual dosing instruction. No safety facts, interactions, indications, patient records, prescriptions, or transactions were invented.

The existing local PostgreSQL database initially had 34 terminology records and no users, medications, or prescriptions. Import added 78 medicine identities. A repeat import added zero. The 34 existing terms remain. Temporary authentication/OCR QA accounts were removed after verification. Reference records are not labeled demo/sample/test data. Existing development-only terminology release status was preserved rather than falsely upgraded to clinically approved.

Sources: [NLM RxNorm API and terms](https://lhncbc-portal.lhcaws-prod-pub.nlm.nih.gov/RxNav/APIs/RxNormAPIs.html), [concept property API](https://lhncbc-portal.lhcaws-prod-pub.nlm.nih.gov/RxNav/APIs/api-RxNorm.getRxConceptProperties.html). Per-record source URLs and retrieval/version metadata are in the snapshot and provider mapping evidence.

## Verification results

- 108 API tests passed, covering authentication, token replay/revocation, account ownership, profile/consent, prescriptions, medication plans, reference data, source-backed intelligence, and governance.
- 136 Flutter tests passed, including secure session persistence, a pending-write/logout race, binary OCR upload, confirmation gates, parsing, local databases, schedules, routing, accessibility, and localization.
- Ruff formatting/lint, strict mypy, Flutter analysis, PostgreSQL Alembic upgrade/check, duplicate checks, and authenticated PostgreSQL/HTTP smoke tests passed.
- Android debug APK compiled. Physical-device camera, native ML Kit quality, and visual UI behavior require device testing; a compilation and widget tests do not establish those results.
- Admin checks are explicitly skipped because the admin source is absent, not reported as passed.

## Run and reproduce

Docker (downloads pinned handwriting weights once into a persistent volume):

```sh
python3 scripts/dev.py --project meddex start --ocr
# Equivalent:
docker compose -f docker-compose.yml -f docker-compose.ocr.yml up --build -d
```

The verified local stack uses Compose project `meddex`; reuse `--project meddex` for status, stop, and Android connection commands to preserve this database. The helper's historical default project name is `mediexplain`, which is a separate stack.

The default stack keeps handwriting dependencies optional. The overlay enables the actual model independently of Ollama/conversational AI. Normal startup imports the attributed medicine snapshot idempotently. The omitted admin app is isolated behind an admin profile; the helper enables it automatically if its source is restored.

Local API:

```sh
cd services/api
uv sync --group dev --extra ocr --locked
# Configure .env from .env.example with your actual DB and secret.
uv run alembic upgrade head
uv run python -m app.cli import-medications --path ../../data/rxnorm_reference.json
uv run python -m app.prepare_handwriting_model
uv run uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Mobile emulator: use `http://10.0.2.2:8000/api/v1/`. USB-connected Android: `adb reverse tcp:8000 tcp:8000`, then use a build targeting `http://127.0.0.1:8000/api/v1/`. A phone's loopback address refers to the phone. Production builds require an HTTPS API URL, external secrets, PostgreSQL, and the existing production security settings.

Verification commands:

```sh
./scripts/verify-local.sh
# Optional Android rebuild:
./scripts/verify-local.sh --android
# Public-fixture model smoke (OCR extra and prepared model required):
cd services/api
uv run python scripts/smoke_handwriting.py
# Against the local API and configured local PostgreSQL; QA accounts are deleted:
uv run python scripts/smoke_auth_postgres.py
uv run python scripts/smoke_ocr_http.py
# Refresh the public snapshot explicitly, then import it:
uv run python scripts/fetch_medication_reference.py --output ../../data/rxnorm_reference.json
```

Core API tests run without downloading model weights. OCR segmentation tests skip when the optional image runtime is absent. The live OCR smoke is separate so routine tests neither download models nor send data to external services. Deploy one API worker per model instance and apply a shared gateway rate limit if scaling beyond the existing single-process limiter. Do not disable the existing human-confirmation gates based on published IAM scores.
