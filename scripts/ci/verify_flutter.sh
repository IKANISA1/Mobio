#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${MOBIO_CAPTURE_DIR:-}" ]]; then
  printf '%s\n' \
    "MOBIO_CAPTURE_DIR is for review image export only; it bypasses golden comparisons." \
    "Unset MOBIO_CAPTURE_DIR before running Flutter verification." >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

source "$repo_root/scripts/lib/flutter.sh"

./scripts/ci/bootstrap_flutter.sh
python3 scripts/ci/check_repository_structure.py
python3 scripts/ci/check_design_authority.py
python3 -m unittest discover -s scripts/tests -v
"$FLUTTER_BIN" analyze --no-pub
"$FLUTTER_BIN" test --coverage
