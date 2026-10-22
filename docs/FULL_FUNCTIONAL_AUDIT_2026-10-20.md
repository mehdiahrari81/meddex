# Full application audit — 20 October 2026

The main implemented workflows passed the checks below. **The app cannot yet be described as having every option fully implemented.** This audit found additional gaps beyond the regular test suite. Learning and pronunciation-screen faults were fixed; incomplete auxiliary features are listed separately so passing regression tests are not mistaken for full feature coverage.

Tests used isolated local databases, disposable server accounts and a synthetic printed prescription image. Existing user data was preserved. The synthetic account prefixes used by the API, authentication, scan and mobile-sync scripts had zero remaining accounts after testing; the separate password-reset account was also deleted. No genuine prescription or patient image was uploaded during this audit.

## Fixes delivered

- Lesson loading now displays a retryable error instead of remaining on a loading indicator after a repository failure. Empty lessons with existing progress no longer attempt an invalid index clamp.
- Advancing a lesson now stores the section the user reaches, so leaving and returning resumes that section. Completion scoring and the lesson/quiz content were not changed.
- Lesson, flashcard and final quiz saves now report failures, preserve the current work and allow retry. Pending saves block duplicate taps. Starting a quiz also blocks duplicate requests before the next UI frame.
- Failed final quiz saves retain the selected answer without appending duplicate answers on retry.
- Leaving a terminology pronunciation screen stops audio without reading a disposed Riverpod reference. Playback failures display a message; cleanup failures are logged without breaking navigation.
- New error messages have English and Urdu translations. The reminder repository documentation was formatted so the combined verification script can complete.

Ten new widget checks cover these behaviors, including delayed writes, duplicate taps, save failures, retry, lesson reopening, unavailable audio and failing audio cleanup.

## Checks completed

| Area | Evidence and practical scope |
| --- | --- |
| Startup and navigation | Startup retry, onboarding/routing guards, router lifecycle and Home navigation tests passed. Route map and user-facing destinations inspected. |
| Authentication | Real PostgreSQL/HTTP registration, Argon2id hashing, correct and incorrect login, refresh, logout, revoked access and restored session passed. |
| Password recovery | Real local SMTP delivery to Mailpit, single-use reset code, changed password, old-password rejection and session revocation passed. No external email delivery was used. |
| Prescription scanning | Live Gemini image reading, medicine separation and three sourced explanations passed. The synthetic image contained Lipitor, Metformin and Betaloc. Image-to-fields took 9.97 seconds; all three explanations completed by 20.85 seconds total. This measures the API pipeline, not phone capture/upload time or difficult handwriting accuracy. |
| Prescription review | Regression tests cover manual correction, explicit confirmation/tick persistence, rejected unreadable text, deletion of items and drafts, image cleanup, saved medicines and offline synchronization. |
| Medication plans | Creation, confirmed-scan saving, Set reminder, Home appearance, weekday/interval schedules, as-needed tracking, pause/resume, completion, archive, deletion and data cascades passed their relevant tests. |
| Taken/skipped history | Dated record persistence, corrections, duplicate handling, current history display, notification actions, snoozing and adherence calculations passed automated checks. |
| Learning | Thirty lessons, sixty flashcards and four unchanged quiz questions remain installed. Content import, scoring, progress, streak expiry, midnight/resume refresh, daily terms and the new failure/retry tests passed. |
| Terminology and saved content | Search/ranking, spelling handling, morphology, abbreviations, bookmarks, source metadata, reporting and local persistence covered by repository/API tests. |
| Medicine information and assistant | Source-backed explanations passed live checks. Assistant selection is Gemini first; actual Ollama **qwen3:1.7b** returned valid structured output after a locally simulated Google 429 in 3.53 seconds. That fallback test did not call Google. It verifies the local 1.7B model, not a vision model. |
| Sessions, consent and account deletion | Live API scenarios and real Flutter transport checks passed ownership, session revocation, consent, account erasure and local file/data cleanup. |
| Offline/account boundaries | Separate profile databases, pending operations, deletion when uploads are disabled, retries and real mobile save/delete synchronization over the Mac's Bonjour address passed. Cross-device restoration was not exercised. |
| Accessibility/localization | Existing large-text, RTL, Urdu, theme/readability and semantics checks passed. See the unapplied preferences below. |
| Database/reference integrity | Fresh SQLite migration/schema-drift checks and the running PostgreSQL schema check passed. Reference counts remain 30 lessons, 60 flashcards, 4 quiz questions, 34 terms and 89 medicine identities. No reference data was changed. |
| Native builds | Android debug APK compiled; required native libraries were present for arm64-v8a, armeabi-v7a and x86_64. iPhone Release deployment is recorded separately below. |

Final checks: **250 mobile tests passed**, with three opt-in live suites skipped in the default run; **194 backend tests passed**; **30/30 live API scenarios passed**; **two opt-in real Flutter transport tests passed**; three installer tests passed. Ruff formatting/lint, strict mypy for 73 backend files, Dart formatting and Flutter analysis passed. The backend test client emits a dependency deprecation warning. Android emits plugin migration notices but builds successfully.

The key file remains Git-ignored with private `0600` permissions; no key was displayed or changed.

## Remaining confirmed gaps

These are not covered by a claim that the app is fully complete. The first two were reproduced with additional expected-behavior tests outside the regular suite; **both reproduction tests failed** because the requested alert was absent.

1. **Refill reminders save data without scheduling a refill alert.** `RefillReminderScreen` calls `saveRefill`, but the reminder service only creates dose notifications. A date was successfully saved in a real local database; rebuilding notifications still produced only the thirty dose notifications. The refill editor also does not reload an existing saved refill, and the inventory estimate subtracts all logged doses rather than establishing a new supply baseline when the quantity changes. Relevant code: `apps/mobile/lib/features/medications/presentation/medication_screens.dart:1739`, `apps/mobile/lib/features/medications/data/local_medication_repository.dart:997`, `apps/mobile/lib/features/medications/application/medication_reminder_service.dart:45`.
2. **Neutral daily reminder summary is a saved preference only.** Its current subtitle explicitly describes a future notification. Enabling the preference and rebuilding produced no summary notification. Relevant code: `medication_screens.dart:2078` and the reminder service.
3. **Obscure app preview is not connected to a platform privacy implementation.** The setting persists, but neither the Flutter app lifecycle nor the Android/iOS implementation reads it to obscure the recent-apps snapshot. It should not be relied on for that protection. Biometric locking is a separate implemented feature. Relevant code: `medication_screens.dart:2065`, `apps/mobile/lib/app/app.dart`, Android `MainActivity.kt`, iOS `AppDelegate.swift`.
4. **The medication-privacy image-retention switch is not the setting used by confirmation.** “Retain prescription images” updates `MedicationPrivacyPreferences.retainPrescriptionImages`; confirmation instead reads `AppSettings.deletePrescriptionImagesAfterConfirmation`. Enabling the former therefore does not override the latter's default deletion. The actual Settings deletion preference works, but these two controls are inconsistent. Relevant code: `medication_screens.dart:2027` and `apps/mobile/lib/features/prescription/application/prescription_workflow_controller.dart:588`.
5. **Some general preferences do not affect behavior.** “Larger controls” and “Haptic feedback” are persisted but are not consumed by the theme/control sizing or haptic calls. The app uses standard minimum touch targets regardless of the larger-controls switch. Analytics is likewise a stored preference, with no analytics collection pipeline implemented. Text scale, high readability, reduced motion, theme and language do have consumers. Relevant code: `apps/mobile/lib/features/settings/presentation/settings_screen.dart:154`, `:170`, `:284`, and `apps/mobile/lib/design_system/app_theme.dart`.
6. **Medication export omits schedule distinctions.** The export flattens schedule times without including paused/completed state or selected weekdays. An interval schedule with no fixed time list is rendered as “no fixed reminders.” Text/PDF generation exists, but the exported schedule description needs improvement before it represents all supported schedule types accurately. Relevant code: `apps/mobile/lib/features/medications/application/medication_export_service.dart:70`.
7. **Home's next-reminder label can become stale while the screen sits idle.** It calculates the current time on widget rebuild and watches plan/history changes, but has no clock or resume refresh of its own. Scheduled OS alerts are separate; this finding concerns the displayed next occurrence. Relevant code: `apps/mobile/lib/features/home/presentation/home_screen.dart:177`.

Items 3–7 are code-path findings, not claims of observed failures during physical phone interaction. They require implementation/regression work beyond the learning/audio fixes delivered here. No new telemetry, clinical interpretation or automatic dose inference was added during the audit.

## Verification limits

- Physical camera operation, Face ID prompts, microphone recognition, share-sheet completion and actual background notification delivery were not manually exercised on the iPhone. Simulated/plugin tests and successful builds do not prove those hardware behaviors.
- Live OCR used an ideal printed engineering fixture. Difficult handwritten prescriptions, unclear medicine names and missing instructions still require patient review; recognition of every possible prescription is not guaranteed.
- Medicine matching, barcode resolution and explanations depend on available trusted references; unresolved identities must not be guessed. The drug-interaction provider is explicitly not configured.
- Gemini availability/quota and external reference services can change after a successful check. Ollama fallback applies to the assistant; Qwen3 1.7B is not a handwriting vision fallback.
- This is a local development deployment. The Mac/backend must be awake and reachable on the same LAN; Wi-Fi access-point switching was not physically repeated in this audit.
- Admin frontend source is absent from this checkout. Backend admin tests passed; admin web screens/build/browser behavior could not be checked.
- The installed learning catalog remains development/reviewed content, rather than an assertion of a production-approved clinical curriculum.

## Evidence

- `/tmp/meddex-full-audit-verification-2026-10-20.log` — backend, migrations and initial regression run.
- `/tmp/meddex-full-audit-final-mobile-tests.log` — final 250 passing mobile tests.
- `/tmp/meddex-full-audit-final-analysis.log`, `/tmp/meddex-full-audit-final-format.log`.
- `/tmp/meddex-full-audit-learning-actions.log`, `/tmp/meddex-full-audit-audio-actions.log`.
- `/tmp/meddex-full-audit-live-api.log`, `/tmp/meddex-full-audit-live-auth.log`, `/tmp/meddex-full-audit-password-reset.log`.
- `/tmp/meddex-full-audit-mobile-live.log`, `/tmp/meddex-full-audit-live-scan.log`, `/tmp/meddex-full-audit-ollama.log`.
- `/tmp/meddex-full-audit-option-gaps.log` and `/tmp/meddex_option_gaps_test.dart` — the two additional failing alert-feature reproductions.
- `/tmp/meddex-full-audit-postgres-schema.log`, `/tmp/meddex-full-audit-reference-counts.log`.
- `/tmp/meddex-full-audit-final-android.log`, `/tmp/meddex-full-audit-iphone-install.log`.
