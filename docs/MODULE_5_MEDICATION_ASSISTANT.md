# Module 5 — Personal Medication & Health-Literacy Assistant

## Repository audit

The audited checkout contains the secure/auth/offline foundation, terminology and
learning system, and prescription capture/parsing/confirmation workflow. Its
prescription safety boundary is `readyForMedicationLookup` at prescription level
and `readyForLookup` plus a `userConfirmed` medication-name field at item level.

No Module 4 trusted medication/RAG implementation is present in this checkout.
Module 5 therefore records `medicationInformationId` as an optional reference and
shows trusted information as unavailable. It does not synthesize medicine facts,
citations, missed-dose guidance, interaction claims, or AI explanations.

The pre-existing notification abstraction was an unavailable two-method stub.
Module 5 replaces it with permission, platform-adapter, scheduler, and medication
reminder layers. Existing Drift storage, outbox synchronization, private image
storage, Flutter TTS, localization, settings, analytics opt-in, and redacting
logger are reused.

## Safety invariants

- Prescription-derived plans require a fully user-confirmed prescription and
  medicine identity in both local and server repositories.
- Raw prescription instructions and the user-confirmed source snapshot are
  stored separately from reminder schedules. The source snapshot is immutable.
- Reminder times are explicitly chosen by the user. Frequency abbreviations do
  not generate clock times. As-needed medicines have no fixed reminders.
- Every-N-hours schedules require an explicit interval and user-selected anchor.
- Opening a notification is never a dose event. Taken/skip actions require the
  app UI to open; voice state changes require visual confirmation.
- Dose corrections append a revision and retain the superseded event.
- Missed doses receive neutral wording; the app never advises taking now or
  doubling.
- Adherence percentages use scheduled doses only and do not imply outcomes.
- Refill remaining quantity is explicitly estimated from user-confirmed starting
  quantity and latest logged taken-dose states.

## Offline, sync, and conflict behavior

Plans, schedules, reminders, logs, notes, history, refill tracking, privacy,
calendar, export preview, and saved content are local-first. Medication plan
mutations use the existing idempotent outbox. Dose log sync is disabled by default
and is queued only after explicit opt-in.

Dose IDs are stable logical dose IDs. Server uniqueness covers client event IDs
and logical-dose revision. Local conflict resolution selects higher revision,
then newer `recordedAt`, then stable ID, while retaining all correction rows.

## Reminder reliability and timezones

Schedules store an IANA timezone. Wall-clock schedules are generated within that
timezone; explicit every-N-hours schedules preserve elapsed hours across DST.
The app detects device-timezone changes, preserves stored schedules, and asks the
user to review times. Notifications use a bounded 30-day/60-item rolling window
for iOS limits. Android boot/update receivers restore scheduled notifications,
and app startup reconstructs the window. If exact alarms are unavailable, the
adapter uses inexact delivery and the UI explains OS timing limitations.

## Privacy and accessibility

Private notification content is the default. Full details, medicine name only,
and private reminder modes are supported. Medication log sync is opt-in. Export
is preview-first, excludes personal notes by default, and labels output as a user
summary rather than an official prescription. Biometric lock delegates to device
authentication. The app never stores biometric templates.

Medication views include semantic labels, explicit headings, large-text-safe
scrolling, confirmation dialogs, read-aloud controls, and bounded speech input.
Existing Urdu/RTL, large-control, high-readability, reduced-motion, haptic, and
TTS settings are reused.

## Platform limitations

- Actual lock-screen action behavior, OS notification disabling, Android power
  management, exact-alarm approval, boot recovery, iOS pending limits, Face ID /
  fingerprint prompts, speech permissions, and physical device restart must be
  verified on signed physical Android and iOS builds.
- iOS recent-app switcher obscuring is not implemented. Notification privacy and
  biometric relock are implemented; app-switcher behavior varies by platform.
- Local database encryption at rest is not added by Module 5; the repository's
  existing private application storage and secure session vault remain in use.
- The checked-out project has no Module 4 trusted drug information/RAG system, so
  those integrations intentionally remain references/statuses rather than
  fabricated content.
