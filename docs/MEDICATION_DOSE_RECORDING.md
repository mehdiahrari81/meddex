# Taken and skipped dose recording

Updated 19 October 2026.

The reminder timeline previously built every row with `DoseAction.notRecorded` and never read saved dose events. Recording only invalidated a separate history provider; My Medications did not display dose events at all. The result could appear unchanged even after a successful database write.

Selecting Taken or Skip now records that explicit action immediately in the account's local SQLite database. The menu shows progress while saving and reports a failure with a retry message. The timeline and My Medications subscribe to database history changes, showing the current action and its recorded date/time in the device's local timezone. Each medication card links to its complete dose history. No network or Gemini request is needed to record a dose.

Corrections append audit revisions, while patient-facing lists show one current status per scheduled dose. App and notification double taps are deduplicated within a transaction. Records survive database close/reopen. My Medications displays the latest entry for each medication, and the history screen shows the individual dated entries. Existing saved records become visible through the same subscriptions.

Completed dose occurrences are excluded from the next-reminder card and from reminder reconstruction, and recording cancels the dose's pending regular notification. The prescribed dose, frequency, and original instructions are unchanged. Medication-history synchronization remains governed by the existing opt-in privacy setting.

Validation: 180 Flutter tests passed and Flutter analysis reported no issues. The six additional regressions cover timeline Taken/Skip and correction display, My Medications updates from notification actions, failed save/retry, real-file persistence across reopen, simultaneous app/notification deduplication, and omission of recorded doses when rebuilding reminders. The existing authentication, prescription, medication, scheduling, accessibility, and localization suites also passed. These checks use isolated engineering fixtures and do not modify patient records.

## Delete a saved medication

My Medications (including the entry reached from Profile) now has a delete bin beside each medication. The confirmation names the selected entry and explains that its reminders, dose history, notes and refill records will be permanently removed. The detail screen uses the same full deletion flow. Cancellation and a failed-reminder-cleanup retry are covered by widget tests.

Deletion cancels matching pending and delivered notifications by their plan IDs, including snoozes, without cancelling another medicine's reminders or requiring notification permission. All of the selected medication's plans, source snapshots, schedules, reminder times, dose revisions, notes, refill records and activity history are removed from local storage in one transaction. A separately saved prescription remains in Prescription History.

Old queued medication/dose payloads are scrubbed and replaced with opaque completion markers so they cannot upload deleted medicine details or break other pending deletion prerequisites. A saved-medicine deletion is queued for the owned backend record. Requested erasure still synchronizes when ordinary backup uploads are disabled; offline deletion remains queued until authentication/connectivity returns. The server removes related records and retains only a blank opaque deletion marker, which prevents delayed uploads from restoring the deleted medicine. Re-adding a medicine explicitly creates a new saved entry.

Validation on 19 October 2026: 185 Flutter tests and 157 API tests passed; Flutter analysis, Ruff and mypy passed. Tests include notification cancellation for only the target medication, retry/cancel, SQLite reopen, dependent-record cleanup, deleted-source outbox cleanup, owner isolation, idempotent deletion and delayed-upload rejection. A real mobile-to-API check passed offline save/delete synchronization and deletion of the synced medicine while regular uploads were disabled. Its temporary account was removed afterward.
