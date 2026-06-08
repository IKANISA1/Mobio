#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep (rg) is required" >&2
  exit 127
fi

forbidden_files=(
  "android/fastlane/play-store-service-account.json"
)

matches=0
for file in "${forbidden_files[@]}"; do
  if [[ -e "$ROOT_DIR/$file" ]]; then
    echo "$file"
    matches=1
  fi
done

patterns=(
  'sbp_[A-Za-z0-9_-]{20,}'
  'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
  '(SUPABASE_SERVICE_ROLE_KEY|SERVICE_ROLE_KEY|SUPABASE_DB_PASSWORD|OPENAI_API_KEY|GOOGLE_MAPS_API_KEY|GEMINI_API_KEY)=.+'
  '"private_key"[[:space:]]*:[[:space:]]*"-----BEGIN PRIVATE KEY-----'
  '"type"[[:space:]]*:[[:space:]]*"service_account"'
)

for pattern in "${patterns[@]}"; do
  if rg --hidden --files-with-matches \
    --glob '!.git/**' \
    --glob '!build/**' \
    --glob '!.dart_tool/**' \
    --glob '!node_modules/**' \
    --glob '!ios/Pods/**' \
    --glob '!android/.gradle/**' \
    --glob '!scripts/qa/scan_secrets.sh' \
    --glob '!docs/security/secret_rotation_runbook.md' \
    "$pattern" "$ROOT_DIR"; then
    matches=1
  fi
done

if [[ "$matches" -ne 0 ]]; then
  echo "secret-pattern scan found potential committed credentials" >&2
  exit 1
fi

echo "secret-pattern scan passed"
