#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec python3 "$repo_root/scripts/ci/check_github_actions_pinned.py" --root "$repo_root" "$@"
