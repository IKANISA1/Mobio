#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

flutter pub get
flutter gen-l10n
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test --coverage
