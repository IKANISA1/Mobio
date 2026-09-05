#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

source "$repo_root/scripts/lib/flutter.sh"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "The iOS release build requires macOS and Xcode." >&2
  exit 1
fi

build_temp="$(mktemp -d "${TMPDIR:-/tmp}/mobio-ios-build.XXXXXX")"
trap 'rm -rf "$build_temp"' EXIT
dart_define_file="$build_temp/runtime.json"
python3 scripts/lib/runtime_defines.py "$dart_define_file" --platform ios

# Run the existing release guards with only allowlisted client values from .env.
python3 - "$dart_define_file" <<'PY'
import json
import os
import subprocess
import sys
with open(sys.argv[1], encoding="utf-8") as stream:
    values = json.load(stream)
subprocess.run(["./scripts/ci/verify_release_config.sh"],
               env={**os.environ, **values}, check=True)
PY

# An Intel Flutter SDK can otherwise launch Intel Ruby against ARM-only gems.
# Keep this shim private to this build and retain the installed pod command.
pod_command="$(type -P pod || true)"
if [[ "$(/usr/sbin/sysctl -n hw.optional.arm64 2>/dev/null || true)" == "1" && -n "$pod_command" ]] &&
   /usr/bin/arch -arm64 "$pod_command" --version >/dev/null 2>&1; then
  mkdir "$build_temp/bin"
  python3 - "$build_temp/bin/pod" "$pod_command" <<'PY'
from pathlib import Path
import shlex
import sys
path = Path(sys.argv[1])
path.write_text('#!/bin/sh\nexec /usr/bin/arch -arm64 '
                + shlex.quote(str(Path(sys.argv[2]).resolve())) + ' "$@"\n')
path.chmod(0o700)
PY
  export PATH="$build_temp/bin:$PATH"
fi

./scripts/ci/bootstrap_flutter.sh

COCOAPODS_DISABLE_STATS=true "$FLUTTER_BIN" build ios --release --no-codesign \
  --dart-define-from-file="$dart_define_file"
