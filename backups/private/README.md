# Encrypted local project backup

`meddex-local-2026-10-22.tar.gz.fernet` contains:

- `services/api/.env`: the local API configuration, including private credentials.
- `database/meddex-postgres.dump`: a complete PostgreSQL custom-format dump of the
  `mediexplain` database from `meddex-postgres-1`.
- `manifest.json`: backup metadata and checksums.

The archive uses Fernet authenticated encryption from Python's `cryptography`
library. The recovery key is intentionally kept outside this repository. Its
original location on the source Mac is:

`~/Desktop/meddex-private-backup-2026-10-22.key`

Keep that key in a password manager or another private backup location. Anyone
with the key and archive can decrypt the credentials and database. Never commit
the key. Without it, this archive cannot be recovered.

## Restore the files

Use Python 3.12 or newer. From a clone of this repository:

```sh
python3 -m venv /tmp/meddex-private-restore
/tmp/meddex-private-restore/bin/python -m pip install cryptography
/tmp/meddex-private-restore/bin/python scripts/restore-private-backup.py \
  backups/private/meddex-local-2026-10-22.tar.gz.fernet \
  --key-file ~/Desktop/meddex-private-backup-2026-10-22.key \
  --output ~/Desktop/meddex-restored-private
```

The output directory must not already exist. Decryption authenticates the entire
archive before extracting any files. Copy the restored `.env` to `services/api/`
when ready to run the application.

## Restore the database

The dump was created with PostgreSQL 16. For a **fresh, empty** database, start
the PostgreSQL service, then restore the dump:

```sh
docker compose up -d postgres
docker compose exec -T postgres pg_isready -U mediexplain -d mediexplain
docker compose exec -T postgres pg_restore \
  --username=mediexplain --dbname=mediexplain --no-owner --no-acl --exit-on-error \
  < ~/Desktop/meddex-restored-private/database/meddex-postgres.dump
```

Wait until `pg_isready` reports that it is accepting connections. Restore before
starting the API or running migrations. Do not restore over an existing populated
database. This backup contains the project's PostgreSQL database, not unrelated
Docker projects, Docker images, model caches, or databases stored inside an
installed mobile app.
