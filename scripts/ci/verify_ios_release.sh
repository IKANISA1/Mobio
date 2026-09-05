#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

./scripts/ci/verify_release_config.sh

source "$repo_root/scripts/lib/flutter.sh"
./scripts/ci/bootstrap_flutter.sh

COCOAPODS_DISABLE_STATS=true "$FLUTTER_BIN" build ios --release --no-codesign \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=PRIVACY_POLICY_URL="$PRIVACY_POLICY_URL" \
  --dart-define=ACCOUNT_DELETION_URL="$ACCOUNT_DELETION_URL" \
  --dart-define=FIREBASE_IOS_APP_ID="$FIREBASE_IOS_APP_ID"
