#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

: "${SUPABASE_URL:?Missing SUPABASE_URL. Add it to .env or export it before building.}"
: "${SUPABASE_ANON_KEY:?Missing SUPABASE_ANON_KEY. Add it to .env or export it before building.}"
: "${PRIVACY_POLICY_URL:?Missing PRIVACY_POLICY_URL. Add it to .env or export it before building.}"

if [[ ! -f android/key.properties ]]; then
  echo "Missing android/key.properties. Copy android/key.properties.example and point it to the release keystore." >&2
  exit 1
fi

target="${1:-appbundle}"

case "$target" in
  appbundle)
    flutter build appbundle --release \
      --dart-define=SUPABASE_URL="$SUPABASE_URL" \
      --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
      --dart-define=PRIVACY_POLICY_URL="$PRIVACY_POLICY_URL"

    echo
    echo "Built AAB: build/app/outputs/bundle/release/app-release.aab"
    ;;
  apk)
    flutter build apk --release \
      --dart-define=SUPABASE_URL="$SUPABASE_URL" \
      --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
      --dart-define=PRIVACY_POLICY_URL="$PRIVACY_POLICY_URL"

    echo
    echo "Built APK: build/app/outputs/flutter-apk/app-release.apk"
    ;;
  *)
    echo "Usage: $0 [appbundle|apk]" >&2
    exit 1
    ;;
esac
