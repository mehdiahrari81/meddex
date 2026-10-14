#!/bin/sh
set -eu

: "${MEDIEXPLAIN_BACKUP_DATABASE_URL:?Set MEDIEXPLAIN_BACKUP_DATABASE_URL}"
: "${MEDIEXPLAIN_BACKUP_ENCRYPTION_KEY_FILE:?Set MEDIEXPLAIN_BACKUP_ENCRYPTION_KEY_FILE}"

backup_dir="${MEDIEXPLAIN_BACKUP_DIRECTORY:-./backups}"
retention_days="${MEDIEXPLAIN_BACKUP_RETENTION_DAYS:-30}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$backup_dir"
umask 077

plain_file="$backup_dir/mediexplain-$timestamp.dump"
encrypted_file="$plain_file.enc"
trap 'test ! -f "$plain_file" || rm -f "$plain_file"' EXIT

pg_dump --format=custom --no-owner --no-acl \
  --file="$plain_file" "$MEDIEXPLAIN_BACKUP_DATABASE_URL"
openssl enc -aes-256-cbc -salt -pbkdf2 \
  -in "$plain_file" -out "$encrypted_file" \
  -pass "file:$MEDIEXPLAIN_BACKUP_ENCRYPTION_KEY_FILE"
shasum -a 256 "$encrypted_file" > "$encrypted_file.sha256"
rm -f "$plain_file"
find "$backup_dir" -type f -name 'mediexplain-*.dump.enc*' \
  -mtime "+$retention_days" -delete

echo "Encrypted backup created: $encrypted_file"
