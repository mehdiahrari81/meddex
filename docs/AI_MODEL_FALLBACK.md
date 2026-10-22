# MediExplain AI recovery — implementation and verification

Verified on 22 October 2026. The updated backend is deployed in the existing `meddex` Docker stack. No mobile reinstall is required for these backend changes.

## Active routing

| Workflow | Priority |
| --- | --- |
| Assistant, medicine explanations, whole-list explanations | Gemini `gemini-3.5-flash-lite` → Gemini `gemini-3.1-flash-lite` → Groq `openai/gpt-oss-120b` → local Ollama `qwen3:1.7b` |
| Prescription image reading and handwriting review | Gemini `gemini-3.5-flash-lite` → Gemini `gemini-3.1-flash-lite` → Groq vision `qwen/qwen3.8-27b` |
| Separating already-recognized prescription text into medicine fields | The separately configured prescription Gemini chain → Groq text; no local image inference |

The requested `gemini-2.5-flash-lite` emergency slot is **disabled**. Although Google's model metadata endpoint returned 200, actual generation returned **404** for both text and image requests with this project's credentials. Metadata listing alone therefore does not establish usability. The text, prescription and handwriting emergency settings are intentionally empty. No substitute model was silently introduced.

Gemini 3.1 initially returned temporary 503 responses. Later live checks returned valid structured text and image results. It remains eligible, and runtime cooldown automatically skips it during failures.

Images are restricted to explicit verified capability registries in the provider code. They never go to Groq's text model or local Qwen. The cloud vision model runs on Groq's servers, not on the Mac. The installed `qwen3:8b` model was not selected or invoked; the configured local model is `qwen3:1.7b`.

## Recovery behavior

- A successful primary request makes no fallback requests. Different workflow settings remain independent, while provider/model availability is shared to avoid repeatedly hitting a failed endpoint.
- Each distinct eligible model is attempted at most once per operation. Duplicate model IDs are removed. Expired request budgets stop further attempts; no infinite retry or mandatory sleep is introduced.
- Timeouts, connection failures, HTTP 408 and all HTTP 5xx responses can advance to the next eligible model. Model-not-found 404 errors cool down that model and advance.
- HTTP 402/429 quota responses are scoped conservatively. Another Gemini model is eligible **only** when every Google `QuotaFailure` violation explicitly names the current model and identifies a `PerModel` quota. Unknown, mixed, billing or project-wide limits pause Gemini across workflows and proceed to the independently limited Groq provider.
- Numeric and HTTP-date `Retry-After` values and Google `RetryInfo` delays are reused. An unscoped server `Retry-After` pauses the provider rather than probing another Gemini model. No rotating keys, projects, or accounts is used.
- Failed models stay out of the chain during cooldown. When every model is cooling down, the backend does not force a probe. Groq quota failures also block its text and vision requests conservatively.
- Cloud attempts share the existing operation timeout, reserving time for Groq. Ollama has an explicit 30-second request timeout and an availability cooldown. These are HTTP operation timeouts, not a guarantee of total application latency: uploading, reference lookup, and separate scan/review operations also take time.
- Invalid input, invalid credentials/permissions, safety-blocked or malformed results are not disguised as successful output. Existing source, identity, dosage and batch-result validations remain in place.
- Successful explanations no longer include transient provider-switch notices in their user-facing limitations. Provider/model metadata remains in the API response for compatibility and provenance. Server diagnostics contain model IDs, status codes, timing, attempt number and cooldown scope, never prompts, images or credentials.
- If compatible providers are exhausted, image/structuring requests fail safely and preserve the saved review workflow. Explanation services retain their existing validated-reference fallback where available; they do not invent medicine facts.

## Configuration

Backend configuration: [services/api/.env](/Users/mahdiahrari/Developer/meddex/services/api/.env).
Template: [services/api/.env.example](/Users/mahdiahrari/Developer/meddex/services/api/.env.example).

Each workflow has a primary, fallback and emergency field:

```text
MEDIEXPLAIN_GEMINI_MODEL=gemini-3.5-flash-lite
MEDIEXPLAIN_GEMINI_FALLBACK_MODEL=gemini-3.1-flash-lite
MEDIEXPLAIN_GEMINI_EMERGENCY_MODEL=

MEDIEXPLAIN_GEMINI_PRESCRIPTION_MODEL=gemini-3.5-flash-lite
MEDIEXPLAIN_GEMINI_PRESCRIPTION_FALLBACK_MODEL=gemini-3.1-flash-lite
MEDIEXPLAIN_GEMINI_PRESCRIPTION_EMERGENCY_MODEL=

MEDIEXPLAIN_GEMINI_HANDWRITING_MODEL=gemini-3.5-flash-lite
MEDIEXPLAIN_GEMINI_HANDWRITING_FALLBACK_MODEL=gemini-3.1-flash-lite
MEDIEXPLAIN_GEMINI_HANDWRITING_EMERGENCY_MODEL=
```

The duplicate `MEDIEXPLAIN_GEMINI_SCAN_RECOVERY_MODEL` setting was removed. Existing timeout/cooldown settings are reused. Groq, Ollama, database, SMTP, authentication, and LAN identity values were preserved. Credentials remain in the ignored backend `.env`, with mode 600, and are not included in this report or Docker images.

Pydantic reads this configuration locally. The existing `docker-compose.ai.yml` loads the same environment file and supplies Docker's host address for Ollama. Existing Compose database/authentication overrides were preserved. No dependency changes or migrations are needed.

## Files changed for this task

| Files | Purpose |
| --- | --- |
| `services/api/app/core/config.py` | Separate text, prescription and handwriting priority settings; empty emergency slots |
| `services/api/app/providers/ai.py` | Bounded Gemini routing, model/project quota classification, shared cooldowns, image eligibility and bounded Ollama requests |
| `services/api/app/providers/cloud_fallback.py` | Select the configured workflow chain, preserve Gemini → Groq routing, enforce modality and provider cooldowns |
| `services/api/app/services/gemini_handwriting.py` | Use handwriting emergency settings and cooldown-aware cloud review |
| `services/api/app/services/prescription_structuring.py` | Select the separate prescription chain |
| `services/api/app/services/medicine_batch_overview.py` | Preserve local batch recovery for all temporary server errors and model removal, including when Groq is unconfigured |
| `services/api/app/services/medical_rag.py` | Remove transient failover notices from successful patient explanations; keep provenance fields |
| `services/api/.env` (ignored), `services/api/.env.example` | Apply verified priorities and remove obsolete/duplicate routing values |
| `services/api/scripts/verify_ai_models.py` | Repeatable live synthetic text/image probes, safe status-only reporting; does not edit configuration |
| `services/api/tests/test_ai_model_routing.py` | New failure, quota-scope, modality, timing, emergency, deduplication and cooldown regressions |
| `services/api/tests/test_cloud_fallback.py`, `test_gemini_scan_availability.py`, `test_gemini_fallback.py` | Update recovery/cooldown behavior and invisible-transition expectations |
| `services/api/tests/test_handwriting_detail.py`, `test_prescription_structuring.py`, `test_scan_latency.py` | Verify the new fallback ID while preserving uncertainty, evidence and bounded latency |
| `services/api/tests/test_medicine_batch_overview.py` | Whole-list local recovery when Gemini models are removed or return nonstandard 5xx and Groq is unconfigured |
| `services/api/tests/conftest.py` | Remove obsolete jitter fixture; retain isolated provider state |
| `docs/AI_MODEL_FALLBACK.md` | This implementation and verification report |

## Verification results

1. **Entire API test suite: 264 passed.** Covers authentication, sessions, prescriptions, medication workflows, reference data, learning, admin, provider routing and AI validation. One existing Starlette/httpx deprecation warning remains; it does not fail the tests.
2. **Ruff:** changed Python sources/tests/operator script passed. **mypy:** all seven changed application modules passed.
3. **Live model checks:** Gemini 3.5 and 3.1 each returned HTTP 200 with valid structured text and synthetic image answers. Groq's configured text model and vision model each returned valid live results. Groq vision also timed out on one separate probe; subsequent forced-failover checks succeeded, demonstrating that individual cloud requests can still be temporarily unavailable.
4. **Real recovery endpoints with injected failures:** synthetic primary 503 → real Gemini 3.1 succeeded for text and image. Synthetic failures for both Google models → real Groq succeeded for text and image. The normal provider routing code performed all transitions.
5. **Local fallback:** a real structured request to `qwen3:1.7b` succeeded. Docker can reach the host Ollama server and confirms the configured model is installed. Automated tests also verify the full cloud-failure → local explanation sequence.
6. **Deployed HTTP workflow:** disposable test account → synthetic prescription image → two correctly separated medicines (Lipitor and Metformin) → confirmed-list request → both sourced explanations returned together. All endpoints returned 200; test account was deleted. Image reading took 2.28 s, structuring 1.47 s, and explanations 1.99 s in this check. These timings are observations, not latency guarantees.
7. **Simulations:** primary success, 408, every tested 5xx including 501/599, network/read timeouts, model 404, model-specific 429, global/mixed/project 429, billing limits, Retry-After seconds/date, Google RetryInfo, cooldown expiry, all models unavailable, unsupported vision model, duplicated IDs, and bounded total cloud attempts.
8. Backend image was rebuilt using the existing installed dependencies, the existing API container was recreated, and database volumes were preserved. No frontend changes were required.

Run the checks again from the repository root:

```sh
cd /Users/mahdiahrari/Developer/meddex/services/api
.venv/bin/pytest -q
.venv/bin/python scripts/verify_ai_models.py
```

The live verifier sends small synthetic requests and consumes normal API quota. It does not print credentials or patient content, automatically enable unavailable models, or continue Google probes after an unknown quota response.

## Remaining limits / presentation operation

- Keep the existing Mac backend and Ollama running. Cloud providers require internet access; the phone still needs a valid connection to the Mac server.
- Handwriting can remain illegible. Review and confirmation remain necessary; model failover cannot guarantee accurate recognition of every prescription.
- If all image providers are unavailable, the text-only local model cannot read images. The app must show the safe retry/manual-review state.
- The existing local batch size/context guard remains: very large confirmed lists cannot fall back to the small local model. Existing grounded source information may still be available.
- Cooldowns are process-local, appropriate to the current single API worker. A future multi-worker/multi-host deployment should coordinate provider cooldowns through shared storage.
- No manual action is required for the enabled chain. Leave Gemini 2.5 disabled unless generation succeeds for the intended project and the verified image-capability registry is updated if needed.

## Provider documentation checked

Google documents image input for [Gemini 3.5 Flash-Lite](https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite) and [Gemini 3.1 Flash-Lite](https://ai.google.dev/gemini-api/docs/models/gemini-3.1-flash-lite). Groq documents image input for [Qwen 3.8 27B](https://console.groq.com/docs/model/qwen/qwen3.8-27b). Google's [rate-limit documentation](https://ai.google.dev/gemini-api/docs/rate-limits) explains project-level enforcement and model-dependent quotas. Live generation results, rather than catalog listings alone, determined which requested models were enabled here.
