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

target_platform="${TARGET_PLATFORM:-android-arm64}"
timestamp="$(date +%Y%m%d%H%M%S)"
output_dir="${SIZE_OUTPUT_DIR:-build/size/${target_platform}/${timestamp}}"
dart_define_file="$(mktemp "${TMPDIR:-/tmp}/mobi-size-dart-defines.XXXXXX.json")"
before_marker="$(mktemp "${TMPDIR:-/tmp}/mobi-size-before.XXXXXX")"
trap 'rm -f "${dart_define_file:-}" "${before_marker:-}"' EXIT

mkdir -p "$output_dir"
touch "$before_marker"

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
        "Missing " + ", ".join(missing) + ". Add them to .env or export them before building.",
        file=sys.stderr,
    )
    raise SystemExit(1)

with open(path, "w", encoding="utf-8") as fh:
    json.dump(defines, fh)
PY

export GRADLE_OPTS="-Dorg.gradle.daemon=false ${GRADLE_OPTS:-}"

"$FLUTTER_BIN" build apk \
  --release \
  --target-platform "$target_platform" \
  --analyze-size \
  --code-size-directory "$output_dir" \
  --dart-define-from-file "$dart_define_file"

latest_size_json="$(find "$HOME/.flutter-devtools" -name 'apk-code-size-analysis_*.json' -newer "$before_marker" -type f -print | sort | tail -1)"
if [[ -z "$latest_size_json" ]]; then
  echo "Flutter did not write an apk-code-size-analysis JSON under ~/.flutter-devtools" >&2
  exit 1
fi

cp "$latest_size_json" "$output_dir/apk-code-size-analysis.json"
stat -f '%Sm %z bytes %N' "$output_dir/apk-code-size-analysis.json"
stat -f '%Sm %z bytes %N' build/app/outputs/flutter-apk/app-release.apk
