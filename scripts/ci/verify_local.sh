#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

builds=false
case "${1:-}" in
  "") ;;
  --builds) builds=true ;;
  -h|--help)
    echo "Usage: scripts/ci/verify_local.sh [--builds]"
    echo "Run local Flutter/backend checks; --builds also packages Android, iOS, and website/admin."
    exit 0 ;;
  *) echo "Unknown option: $1" >&2; exit 2 ;;
esac
if (( $# > 1 )); then
  echo "Only one option is supported." >&2
  exit 2
fi

if ! command -v deno >/dev/null 2>&1; then
  echo "Deno is required for local backend verification. Add it to PATH before running." >&2
  exit 1
fi
if [[ "$builds" == "true" && "$(uname -s)" != "Darwin" ]]; then
  echo "--builds includes iOS and requires macOS/Xcode; use individual build scripts on other hosts." >&2
  exit 1
fi

./scripts/ci/verify_flutter.sh
# This command never uses linked database credentials or changes remote services.
env -u SUPABASE_ACCESS_TOKEN -u SUPABASE_DB_PASSWORD -u SUPABASE_PROJECT_REF \
  -u SUPABASE_WORKDIR REQUIRE_LINKED_SUPABASE=false ./scripts/ci/verify_backend.sh

if [[ "$builds" == "true" ]]; then
  ./scripts/web/prepare_pwa_bundles.sh
  ./scripts/web/verify_pwa_bundles.sh
  ./scripts/release/build_android_release.sh appbundle
  ./scripts/release/build_android_release.sh apk
  ./scripts/ci/verify_ios_release.sh
fi

echo "Local verification passed. No deployment or store upload was performed."
