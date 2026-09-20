#!/usr/bin/env bash
set -euo pipefail

# Cloudflare's Git builder needs the compiled Flutter shells as well as landing/.
# Keep the SDK pinned to the same reviewed revision used by local and GitHub CI.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"
flutter_version="$(tr -d '[:space:]' < .flutter-version)"
flutter_revision="e1fd963c6f6922bd32afde2e9698a363cd0406d2"
if [[ "$flutter_version" != "3.44.3" ]]; then
  echo "Update the Cloudflare SDK revision when changing .flutter-version." >&2
  exit 1
fi

if [[ -z "${FLUTTER_BIN:-}" ]]; then
  sdk_dir="${MOBIO_FLUTTER_CACHE_DIR:-$repo_root/.dart_tool/cloudflare-flutter}"
  if [[ ! -d "$sdk_dir/.git" ]]; then
    git clone --depth 1 --single-branch --branch "$flutter_version" \
      https://github.com/flutter/flutter.git "$sdk_dir"
  fi
  if [[ "$(git -C "$sdk_dir" rev-parse HEAD)" != "$flutter_revision" ]]; then
    echo "Cloudflare Flutter SDK does not match the reviewed revision." >&2
    exit 1
  fi
  export FLUTTER_BIN="$sdk_dir/bin/flutter"
fi

source "$repo_root/scripts/lib/flutter.sh"
export PATH="$(dirname "$FLUTTER_BIN"):$PATH"
# A fresh SDK emits bootstrap/download output before its first version result.
# Warm it before parsing machine JSON so clean Linux builders work as well.
"$FLUTTER_BIN" --version >/dev/null
"$FLUTTER_BIN" --version --machine | python3 -c \
  'import json,sys; v=json.load(sys.stdin); assert v["frameworkVersion"]=="3.44.3", "Unexpected Flutter SDK"'
"$repo_root/scripts/ci/bootstrap_flutter.sh"
"$repo_root/scripts/web/prepare_pwa_bundles.sh" "${1:-build/pwa}"
