#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

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
  mkdir -p supabase/.temp
  printf '%s' "$SUPABASE_PROJECT_REF" > supabase/.temp/project-ref
fi

if [[ -n "${SUPABASE_ACCESS_TOKEN:-}" && -f "supabase/.temp/project-ref" ]]; then
  supabase db lint --linked --fail-on error
else
  echo "Skipping linked Supabase lint: SUPABASE_ACCESS_TOKEN and SUPABASE_PROJECT_REF were not both provided."
fi
