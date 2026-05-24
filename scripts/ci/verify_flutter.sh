#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

default_flutter="/Volumes/PRO-G40/flutter_3_44/bin/flutter"
if [[ -z "${FLUTTER_BIN:-}" && -x "$default_flutter" ]]; then
  FLUTTER_BIN="$default_flutter"
else
  FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
fi

"$FLUTTER_BIN" pub get
"$FLUTTER_BIN" gen-l10n
"$FLUTTER_BIN" analyze --no-fatal-infos --no-fatal-warnings
"$FLUTTER_BIN" test --coverage
