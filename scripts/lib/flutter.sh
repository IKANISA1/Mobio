#!/usr/bin/env bash
# Source after setting repo_root. Keep Flutter and Dart on the same SDK.
mobio_local_flutter="/Volumes/PRO-G40/flutter_3_44/bin/flutter"
if [[ -z "${FLUTTER_BIN:-}" ]]; then
  if [[ -x "$mobio_local_flutter" ]]; then
    FLUTTER_BIN="$mobio_local_flutter"
  else
    FLUTTER_BIN="$(command -v flutter || true)"
  fi
fi
if [[ -z "$FLUTTER_BIN" ]] || ! command -v "$FLUTTER_BIN" >/dev/null 2>&1; then
  echo "Flutter is unavailable. Install the version in .flutter-version or set FLUTTER_BIN." >&2
  return 1
fi
FLUTTER_BIN="$(command -v "$FLUTTER_BIN")"
DART_BIN="$(dirname "$FLUTTER_BIN")/dart"
export FLUTTER_BIN DART_BIN
