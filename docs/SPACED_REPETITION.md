# Spaced Repetition

MediExplain uses a deterministic, forgiving SM-2-inspired scheduler.

- New cards start at ease 2.5 and are due immediately.
- `again` resets repetitions to zero, decreases ease by 0.2 (floor 1.3), and retries after one day.
- First successful review schedules one day.
- Second successful review schedules six days, or three for `hard`.
- Later intervals multiply the previous interval by ease; `hard` applies a 0.8 factor. Intervals always increase by at least one day and cap at 365 days.
- The SM-2 ease delta is applied for `hard`, `good`, and `easy`, clamped to 1.3–3.0.
- Missed days do not add punishment; the next interval is calculated from the persisted schedule and actual review time.

The schedule stores repetitions, ease factor, interval, last review, next review, and performance. The implementation accepts an explicit clock value and has deterministic unit tests. Reviews persist offline and enqueue an idempotent user-data sync operation.
