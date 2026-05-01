#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKDIR="${SUPABASE_WORKDIR:-$ROOT_DIR}"
AUDIT_SQL="$ROOT_DIR/supabase/tests/storage_realtime_audit.sql"

if ! command -v supabase >/dev/null 2>&1; then
  echo "supabase CLI is required" >&2
  exit 127
fi

if [[ ! -f "$AUDIT_SQL" ]]; then
  echo "missing audit SQL: $AUDIT_SQL" >&2
  exit 1
fi

output="$(
  supabase --workdir "$WORKDIR" db query --linked --file "$AUDIT_SQL" --output table
)"

printf '%s\n' "$output"

if grep -q ' failure ' <<<"$output"; then
  echo "storage/realtime audit failed" >&2
  exit 1
fi
