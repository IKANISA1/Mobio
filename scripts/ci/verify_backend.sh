#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"
supabase_workdir="${SUPABASE_WORKDIR:-$repo_root}"
deno_lock="$repo_root/deno.lock"
deno_args=(--frozen --lock="$deno_lock")

if [[ ! -f "$deno_lock" ]]; then
  echo "Missing deno.lock. Run: deno cache --lock=deno.lock supabase/functions/*/index.ts scripts/admin/*.ts supabase/functions/*/*_test.ts" >&2
  exit 1
fi

if [[ -x "scripts/qa/scan_secrets.sh" ]]; then
  scripts/qa/scan_secrets.sh
else
  echo "Skipping secret scan: scripts/qa/scan_secrets.sh is not executable."
fi

shopt -s nullglob
function_entrypoints=(supabase/functions/*/index.ts)
for entrypoint in "${function_entrypoints[@]}"; do
  deno check "${deno_args[@]}" "$entrypoint"
done

admin_scripts=(scripts/admin/*.ts)
for script in "${admin_scripts[@]}"; do
  deno check "${deno_args[@]}" "$script"
done

if [[ -f "supabase/functions/biopay-api/index_test.ts" ]]; then
  deno test "${deno_args[@]}" --allow-env supabase/functions/biopay-api/index_test.ts
fi

if [[ -f "supabase/functions/biopay-face-provider/index_test.ts" ]]; then
  deno test "${deno_args[@]}" --allow-env supabase/functions/biopay-face-provider/index_test.ts
fi

if [[ -f "supabase/functions/_shared/otp-security_test.ts" ]]; then
  deno test "${deno_args[@]}" --allow-env supabase/functions/_shared/otp-security_test.ts
fi

if [[ -f "supabase/functions/_shared/phone_test.ts" ]]; then
  deno test "${deno_args[@]}" --allow-env supabase/functions/_shared/phone_test.ts
fi

if [[ -f "supabase/functions/_shared/whatsapp-cloud_test.ts" ]]; then
  deno test "${deno_args[@]}" --allow-env supabase/functions/_shared/whatsapp-cloud_test.ts
fi

if [[ -n "${SUPABASE_PROJECT_REF:-}" ]]; then
  mkdir -p "$supabase_workdir/supabase/.temp"
  printf '%s' "$SUPABASE_PROJECT_REF" > "$supabase_workdir/supabase/.temp/project-ref"
fi

has_linked_auth=false
if [[ -n "${SUPABASE_ACCESS_TOKEN:-}" || -n "${SUPABASE_DB_PASSWORD:-}" ]]; then
  has_linked_auth=true
fi

if [[ "$has_linked_auth" == "true" && -f "$supabase_workdir/supabase/.temp/project-ref" ]]; then
  supabase --workdir "$supabase_workdir" db lint --linked --schema public --fail-on error
  SUPABASE_WORKDIR="$supabase_workdir" scripts/qa/audit_storage_realtime.sh
  supabase --workdir "$supabase_workdir" db query \
    --linked \
    --file "$repo_root/supabase/tests/backend_security_assertions.sql" \
    --output table
else
  if [[ "${REQUIRE_LINKED_SUPABASE:-false}" == "true" ]]; then
    echo "Linked Supabase security gates are required but credentials were incomplete. Provide SUPABASE_PROJECT_REF plus SUPABASE_ACCESS_TOKEN or SUPABASE_DB_PASSWORD." >&2
    exit 1
  fi
  echo "Skipping linked Supabase security gates: provide SUPABASE_PROJECT_REF plus SUPABASE_ACCESS_TOKEN or SUPABASE_DB_PASSWORD."
fi
