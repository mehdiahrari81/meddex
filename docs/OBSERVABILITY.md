# Observability

`/api/v1/health` is process liveness; `/api/v1/ready` executes a database query. Request IDs are accepted only in a safe format or generated and returned. Structured JSON logs contain event codes/request IDs, not bodies.

Permission-gated `/api/v1/admin/metrics` reports uptime, request/server-error counts, and latency aggregates using identifier-redacted route labels. Provider health uses real persisted request events: provider, operation, success, latency, safe error, cache state, circuit state, time. System health reports actual DB readiness, latest import, and open reports. Empty data is shown as no observations, never fabricated green state.

Alert candidates: readiness failure, sustained 5xx rate/latency, provider failure rate/circuit open, repeated model validation/provider failures, validation-failed imports, missing backup success/checksum, retention-job failure, and migration/startup failure. Export these adapters to the selected production log/metrics/alert platform; the repository does not claim a hosted dashboard exists.
