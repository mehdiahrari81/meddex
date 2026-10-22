# Cloud fallback and reviewed medicine explanations

**Flow update:** [Confirm the entire list, then Explain medicines](PRESCRIPTION_BATCH_EXPLANATIONS_2026-10-21.md) supersedes the individual-confirmation trigger described below.

Delivered 21 October 2026. Keys stay in `/Users/mahdiahrari/Developer/meddex/services/api/.env` under `MEDIEXPLAIN_GEMINI_API_KEY` and `MEDIEXPLAIN_GROQ_API_KEY`. Both were authenticated successfully without printing their values. The file is ignored by Git and has permissions 0600. Flutter contains neither key.

## Provider order

| Task | Primary | Cloud fallback | Last fallback |
| --- | --- | --- | --- |
| Prescription image transcription | Configured Gemini vision model | Groq `qwen/qwen3.8-27b` | Saved scan / manual correction |
| Medicine field separation | Configured Gemini text model | Groq `openai/gpt-oss-120b` | Saved text / manual correction |
| Sourced medicine explanations and assistant | Configured Gemini text model | Groq `openai/gpt-oss-120b` | Ollama `qwen3:1.7b` on the Mac |

Groq models run on Groq's servers. No large model was downloaded to the Mac. Images never go to the local text-only Ollama model. Existing endpoint names containing `gemini` remain compatible with installed clients; responses identify the actual provider/model.

Quota, timeout, and temporary availability failures trigger bounded fallback. Credential/permission errors, safety refusals, malformed JSON and failed source validation do not bypass validation by asking another model. Shared cooldowns honor Retry-After, then allow Gemini to recover. Both cloud quotas exhausted means image processing must wait or be corrected manually; another API key does not guarantee unlimited service.

## Review and explanation

The scan displays medicine name, strength, form, dose quantity and frequency from evidence in the recognized text. Missing details remain missing; neither provider may invent a dose or silently correct a drug name. Every extracted item remains unconfirmed.

Use **Check** to correct fields. **Confirm** records review, shows a tick and starts the simple explanation under that medicine. No explanation request starts in the scan review screen before confirmation. Editing hides the previous explanation and requires another confirmation. Existing saved medications remain eligible for their general explanations.

Names are resolved with trusted reference identities and brand-to-ingredient relationships. Explanations retain their actual RxNorm/MedlinePlus/DailyMed references and grounding checks. Failed or ambiguous identity resolution remains correctable rather than displaying an invented explanation. Retry remains available for temporary explanation failures.

## Request limits

The Groq vision fallback retains the entire prescription page and up to two contextual detail images, within the model's three-image limit. Current default vision output is 768 tokens because this account's live vision output allowance was 1,000 tokens/minute; the original larger request exceeded it. Large prescriptions may exceed that allowance or output budget and must be split or retried. Incomplete responses are rejected, not presented as complete scans. The optional uncertain-line recheck fails softly if its quota is exhausted, preserving the successful initial transcription. Completed rechecks report the actual provider/model rather than attributing Groq results to Gemini.

## Verification

- Backend: 212 tests passed; Ruff and mypy checked all 74 API source files.
- Mobile: 254 tests passed, with three opt-in live tests skipped in the normal suite. Flutter analysis was clean. Eleven targeted error/privacy tests passed after the final English/Urdu wording changes.
- Credential checks: both real keys accepted; selected Groq vision model present in the account's model list.
- Real backend primary scan: synthetic printed image containing Lipitor, Metformin and Betaloc produced all three names and the expected strength, dose and frequency fields. Image-to-fields: 6.49 seconds; with three sourced explanations: 10.69 seconds. The temporary QA account was removed.
- Live Groq patient-summary checks succeeded for Lipitor, Metformin and Betaloc with source references, about 1.1–1.4 seconds each after reference caching. Forcing both cloud quotas used the actual local `qwen3:1.7b` and passed grounding, taking 31.26 seconds. Temporary QA accounts were removed.
- Forced quota transport tests exercise Gemini-to-Groq, both-cloud-to-Ollama, cooldown/recovery, full-page retention, uncertainty, literal evidence validation, refusal/truncation rejection and source grounding.
- Flutter tests exercise no explanation request before Confirm, approval-triggered loading, editing and re-confirmation, and Groq provider provenance.

These are engineering checks, not clinical validation. In a real Groq fallback image test, the model read printed “Betaloc” as “Betalloc” without reporting uncertainty. That result was not silently corrected or counted as an exact-name pass. Image transcription still requires review against the original prescription. Neither service can guarantee correct recognition of every handwritten medicine.

## iPhone delivery

Built and signed the release app, installed it on the connected iPhone 12 and launched it successfully without a debugger. Backend readiness passed through the Mac’s Bonjour LAN address. Existing app data was preserved. Build/install log: `/tmp/meddex-groq-iphone-install.log`.

## Operations

After changing keys, recreate the API container so its environment is refreshed:

```sh
docker compose -p meddex -f docker-compose.yml -f docker-compose.ai.yml -f docker-compose.ocr.yml up -d --build api
```

Model, timeout and output-limit overrides are documented in `services/api/.env.example`. Keep the Mac/backend available for the current local development deployment.

Official provider references: [Groq vision](https://console.groq.com/docs/vision), [structured outputs](https://console.groq.com/docs/structured-outputs), [rate limits](https://console.groq.com/docs/rate-limits), [Qwen vision model](https://console.groq.com/docs/model/qwen/qwen3.8-27b).
