#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"
supabase_workdir="${SUPABASE_WORKDIR:-$repo_root}"

if [[ -x "scripts/qa/scan_secrets.sh" ]]; then
  scripts/qa/scan_secrets.sh
else
  echo "Skipping secret scan: scripts/qa/scan_secrets.sh is not executable."
fi

shopt -s nullglob
function_entrypoints=(supabase/functions/*/index.ts)
for entrypoint in "${function_entrypoints[@]}"; do
  deno check "$entrypoint"
done

admin_scripts=(scripts/admin/*.ts)
for script in "${admin_scripts[@]}"; do
  deno check "$script"
done

if [[ -f "supabase/functions/biopay-api/index_test.ts" ]]; then
  deno test --allow-env supabase/functions/biopay-api/index_test.ts
fi

if [[ -n "${SUPABASE_ACCESS_TOKEN:-}" && -n "${SUPABASE_PROJECT_REF:-}" ]]; then
  mkdir -p "$supabase_workdir/supabase/.temp"
  printf '%s' "$SUPABASE_PROJECT_REF" > "$supabase_workdir/supabase/.temp/project-ref"
fi

if [[ -n "${SUPABASE_ACCESS_TOKEN:-}" && -f "$supabase_workdir/supabase/.temp/project-ref" ]]; then
  supabase --workdir "$supabase_workdir" db lint --linked --schema public --fail-on error
  SUPABASE_WORKDIR="$supabase_workdir" scripts/qa/audit_storage_realtime.sh
  supabase --workdir "$supabase_workdir" db query \
    --linked \
    --file "$repo_root/supabase/tests/backend_security_assertions.sql" \
    --output table
else
  echo "Skipping linked Supabase security gates: SUPABASE_ACCESS_TOKEN and SUPABASE_PROJECT_REF were not both provided."
fi
