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
require_var ACCOUNT_DELETION_URL

if [[ "${REQUIRE_SECRET_HISTORY_CLEAN:-false}" == "true" ]]; then
  scripts/qa/check_secret_history.sh
fi

if [[ "${REQUIRE_IOS_FIREBASE:-true}" == "true" ]]; then
  require_var FIREBASE_IOS_APP_ID
fi

if [[ "${REQUIRE_ANDROID_SIGNING:-false}" == "true" ]]; then
  require_var KEYSTORE_BASE64
  require_var KEY_ALIAS
  require_var KEY_PASSWORD
  require_var STORE_PASSWORD
fi

if [[ "${REQUIRE_PLAY_UPLOAD_CREDENTIAL:-false}" == "true" ]]; then
  require_var PLAY_STORE_SERVICE_ACCOUNT_JSON

  play_release_track="${PLAY_RELEASE_TRACK:-internal}"
  play_release_status="${PLAY_RELEASE_STATUS:-draft}"

  case "$play_release_track" in
    internal|alpha|beta|production) ;;
    *)
      echo "PLAY_RELEASE_TRACK must be one of: internal, alpha, beta, production" >&2
      exit 1
      ;;
  esac

  case "$play_release_status" in
    draft|completed|inProgress|halted) ;;
    *)
      echo "PLAY_RELEASE_STATUS must be one of: draft, completed, inProgress, halted" >&2
      exit 1
      ;;
  esac

  if [[ "$play_release_track" == "production" && "${PLAY_PRODUCTION_APPROVED:-false}" != "true" ]]; then
    echo "PLAY_PRODUCTION_APPROVED=true is required for production-track uploads." >&2
    exit 1
  fi

  python3 - <<'PY'
import json
import os
import sys

raw = os.environ.get("PLAY_STORE_SERVICE_ACCOUNT_JSON", "")
try:
    data = json.loads(raw)
except json.JSONDecodeError as exc:
    print(f"PLAY_STORE_SERVICE_ACCOUNT_JSON is not valid JSON: {exc}", file=sys.stderr)
    sys.exit(1)

checks = {
    "type": data.get("type") == "service_account",
    "client_email": isinstance(data.get("client_email"), str) and "@" in data["client_email"],
    "private_key": isinstance(data.get("private_key"), str)
    and data["private_key"].startswith("-----BEGIN PRIVATE KEY-----"),
    "token_uri": isinstance(data.get("token_uri"), str) and data["token_uri"].startswith("https://"),
}

missing = [name for name, ok in checks.items() if not ok]
if missing:
    print(
        "PLAY_STORE_SERVICE_ACCOUNT_JSON is missing or has invalid fields: "
        + ", ".join(missing),
        file=sys.stderr,
    )
    sys.exit(1)
PY
fi

if [[ "${REQUIRE_IOS_NATIVE:-true}" == "true" ]]; then
  require_file ios/Runner/Info.plist
  require_file ios/Runner/Runner.entitlements
  require_file ios/Runner.xcodeproj/project.pbxproj

  require_contains 'remote-notification' ios/Runner/Info.plist
  require_contains 'Runner/Runner.entitlements' ios/Runner.xcodeproj/project.pbxproj
  require_contains 'aps-environment' ios/Runner/Runner.entitlements
fi
