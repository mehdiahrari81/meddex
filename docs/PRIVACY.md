# Privacy and retention

Mobile sessions use platform secure storage. Prescription images use the private app directory, opaque names, conservative processing, optional retention, and stale temporary-file cleanup. Android backup is disabled. Logs redact security and medical keys; normal analytics is no-op unless explicitly replaced/consented and must never receive search/medicine/prescription/AI text.

Default policies: temporary scans 24 hours, AI conversations 30 days, exports 24 hours, provider cache 90 days after expiry, backup retention 30 days. Audit retention is an operator/legal policy and is not silently deleted. `ops/retention_cleanup.py` deletes only expired AI conversations and provider cache rows transactionally.

Account deletion uses database cascades for sessions, prescriptions, medication plans/history, saved records, reports as applicable, and AI conversations/messages. Mobile private images are local and removed by its local deletion/retention path. Governance/audit records use policy-driven actor nulling or controlled retention instead of exposing/deleting unrelated integrity history.
