#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 path/to/mediexplain.dump.enc" >&2
  exit 2
fi
: "${MEDIEXPLAIN_RESTORE_DATABASE_URL:?Set a disposable MEDIEXPLAIN_RESTORE_DATABASE_URL}"
: "${MEDIEXPLAIN_BACKUP_ENCRYPTION_KEY_FILE:?Set MEDIEXPLAIN_BACKUP_ENCRYPTION_KEY_FILE}"

encrypted_file="$1"
case "$encrypted_file" in
  *.dump.enc) ;;
  *) echo "Refusing unexpected backup filename" >&2; exit 2 ;;
esac

plain_file="$(mktemp -t mediexplain-restore.XXXXXX.dump)"
trap 'rm -f "$plain_file"' EXIT
openssl enc -d -aes-256-cbc -pbkdf2 \
  -in "$encrypted_file" -out "$plain_file" \
  -pass "file:$MEDIEXPLAIN_BACKUP_ENCRYPTION_KEY_FILE"
pg_restore --exit-on-error --clean --if-exists --no-owner --no-acl \
  --dbname="$MEDIEXPLAIN_RESTORE_DATABASE_URL" "$plain_file"
psql "$MEDIEXPLAIN_RESTORE_DATABASE_URL" -v ON_ERROR_STOP=1 <<'SQL'
SELECT COUNT(*) AS alembic_version_count FROM alembic_version;
SELECT COUNT(*) AS user_count FROM users;
SELECT COUNT(*) AS medication_identity_count FROM medication_identities;
SELECT COUNT(*) AS governed_content_count FROM governed_content;
SQL

echo "Restore and critical-table verification completed."
