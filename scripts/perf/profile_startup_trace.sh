#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

source "$repo_root/scripts/lib/flutter.sh"

device="${DEVICE:-chrome}"
trace_output="${TRACE_OUTPUT:-build/perf/startup-${device}-$(date +%Y%m%d%H%M%S).binpb}"
dart_define_file="$(mktemp "${TMPDIR:-/tmp}/mobi-profile-dart-defines.XXXXXX.json")"
trap 'rm -f "${dart_define_file:-}"' EXIT

mkdir -p "$(dirname "$trace_output")"

python3 "$repo_root/scripts/lib/runtime_defines.py" "$dart_define_file"

"$FLUTTER_BIN" run \
  -d "$device" \
  --profile \
  --trace-startup \
  --trace-to-file="$trace_output" \
  --dart-define-from-file="$dart_define_file"

test -s "$trace_output"
printf 'Wrote startup trace: %s\n' "$trace_output"
