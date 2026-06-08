#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

failures=0
while IFS= read -r -d '' workflow; do
  line_number=0
  while IFS= read -r line; do
    line_number=$((line_number + 1))
    if [[ "$line" =~ ^[[:space:]-]*uses:[[:space:]]*([^[:space:]#]+) ]]; then
      action_ref="${BASH_REMATCH[1]}"
      if [[ ! "$action_ref" =~ @[0-9a-f]{40}$ ]]; then
        echo "Unpinned GitHub Action in ${workflow}:${line_number}: ${action_ref}" >&2
        failures=1
      fi
    fi
  done < "$workflow"
done < <(find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \) -print0)

if [[ "$failures" -ne 0 ]]; then
  echo "GitHub Actions must be pinned to immutable 40-character commit SHAs." >&2
  exit 1
fi

echo "github-actions pin check passed"
