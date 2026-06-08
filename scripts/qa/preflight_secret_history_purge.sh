#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

for command_name in git git-filter-repo; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "$command_name is required before rewriting secret history." >&2
    exit 127
  fi
done

forbidden_path="android/fastlane/play-store-service-account.json"

if [[ "$(git rev-parse --is-shallow-repository)" == "true" ]]; then
  cat >&2 <<'EOF'
Secret history purge preflight requires a full clone.

Fetch full history first, then rerun this script before using git-filter-repo.
EOF
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  cat >&2 <<'EOF'
Secret history purge must run from a clean clone or clean working tree.

Commit, stash, or move current work before rewriting history. Do not run
git-filter-repo in a dirty shared working tree.
EOF
  exit 1
fi

if [[ -e "$forbidden_path" ]]; then
  echo "Forbidden credential file still exists in the working tree: $forbidden_path" >&2
  exit 1
fi

if ! git log --all --format='%H' -- "$forbidden_path" | grep -q .; then
  echo "No historical entries found for $forbidden_path."
  echo "Run scripts/qa/check_secret_history.sh for production evidence."
  exit 0
fi

cat <<EOF
Secret history purge preflight passed.

Required next command from a prepared clean clone:

  git filter-repo --path $forbidden_path --invert-paths

Then run:

  scripts/qa/check_secret_history.sh
  scripts/qa/scan_secrets.sh

Only push rewritten history after the exposed Play key has been revoked and all
collaborators are ready to rebase or reclone.
EOF
