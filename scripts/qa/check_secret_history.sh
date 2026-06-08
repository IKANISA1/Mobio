#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required" >&2
  exit 127
fi

forbidden_paths=(
  "android/fastlane/play-store-service-account.json"
)

if [[ "$(git rev-parse --is-shallow-repository)" == "true" ]]; then
  cat >&2 <<'EOF'
Secret history check requires a full clone.

In GitHub Actions, use actions/checkout with fetch-depth: 0 before running this
gate. Locally, fetch full history before treating this check as production
evidence.
EOF
  exit 1
fi

matches=0

for path in "${forbidden_paths[@]}"; do
  history_matches="$(git log --all --full-history --format='%H %ad %s' --date=short -- "$path")"
  if [[ -n "$history_matches" ]]; then
    echo "Forbidden secret-bearing path is still present in git history: $path" >&2
    git log --all --full-history --format='  %h %ad %s' --date=short -- "$path" >&2
    matches=1
  fi
done

if [[ "$matches" -ne 0 ]]; then
  cat >&2 <<'EOF'
Secret history check failed.

Rotate/revoke the exposed credential first, then purge the path from history
with the documented git-filter-repo workflow before production release.
EOF
  exit 1
fi

echo "secret-history scan passed"
