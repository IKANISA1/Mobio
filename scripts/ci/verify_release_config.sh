#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: $name" >&2
    exit 1
  fi
}

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Missing required file: $path" >&2
    exit 1
  fi
}

require_contains() {
  local pattern="$1"
  local path="$2"
  if ! grep -q "$pattern" "$path"; then
    echo "Expected '$pattern' in $path" >&2
    exit 1
  fi
}

require_var SUPABASE_URL
require_var SUPABASE_ANON_KEY
require_var PRIVACY_POLICY_URL

if [[ "${REQUIRE_IOS_FIREBASE:-true}" == "true" ]]; then
  require_var FIREBASE_IOS_APP_ID
fi

if [[ "${REQUIRE_ANDROID_SIGNING:-false}" == "true" ]]; then
  require_var KEYSTORE_BASE64
  require_var KEY_ALIAS
  require_var KEY_PASSWORD
  require_var STORE_PASSWORD
  require_var PLAY_STORE_SERVICE_ACCOUNT_JSON
fi

require_file ios/Runner/Info.plist
require_file ios/Runner/Runner.entitlements
require_file ios/Runner.xcodeproj/project.pbxproj

require_contains 'remote-notification' ios/Runner/Info.plist
require_contains 'Runner/Runner.entitlements' ios/Runner.xcodeproj/project.pbxproj
require_contains 'aps-environment' ios/Runner/Runner.entitlements
