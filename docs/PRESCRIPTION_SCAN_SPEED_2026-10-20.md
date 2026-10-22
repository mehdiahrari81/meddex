# Prescription scan performance — 20 October 2026

Recent phone requests repeatedly waited about 24 seconds for the preferred Gemini 3.8 Flash reader to time out, then another 13–16 seconds for Gemini 3.5 Flash. Text separation could incur another failed-model attempt. The app also serialized all medicine explanations, including identity/source retrieval, so a prescription with several medicines accumulated more waiting.

## Changes

- Start image reading and text separation with **Gemini 3.5 Flash-Lite**, which was already the working cloud recovery model. Keep Gemini 3.5 Flash for transient failures. Duplicate configured recovery model names do not create duplicate requests. The assistant's Gemini/Ollama routing and `qwen3:1.7b` configuration are unchanged.
- Image recognition's cloud recovery budget is 30 seconds instead of 60; separation is 15 instead of 30. Clear pages need no detail pass. Uncertain lines retain a higher-detail Gemini 3.5 Flash re-read, bounded to eight seconds instead of twenty; a failed second pass keeps the original reading and its uncertainty.
- Preserve high-resolution images and overlapping detail views, source-text validation, missing-field handling, medicine/dosage uncertainty and explicit user review. No clinical handwriting accuracy claim is made by switching models.
- Load up to two medicine explanations concurrently, instead of a single serial queue. Coalesce identical in-flight queries, reuse only sourced/grounded successful previews for five minutes within the same account, and retain at most 32 previews in memory. Errors are not cached; queued or late results cannot cross an account change.
- A fully specified exact installed product or verified brand/ingredient relationship skips redundant online product search. A bare name still goes through the existing identity-resolution safeguards and does not select a sole product just because the local catalogue is incomplete. Public source retrieval and citation checks remain.

Server settings remain in the ignored `services/api/.env`; no key is embedded in Flutter:

```dotenv
MEDIEXPLAIN_GEMINI_HANDWRITING_MODEL=gemini-3.5-flash-lite
MEDIEXPLAIN_GEMINI_PRESCRIPTION_MODEL=gemini-3.5-flash-lite
MEDIEXPLAIN_GEMINI_HANDWRITING_FALLBACK_MODEL=gemini-3.5-flash
MEDIEXPLAIN_GEMINI_PRESCRIPTION_FALLBACK_MODEL=gemini-3.5-flash
```

## Measurements and validation

A live authenticated engineering test used a generated portrait prescription with three medicine rows and no patient, then requested three sourced explanations with two concurrent requests:

| Stage | Measured duration |
|---|---:|
| Image reading | 3.50 seconds |
| Medicine separation | 1.62 seconds |
| Image to medicine fields | **5.12 seconds** |
| Three sourced explanations | 6.12 seconds |
| Complete API pipeline | **11.24 seconds** |

All stages returned HTTP 200. All three medicine names, strengths, dose quantities and frequencies were present; each explanation had source citations. The disposable QA account was deleted. This measures the API pipeline on the current network and source-cache state, not the physical camera/import and phone preprocessing time. Handwriting difficulty, new medicine references, provider load and connectivity can increase duration.

- 194 backend tests passed; three installer tests passed.
- 233 mobile tests passed; three opt-in live suites were skipped in the standard run.
- Formatting, Ruff, strict mypy, Flutter analysis and database migration checks passed. No admin frontend checks ran because its source is absent.
- New regressions cover fast-reader ordering and timeout bounds, uncertainty retained after a slow detail pass, exact-reference lookup without redundant network calls, two concurrent previews, queue recovery after an error, duplicate request coalescing, cache expiry and account isolation.
- Docker API rebuilt and restarted. Signed Release installed and launched on the iPhone 12, preserving its existing data and automatic Bonjour connection. Installation is logged at `/tmp/meddex-scan-speed-iphone-install.log`.
