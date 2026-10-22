# Set medication reminders — 20 October 2026

The medication detail action is now **Set reminder**, with a matching **Set Reminder** screen title. Saving a time explicitly enables the medication plan and its schedule in the same database transaction. Previously, confirmed prescriptions were correctly saved without reminders, but replacing the empty schedule preserved that disabled state, so Home and the notification scheduler ignored the saved time.

Setting a reminder also resumes a paused medication. Repository calls that only edit a schedule still preserve its pause unless activation is explicitly requested. The updated active state, timezone and schedule are included in the existing sync snapshot. Failed saves roll back schedule replacement and activation together. Source prescription instructions remain unchanged.

Home reacts to the existing database stream and displays the earliest upcoming active reminder. Its lookup now covers the same 30-day window as notification scheduling, including weekly reminders more than two days away. As-needed medicines still have no fixed reminder; system alerts still require notification permission and the app's notification preference.

Validation:

- Flutter analysis passed; 240 mobile tests passed, with three opt-in live suites skipped.
- Real database/widget tests confirm prescription review → save to My Medications → Set reminder → save → return to Home, both with notification permission granted and denied. With granted permission, the correct plan and timezone reach the notification scheduler.
- Tests cover weekly reminders beyond two days, paused schedule preservation/resumption, invalid-time rollback, complete sync snapshots, unchanged prescription instructions, missing-dose validation, interval anchors, selected weekdays and as-needed schedules.
- No backend, AI model or API-key changes were required.
- Signed Release installed and launched on the connected iPhone 12, preserving app data and the automatic Bonjour connection. Deployment log: `/tmp/meddex-set-reminder-iphone-install.log`.
