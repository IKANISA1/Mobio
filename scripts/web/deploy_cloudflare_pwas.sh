#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

# Promotion consumes an unchanged prepared site. It never rebuilds, installs a
# deployment tool, or accepts a partial/optional gate set. All destination fields
# and evidence paths must be explicitly supplied; legacy positional calls fail.
exec python3 "$repo_root/scripts/web/pwa_candidate_manifest.py" --root "$repo_root" promote "$@"
