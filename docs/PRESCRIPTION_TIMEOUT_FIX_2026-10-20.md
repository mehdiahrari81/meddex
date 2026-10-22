# Prescription scan timeout fix — 20 October 2026

## Reproduced causes

The installed iPhone build pointed to `192.168.63.106`. Its generated Release plist confirmed that host. The Mac had moved to Wi-Fi address `192.168.100.59`; the old address timed out while the current API returned readiness immediately.

A separate authenticated synthetic-image test reached the API but failed after 40.72 seconds with an upstream Gemini `ReadTimeout`. Model-list verification confirmed both configured cloud models remained available. The prescription availability fallback handled HTTP errors but did not handle transport/read timeouts, and the first attempt could consume its entire time budget.

## Changes

- Rebuilt the iPhone Release app for the Mac's current Wi-Fi address.
- Added **Settings → Server connection** in development builds. It accepts a trusted private-LAN HTTP or hosted HTTPS server, checks only the anonymous readiness endpoint, refuses redirects, and saves the address only after verification and successful persistence. The URL cannot contain credentials, queries, or fragments. It can be changed without reinstalling. No automatic network scanning or token forwarding to discovered hosts was added.
- The connection address is loaded before authentication and configures both normal API requests and session refresh. Old clients are disposed when the address changes without deleting the stored login. The address is kept separately from personal preferences so local-data reset does not silently restore an obsolete server address. Production builds ignore the development override and continue requiring HTTPS.
- The local development installer permits runtime HTTP server changes in its generated, ignored development plist; ordinary production Release transport policy remains unchanged. The app's URL validator rejects public HTTP endpoints.
- Prescription generation now reserves time for one alternate-model attempt and handles transport timeouts as well as transient HTTP errors. Image transcription has a 60-second attempt budget, with at most 30 seconds allocated to its first attempt and the remainder available to the alternate model. The optional uncertainty review remains separately bounded at 20 seconds. Text separation retains its 30-second budget; the mobile image/text limits remain 120/45 seconds.
- Quota, invalid credentials, blocked/truncated output, and validation failures are not retried through this availability fallback. Actual model attribution and prescription uncertainty are retained. Ollama remains the text assistant fallback; no image model was loaded locally.
- Network timeout guidance now identifies the Server connection setting. Exhausted cloud attempts return a distinct `gemini_request_timeout` code rather than being described as unverified medicine extraction. Saved scans remain available for retry.

## Verification

The real authenticated synthetic fixture contained no patient data and was not stored as a prescription. After deployment:

| Stage | Result | Time |
| --- | --- | --- |
| Image recognition | HTTP 200, actual model `gemini-3.5-flash` after primary timeout recovery | 35.19 s |
| Medicine separation | HTTP 200, exactly the expected medicine | 4.63 s |
| Medicine explanation | HTTP 200, available with source references | 4.68 s |

This verifies transport and the scan pipeline, not accuracy on all handwritten prescriptions. The temporary QA account was deleted; no temporary scan QA accounts remained.

The signed Release update was installed and launched on the connected iPhone 12. The running process was confirmed. After launch, the backend received a successful HTTP 200 session-refresh request, confirming that the phone reached the new server address. The existing account and local records were preserved.

The full verification script passed: **217 Flutter tests**, **177 API tests**, Dart/Ruff formatting, Flutter analysis, Ruff lint, strict mypy, and fresh database migration/schema checks. Three opt-in mobile live tests were skipped in the default suite. The admin frontend source remains absent and its checks were skipped. No reference lessons, quizzes, existing prescriptions, or medications were deleted.

New tests cover reserved alternate-model time, bounded repeated timeouts, no retries for quota/credentials, URL validation, anonymous non-redirecting readiness checks, connection persistence, both API/refresh configuration, isolation from unrelated settings changes, and failure/retry in the server-connection dialog.

## Evidence

- `/tmp/meddex-timeout-live-scan.log` — original upstream timeout.
- `/tmp/meddex-timeout-live-scan-fixed.log` — successful real scan pipeline.
- `/tmp/meddex-timeout-full-verification.log` — full checks.
- `/tmp/meddex-timeout-mobile-focused.log` — connection regression tests.
- `/tmp/meddex-timeout-deploy.log` — backend deployment.
- `/tmp/meddex-timeout-iphone.log` — signed device build/install/launch.

The local backend still requires the Mac to be awake, API services running, and both devices on a network that permits peer connections. Provider availability remains external; unreadable handwriting still requires review.
