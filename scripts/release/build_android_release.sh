#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

default_flutter="/Volumes/PRO-G40/flutter_3_44/bin/flutter"
if [[ -z "${FLUTTER_BIN:-}" && -x "$default_flutter" ]]; then
  FLUTTER_BIN="$default_flutter"
else
  FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
fi

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

: "${SUPABASE_URL:?Missing SUPABASE_URL. Add it to .env or export it before building.}"
: "${SUPABASE_ANON_KEY:?Missing SUPABASE_ANON_KEY. Add it to .env or export it before building.}"
: "${PRIVACY_POLICY_URL:?Missing PRIVACY_POLICY_URL. Add it to .env or export it before building.}"
: "${ACCOUNT_DELETION_URL:?Missing ACCOUNT_DELETION_URL. Add it to .env or export it before building.}"

dart_define_file="$(mktemp "${TMPDIR:-/tmp}/mobi-dart-defines.XXXXXX.json")"
trap 'rm -f "${dart_define_file:-}"' EXIT

python3 - <<'PY' "$dart_define_file"
import json
import os
import sys

path = sys.argv[1]
defines = {
    "SUPABASE_URL": os.environ["SUPABASE_URL"],
    "SUPABASE_ANON_KEY": os.environ["SUPABASE_ANON_KEY"],
    "PRIVACY_POLICY_URL": os.environ["PRIVACY_POLICY_URL"],
    "ACCOUNT_DELETION_URL": os.environ["ACCOUNT_DELETION_URL"],
}
with open(path, "w", encoding="utf-8") as fh:
    json.dump(defines, fh)
PY

if [[ ! -f android/key.properties ]]; then
  echo "Missing android/key.properties. Copy android/key.properties.example and point it to the release keystore." >&2
  exit 1
fi

target="${1:-appbundle}"

case "$target" in
  appbundle)
    output="build/app/outputs/bundle/release/app-release.aab"
    rm -f "$output"
    "$FLUTTER_BIN" build appbundle --release \
      --dart-define-from-file="$dart_define_file"

    test -s "$output"

    echo
    echo "Built AAB: $output"
    ;;
  apk)
    output="build/app/outputs/flutter-apk/app-release.apk"
    rm -f "$output"
    "$FLUTTER_BIN" build apk --release \
      --dart-define-from-file="$dart_define_file"

    test -s "$output"

    echo
    echo "Built APK: $output"
    ;;
  *)
    echo "Usage: $0 [appbundle|apk]" >&2
    exit 1
    ;;
esac
