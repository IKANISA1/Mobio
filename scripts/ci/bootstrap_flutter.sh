#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"
source "$repo_root/scripts/lib/flutter.sh"

# Generate shared model parts in their owning package, including on a clean clone.
(cd packages/shared-types && "$DART_BIN" pub get && "$DART_BIN" run build_runner build --delete-conflicting-outputs)
"$FLUTTER_BIN" pub get
"$FLUTTER_BIN" gen-l10n
