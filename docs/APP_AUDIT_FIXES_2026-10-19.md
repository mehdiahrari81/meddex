# Audit fixes and verification — 19 October 2026

All six confirmed findings in the application audit have been addressed. Existing user records were preserved during development and installation; destructive tests used isolated local storage and disposable server accounts.

## Changes

1. **Local reset:** Settings → Manage saved data now removes the current profile's prescriptions and scan images, medicine plans and schedules, dose history, notes, refills, bookmarks, search history, learning progress, cached medicine lookups, export metadata, temporary scan files, and the app's temporary summary PDF. It cancels reminders before removing records, clears in-memory prescription workflow state, reopens the cleaned profile database, and resets preferences/onboarding. Reference lessons/flashcards/quizzes and other profiles are preserved. Pending cloud-deletion requests are kept without upload prerequisites; unsent uploads are discarded. Local reset does not delete the account or existing cloud backups. The confirmation explains this distinction.
2. **Notification switch:** The master preference now prevents reminder rebuilds and snoozes while disabled, cancels existing app reminders when changed, and rebuilds active plans when re-enabled. Startup also cancels stale reminders even when there are no active plans. Disabling notifications does not prevent recording taken/skipped doses. Scheduling rechecks the preference around asynchronous work. Notification actions resolve the current profile's reminder service after a reset or account change rather than retaining an old repository.
3. **Account deletion:** The Settings action requires sign-in and explicit confirmation, calls the existing authenticated `DELETE /users/me` endpoint, clears the current profile locally after acknowledged server success, and signs out/clears session credentials. A failed remote request does not erase local records. If local cleanup fails after remote success, the same dialog can retry cleanup without repeating the acknowledged remote deletion. The dialog prevents duplicate taps, displays progress, and reports failures instead of announcing success.
4. **Streaks:** Current streaks expire after a missed calendar day while longest streak and activity history remain intact. The dashboard refreshes at local midnight and after suspension. Consecutive-day arithmetic uses calendar dates to avoid daylight-saving duration errors. Repeated or older activity does not rewind a newer streak. Repository tests use an explicit clock instead of depending on the date tests happen to run.
5. **Settings destinations:** Manage sessions opens the existing real session-management screen. Privacy, Terms, and Data sources now open readable pages with English and Urdu content, source website addresses, and descriptions consistent with the implemented storage, cloud processing, deletion, and reference-review behavior. Source addresses can be selected/copied. No new dependency was added. The content describes the current development deployment and does not claim clinical or regulatory approval.
6. **Verification tooling:** The backend CLI formatting issue is fixed. The live smoke test accepts `--expected-content-version`, allowing strict verification of the installed lesson expansion while the isolated API test retains its fixture-version assertion. The combined verification script now completes instead of stopping at formatting.

## Checks completed

- Combined `scripts/verify-local.sh`: passed formatting, Ruff lint, strict mypy for 73 backend source files, **170 API tests**, fresh migrations/schema drift, Dart formatting, Flutter analysis, and the full mobile suite. The admin frontend step correctly reports that its source is absent from this checkout.
- Final mobile rerun after the notification-handler correction: **211 tests passed**, three opt-in live tests skipped by default, and **no Flutter analysis issues**.
- Settings widget checks cover real route navigation, confirmed/cancelled account-deletion dispatch, deletion cancellation/double-tap prevention/failure/retry, actual local-reset orchestration, and Urdu information pages at large text size.
- Erasure regression checks cover private file removal, persistence after database reopening, preserved reference content/other-profile files, pending deletion retry, storage failure recovery, and account deletion's remote-success requirement/local-cleanup retry.
- Streak checks cover missed-day expiry, preserved longest streak, a restarted streak, out-of-order activity, midnight refresh, and resume refresh.
- Notification checks cover disabling/re-enabling, immediate app-level refresh, snooze suppression, dose recording while notifications are off, and notification actions after a profile reset.
- Live HTTP/PostgreSQL smoke checks: **30/30 passed**, explicitly checking installed reference version `2026.10.19.1`.
- Two opt-in Flutter tests passed against the Mac's Wi-Fi API: real server account deletion with local file/data cleanup and credential revocation; and real authentication/offline prescription-medication save/delete synchronization.
- Temporary QA account count after these runs: **zero**. Reference counts remain **30 lessons, 60 flashcards, four quiz questions**. No Gemini generation calls were made during this work.
- Final signed iPhone Release build, code-signature verification, installation, and launch passed through `scripts/install-ios-device.py`. A subsequent device process check confirmed the final app running, and API readiness passed over the Wi-Fi address `192.168.63.106`. Existing app data was preserved.

## Remaining verification limits

The Gemini quota limitation is external to these fixes; live cloud OCR and medicine generation were not repeated. Existing mocked provider/handwriting tests passed. Handwriting accuracy, physical camera use, Face ID prompts, and actual background notification delivery still require hands-on device checks and are not guaranteed by the automated tests.

The admin web frontend source is missing from this checkout, so no claim is made about its UI/build/browser tests. Backend admin tests passed. This remains a local development deployment requiring the configured backend on the same reachable LAN. Account deletion cannot withdraw files already shared outside the app or clear local copies on another device.

## Evidence

- `/tmp/meddex-fixes-full-verification.log`
- `/tmp/meddex-fixes-final-mobile-tests.log`
- `/tmp/meddex-fixes-final-analysis.log`
- `/tmp/meddex-fixes-live-api.log`
- `/tmp/meddex-fixes-mobile-live.log`
- `/tmp/meddex-fixes-final-edge-tests.log`
- `/tmp/meddex-audit-fixes-final-iphone.log`
