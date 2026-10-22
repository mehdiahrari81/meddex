# Prescription reader availability fix — 20 October 2026

The iPhone reached the API successfully, but Google's image-generation endpoint returned HTTP 503 `UNAVAILABLE` / high demand. Both configured cloud models could fail on the same scan. The former generic message incorrectly made this look like an unavailable medicine database.

## Changes

- Preserve Gemini 3.8 Flash as the preferred reader and Gemini 3.5 Flash as its alternate. Add Gemini 3.5 Flash-Lite as a third **cloud vision** recovery model for image transcription and medicine separation. It is already used by the assistant and was verified against this account with a real image request.
- Retry only transient transport errors and HTTP 408/500/502/503/504. Use bounded exponential backoff with jitter and honor `Retry-After` when it fits the request budget. At most three distinct model calls occur, sharing the existing 60-second recognition / 30-second separation budget; each remaining model gets reserved time.
- Remember temporary model failures for two minutes per API-key fingerprint/model, so subsequent scans and medicine separation avoid currently failing models. Only availability metadata is retained; no image, text, credential, or patient data is cached. The larger models become eligible again after cooldown. If all are temporarily unavailable, only probe the fast recovery model.
- Quota/payment/credential/configuration failures and unsafe, blocked or incomplete model output do not trigger alternate-model retries. Existing uncertainty annotation, strict source-text field validation, dose checks, consent, authentication and review requirements remain.
- Log actual model, attempt, elapsed time and upstream status without logging images, recognized text, keys or upstream exception bodies.
- Give persistent Google overload its own safe mobile error message. Other image-reading failures explain that the image remains saved and can be retried or replaced with a clearer photo.

Configuration: `services/api/.env`, server-side only:

```dotenv
MEDIEXPLAIN_GEMINI_SCAN_RECOVERY_MODEL=gemini-3.5-flash-lite
```

The existing private key is preserved. No new dependency, local vision model or larger Ollama model is installed. The assistant continues to use Qwen3 1.7B as its local fallback. Availability cooldowns are process-local; multiple-worker hosting would need a shared circuit breaker.

## Verification

- **192 backend tests passed**, including both larger models failing before successful recovery, later requests skipping failing models, cooldown expiry, shared timeout budgets, Retry-After, quotas, authentication failures and blocked output.
- **218 mobile tests passed**; three explicitly opt-in live suites were skipped. Formatting, Ruff, strict mypy, Flutter analysis and database migration checks passed. Admin frontend checks were skipped because its source is absent from this checkout.
- Rebuilt and restarted the Docker API; readiness returned healthy.
- Live authenticated end-to-end check using a generated portrait image containing one synthetic medicine row and no patient: image recognition **HTTP 200 / 15.66 seconds**, medicine separation **HTTP 200 / 1.27 seconds**, sourced explanation **HTTP 200 / 1.73 seconds**. Both larger models actually returned HTTP 503 during this test; Flash-Lite recovered successfully. Separation then used the healthy recovery model directly. The temporary QA account was deleted.
- Signed Release installed and launched on the connected iPhone 12 at the existing bundle ID, preserving its data. CoreDevice confirmed the running process (PID 15386); it targets the current Mac Wi-Fi address `192.168.100.59:8000`. Installation is recorded in `/tmp/meddex-gemini-availability-iphone.log`.

External Google outages and quotas cannot be eliminated, and an unreadable handwritten medicine must still be reviewed rather than guessed. No claim of universal handwriting accuracy is made from this synthetic availability test.

Google describes HTTP 503 and bounded retry/backoff in its [official troubleshooting guidance](https://ai.google.dev/gemini-api/docs/troubleshooting).
