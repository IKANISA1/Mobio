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

device="${DEVICE:-chrome}"
trace_output="${TRACE_OUTPUT:-build/perf/startup-${device}-$(date +%Y%m%d%H%M%S).binpb}"
dart_define_file="$(mktemp "${TMPDIR:-/tmp}/mobi-profile-dart-defines.XXXXXX.json")"
trap 'rm -f "${dart_define_file:-}"' EXIT

mkdir -p "$(dirname "$trace_output")"

python3 - <<'PY' "$dart_define_file"
import json
import os
import sys
from pathlib import Path

path = sys.argv[1]
required = (
    "SUPABASE_URL",
    "SUPABASE_ANON_KEY",
    "PRIVACY_POLICY_URL",
    "ACCOUNT_DELETION_URL",
)


def parse_dotenv(dotenv_path: Path) -> dict[str, str]:
    if not dotenv_path.exists():
        return {}
    values: dict[str, str] = {}
    for raw_line in dotenv_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        if line.startswith("export "):
            line = line[len("export "):].strip()
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip("'\"")
        if key:
            values[key] = value
    return values


dotenv = parse_dotenv(Path(".env"))
defines = {}
missing = []
for key in required:
    value = os.environ.get(key) or dotenv.get(key)
    if not value:
        missing.append(key)
    else:
        defines[key] = value

if missing:
    print(
        "Missing " + ", ".join(missing) + ". Add them to .env or export them before profiling.",
        file=sys.stderr,
    )
    raise SystemExit(1)

with open(path, "w", encoding="utf-8") as fh:
    json.dump(defines, fh)
PY

"$FLUTTER_BIN" run \
  -d "$device" \
  --profile \
  --trace-startup \
  --trace-to-file="$trace_output" \
  --dart-define-from-file="$dart_define_file"

test -s "$trace_output"
printf 'Wrote startup trace: %s\n' "$trace_output"
