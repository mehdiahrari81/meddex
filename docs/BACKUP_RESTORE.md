# Backup and restore

Target RPO is 24 hours and target RTO is 4 hours for the initial deployment. Schedule `ops/backup_postgres.sh` at least daily under a dedicated least-privilege operator identity. It creates a PostgreSQL custom-format dump, encrypts it with AES-256-CBC/PBKDF2 using an external key file, creates SHA-256 evidence, applies configurable 30-day retention, and uses restrictive file permissions. Production should upload encrypted artifacts/checksums to access-controlled immutable storage and alert on missed execution.

Restore only to a new/disposable database: verify checksum, set a distinct `MEDIEXPLAIN_RESTORE_DATABASE_URL`, and run `ops/restore_postgres.sh`. It decrypts to a secure temporary file, invokes `pg_restore --exit-on-error --clean --if-exists`, and checks Alembic/users/medication identity/governed-content tables. Never test restore against production.

On August 13, 2026 an actual local PostgreSQL 16 drill migrated a fresh source through all five Alembic revisions, inserted linked user/profile, verified medication identity, and governed content fixtures, encrypted a dump, restored to a distinct database, and verified Alembic plus each critical record. Both temporary databases and backup/key files were then removed. This proves the repository procedure locally, not the reliability of future production storage/scheduling.
