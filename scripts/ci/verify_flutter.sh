#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

source "$repo_root/scripts/lib/flutter.sh"

./scripts/ci/bootstrap_flutter.sh
python3 scripts/ci/check_repository_structure.py
python3 scripts/ci/check_design_authority.py
python3 -m unittest discover -s scripts/tests -v
"$FLUTTER_BIN" analyze --no-pub
python3 scripts/qa/run_flutter_tests.py --flutter-bin "$FLUTTER_BIN" \
  --source-result build/qa/flutter-test-source.json -- --coverage
