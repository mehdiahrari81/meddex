# Check and confirm scanned medicines — 20 October 2026

Each medicine card now has **Check** and **Confirm** next to each other. Check opens the existing manual field editor, replacing the conditional “Check unclear details” / “Confirm details” action and the redundant Edit details button. Remove medicine remains available separately.

Confirm explicitly approves the displayed medicine details. It atomically stores field acknowledgments and the existing user-verification transitions, then shows a themed tick beside Confirm. The tick comes from persisted state, survives reopening, and clears if a field is edited. Check remains available after confirmation. Confirmation is not an automatic claim of clinical verification, and it does not add medication/reminder records; the existing Add to My Medications flow remains.

Readable fields previously flagged by OCR can be acknowledged by this explicit user action without inventing or changing their values. Original transcription, source, confidence and possible-meaning metadata remain. Missing optional fields stay absent. A missing medicine name or literal unreadable text such as `?` / `[illegible]` in medicine, strength, form, dose or frequency must be corrected with Check. Validation runs before any field is confirmed, inside one transaction. Repeating a completed confirmation is idempotent; buttons are disabled while the operation is pending.

Validation:

- 235 mobile tests passed (three opt-in live suites skipped); Flutter analysis and formatting passed.
- Real local-database UI test: Check opens the actual editor; Confirm persists all displayed fields and a visible tick; reloading keeps the tick; a manual correction clears it; reconfirming saves the corrected result. A second medicine is left untouched.
- Regression test: unreadable fields cause no partial confirmation, and repeated confirmation creates no duplicate verification events.
- Normal iPhone-width and 200% text layouts passed and were visually inspected. Original image, explanation, and deletion controls remain.
- Backend APIs and cloud models were unchanged. Signed Release installed and launched on the connected iPhone 12, preserving its existing data and automatic Bonjour connection. Installation is recorded in `/tmp/meddex-check-confirm-iphone-install.log`.
