#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

: "${CLOUDFLARE_PAGES_CLIENT_PROJECT_NAME:?Missing CLOUDFLARE_PAGES_CLIENT_PROJECT_NAME}"
: "${CLOUDFLARE_PAGES_ADMIN_PROJECT_NAME:?Missing CLOUDFLARE_PAGES_ADMIN_PROJECT_NAME}"

branch="${1:-main}"
output_root="${2:-build/pwa}"

"$repo_root/scripts/web/prepare_pwa_bundles.sh" "$output_root"

npx wrangler pages deploy "$output_root/client" \
  --project-name="$CLOUDFLARE_PAGES_CLIENT_PROJECT_NAME" \
  --branch="$branch"

npx wrangler pages deploy "$output_root/admin" \
  --project-name="$CLOUDFLARE_PAGES_ADMIN_PROJECT_NAME" \
  --branch="$branch"
