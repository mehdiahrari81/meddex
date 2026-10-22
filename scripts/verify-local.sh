#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
browser=false
android=false
for option in "$@"; do
  case "$option" in
    --browser) browser=true ;;
    --android) android=true ;;
    *) printf 'Unknown option: %s (supported: --browser --android)\n' "$option" >&2; exit 2 ;;
  esac
done

python3 -m unittest discover -s "$project_root/scripts/tests" -v

(
  cd "$project_root/services/api"
  if [[ ! -x .venv/bin/python ]]; then
    printf 'Install API dependencies first: cd services/api && uv sync --group dev --locked\n' >&2
    exit 1
  fi
  .venv/bin/ruff format --check app tests alembic scripts
  .venv/bin/ruff check app tests alembic scripts
  .venv/bin/mypy app
  .venv/bin/python -m pytest -q
  migration_directory="$(mktemp -d)"
  trap 'rm -rf "$migration_directory"' EXIT
  export MEDIEXPLAIN_DATABASE_URL="sqlite+pysqlite:///$migration_directory/verification.db"
  .venv/bin/alembic upgrade head
  .venv/bin/alembic check
)
(
  cd "$project_root/apps/mobile"
  dart format --output=none --set-exit-if-changed lib test
  flutter analyze --no-pub
  flutter test --no-pub
  if "$android"; then
    flutter build apk --debug --no-pub
    python3 "$project_root/scripts/check-android-apk.py" build/app/outputs/flutter-apk/app-debug.apk
  fi
)
if [[ -f "$project_root/apps/admin/package.json" ]]; then
(
  cd "$project_root/apps/admin"
  npm run lint
  npm run typecheck
  npm test
  npm run build
  if "$browser"; then npx playwright test; fi
)
else
  printf "Admin source absent in this checkout; admin checks skipped.\n"
fi
