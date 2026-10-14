# Local smoke test · 2026-10-12

The project runs locally. The API and admin smoke suites pass. Android runtime testing found defects that build-only checks missed; the fixes and their retests are recorded below. This is evidence for the tested flows, not certification that every feature works on every device.

## Running services

Compose project: `mediexplain-local`.

| Service | URL |
| --- | --- |
| Admin | http://localhost:13001 |
| API documentation | http://localhost:18000/docs |
| API readiness | http://localhost:18000/api/v1/ready |
| Local email inbox | http://localhost:18025 |

The Android emulator uses `http://10.0.2.2:18000/api/v1/`. There are no default administrator credentials. The existing named local testing accounts are recorded in the private, ignored `CREDENTIALS.md`; for a fresh installation provision your own account using the [local guide](LOCAL_DEVELOPMENT.md).

## Executed checks

| Check | Result |
| --- | --- |
| API formatting, lint, typing, and tests | Pass; 99 tests after AI fixes |
| SQLite migration upgrade and schema comparison | Pass |
| Live HTTP scenarios against running PostgreSQL | Pass; 26 scenarios |
| Real SMTP password reset through Mailpit | Pass; delivery, single use, password change, old-session revocation |
| Admin lint, types, unit test, production build | Pass |
| Chrome browser workflows | Pass; 9 workflows |
| Flutter analysis and tests after fixes | Pass; 134 tests, no analyzer issues |
| Live AI input/output against local Ollama and real official sources | Pass; 9 scenarios, including genuine English and Urdu generation |
| Android debug APK build | Pass |
| APK native-library inspection | Pass; JNI and SQLite libraries in arm64-v8a, armeabi-v7a, and x86_64 |
| Android release manifest merge | Pass; internet permission present |

The live API scenarios cover profile updates and deletion, consent, authorization, prescription CRUD/idempotency/conflicts, cross-account isolation, medicine field/barcode validation, confirmed medication sources, PRN schedule validation, dose-event deduplication, pause/resume state, terminology search/ranking/filtering, learning/quiz access, bookmarks, and session listing/revocation. Synthetic accounts are removed after each scenario.

Browser coverage includes login/logout and protected redirects, role restrictions, CSV dry run/application/errors, administrator navigation, independent reference review/publication/download, phone-sized navigation without page-width overflow, dashboard totals and activity periods, search/filtering/pagination, and confirmed report resolution with refreshed totals.

The API and admin checks were rerun after the [admin dashboard update](ADMIN_DASHBOARD.md). The rebuilt local portal contains 24 labeled demo content records, 6 synthetic reports, and 2 failed-import examples. Its desktop and phone views were inspected, and actual page widths matched 390/768/1024/1440-pixel viewports. The mobile and live HTTP evidence below is from the earlier runtime pass; this dashboard update did not change mobile code.

The local admin login now shows email and password by default. An authenticator code is requested only after selecting its optional control. Chrome verified the existing local account signs in without a code; the isolated login check covers toggling/clearing the optional field, wrong-password feedback, successful password-only login, and logout. Admin lint, types, unit test, and build passed again. The other eight browser workflows passed, and the corrected login check passed on its targeted rerun. Two API authentication checks also passed, including verification that enrolled accounts still require a valid authenticator code.

After a reported credential rejection, the saved credentials succeeded in a fresh browser. The requested local admin account was then given an easier-to-type password through the actual SMTP recovery flow. The private `CREDENTIALS.md` was updated, the old password and session were confirmed rejected, and API and Chrome login with the new password and no MFA code succeeded. Chrome reached the dashboard without page errors. The captured recovery email was removed from Mailpit afterward; no other accounts or application data were changed.

## AI and voice verification

The local AI assistant is now configured and enabled using Ollama `qwen3:8b`. The default production configuration remains disabled. Setup, usage, data flow, and remaining clinical-review requirements are in the [AI and voice guide](AI_FEATURES.md).

The [recorded live inputs and outputs](smoke-evidence/2026-10-12/ai-live-smoke.json) contain **9/9 passing scenarios** against the running PostgreSQL/API and actual model. The test resolved RxNorm `198440`, confirmed acetaminophen 500 MG Oral Tablet, and retrieved 10 actual official-source facts. English warnings, English uses, student explanation, and Urdu explanation all returned `ai_provider_used=true` with DailyMed source references. The final run's generations took 12–26 seconds on this host. Unrelated questions, missing medicine context, English/Urdu dose changes, and prompt injection returned the expected limited responses without generation. The disposable verification account was removed afterward; legitimate shared source cache entries were retained.

Automated regression coverage additionally checks malformed/blank/wrong-language model output, timeouts, invalid source IDs, source-extract labeling, encrypted question/answer persistence, real provider-health recording, exact number/unit matching, thousands separators, liver/stomach translation mismatch, quoted label warnings versus prescriptive dosing, exact-name RxNorm lookup, combination strengths, candidate ranking, and cache-version refresh. Mobile checks cover request cancellation races, late responses after disposal, retry, Urdu/student request parameters, unavailable speech recognition, actual voice-command navigation, and refusal of dose-change actions. These checks use controlled provider responses; the nine live cases above separately exercise the real model.

Defects corrected include disabled/missing AI configuration, an 8-second server and 20-second mobile timeout, cached empty medicine lookup results surviving provider changes, incomplete exact-name/combination lookup, overly broad numeric/dosing validation, unsafe late-response updates, generic failure messages, silent voice failures, and recognized commands that previously only displayed navigation suggestions.

Android testing also exercised the real flow: sign in with a disposable account → Home medicine search → review and confirm the exact candidate → open the assistant → submit a warnings question → receive an **AI explanation** → open its **DailyMed** provenance page. Screenshots show the [actual generated answer](smoke-evidence/2026-10-12/ai-assistant-android.png) and [official-source details](smoke-evidence/2026-10-12/ai-source-android.png). The voice assistant now has a visible microphone entry point in My Medications, including when no medication plans are saved.

The final Android build also completed **Profile → My Medications → Voice assistant → type “Search hypertension” → Review command → Search terminology**, opening the real Hypertension results. Evidence shows the [recognized command and action](smoke-evidence/2026-10-12/voice-assistant-android.png) and [resulting search page](smoke-evidence/2026-10-12/voice-search-android.png). Gboard's emulator stylus tutorial initially intercepted test input; dismissing it resolved that device issue. This walkthrough verifies typed command parsing and navigation, while microphone recognition/audio still requires physical-device testing.

The temporary Android account was signed out and deleted, its exact account-scoped local database and temporary credentials were removed, and the emulator's handwriting setting was restored. Existing named accounts, guest data, and shared source cache were preserved. The rebuilt app was left on guest Home. No unhandled Flutter exceptions appeared in the recorded AI/voice walkthrough log; a debug-only Drift multiple-database warning appeared during the account switch.

## Android runtime evidence

Device: isolated `mediexplain_smoke_api36` emulator, Android API 36, arm64, Pixel 6 configuration. No existing user emulator was modified.

- Onboarding and educational consent work and persist across a cold restart.
- Registration reaches the running API and displays an authenticated profile.
- Session listing and current-device revocation work; revocation returns to guest Profile after the fix. Signing in again and ordinary Profile sign-out work. The guest Saved Library does not show the account's saved terminology.
- English ↔ Urdu and System → Dark → System changes preserve the Settings screen. Urdu uses RTL layout.
- Local terminology search finds Hypertension; detail shows reviewed definitions and sources; bookmarking changes the saved state.
- The word decoder splits `bradycardia` into slow / heart / condition, and abbreviation search finds PRN / As needed.
- Home → term search → Back returns to Home after the navigation fix.
- A complete three-section lesson saves successfully after repairing duplicate streak records from the earlier failed run.
- Flashcard reveal/review, a complete quiz, results, mistake review, and the persisted progress dashboard work.
- Manual prescription entry, medicine-name/item review, explicit final confirmation, saved summary, and return to Scan work.
- Medication creation, Android notification permission, actual scheduled alarms, pause/resume, and return navigation work. Alarm registration was observed with `dumpsys alarm`; notification delivery at the scheduled time was not observed.
- Importing a synthetic PNG through Android's document picker, private preview, actual ML Kit OCR, and structured review work. Recognized medicine/dose text remains unconfirmed until the user reviews it. Recognition accuracy on handwriting is not established by this printed fixture.

The final APK was installed and the corrected session flow retested on the emulator. The final Flutter runtime log contained no unhandled exceptions. The synthetic Android account and temporary credentials were removed after testing. The guest test medication plan and dose logs were deleted through the app; its Home reminder disappeared and Android's alarm history recorded cancellation. The app was left on guest Home. The local stack and isolated emulator remain running.

## Defects found and corrected

1. **Release network permission:** internet access was declared only in debug/profile manifests. Added it to the main Android manifest and verified the merged release manifest.
2. **Incomplete local NDK:** an existing compiler shim omitted `libdartjni.so` despite a successful APK build. JNI initialization stopped later plugins from registering, breaking reminder creation and persistent preferences. Installed the complete official NDK after verifying its SHA-1 against Google's SDK metadata. Preserved the old shim under the SDK's `.mediexplain-backups`. Added a native-library check to local Android verification and CI; it rejects the original broken APK and accepts the corrected build.
3. **Navigation dead ends:** Home used route replacement for standalone tools, and completed workflows could lose their back stack. Home tools now preserve navigation history. Prescription/medication workflow roots have explicit fallback back buttons, and successful medication creation replaces only the form. Nine routing regression checks cover Home tools and root fallback navigation.
4. **Learning completion crash:** SQLite generated a new rowid when the streak insert omitted its integer primary key; repeated activity then caused `Too many elements`. Writes now explicitly use singleton ID 1 in a transaction. Existing duplicates preserve the latest activity and longest streak, then consolidate on the next write. Two regression checks cover repeated activity and recovery; the previously failing lesson was completed on the emulator.
5. **Settings reset navigation:** changing language or theme recreated the router and sent the user to Home. The router now stays alive, refreshes authorization/onboarding redirects from current state, and is disposed with its provider. A regression check verifies that language and theme changes preserve the Settings route.
6. **Current-session revocation left an error screen:** revocation correctly signed the device out but left the session list visible, which then attempted an authenticated reload. Current-device revocation now returns to Profile, and the session provider skips requests for guests. Regression checks cover both current-device sign-out and refreshing the list after revoking another device.

Screenshots contain synthetic/local test data: [term detail](smoke-evidence/2026-10-12/04-term-detail.png), [actual OCR review](smoke-evidence/2026-10-12/05-ocr-review.png), [medication plan](smoke-evidence/2026-10-12/06-medication-plan.png), [quiz results](smoke-evidence/2026-10-12/07-quiz-results.png), [saved prescription](smoke-evidence/2026-10-12/08-prescription-saved.png), [Urdu settings](smoke-evidence/2026-10-12/09-urdu-settings.png), and [dark theme](smoke-evidence/2026-10-12/10-dark-settings.png). Quiz answers were deliberately incorrect to exercise mistake review.

## Repeat the checks

```sh
PLAYWRIGHT_CHANNEL=chrome ./scripts/verify-local.sh --browser --android

cd services/api
.venv/bin/python -m tests.smoke_live_api --url http://127.0.0.1:18000
.venv/bin/python -m tests.smoke_ai \
  --output ../../docs/smoke-evidence/2026-10-12/ai-live-smoke.json
.venv/bin/python -m tests.smoke_local_stack \
  --api http://127.0.0.1:18000/api/v1 --mail http://127.0.0.1:18025
```

The HTTP smoke commands accept localhost only. The browser suite uses a separate disposable database. Android UI checks were performed through ADB and the actual app, and are not included in the root automated verification command.

## Still requires verification

Physical-device camera capture, handwriting OCR accuracy, barcode camera scanning, notification delivery/reboot/timezone behavior, speech recognition/audio quality, biometrics, sharing/printing, and iOS require further device checks. Urdu works for core translated screens and RTL layout; some medication and prescription workflow labels still use English. Live RxNorm/DailyMed retrieval and local AI were exercised for the recorded medicine example; this does not certify every medicine or future provider availability. Model paraphrases and translations require independent clinical review. Interaction checking remains unavailable without a validated provider. Production still requires the [production checklist](PRODUCTION_CHECKLIST.md), including licensed reviewed content and signing.
