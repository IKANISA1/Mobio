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

if [[ -z "${JAVA_HOME:-}" && -x /usr/libexec/java_home ]]; then
  java_17_home="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"
  if [[ -n "$java_17_home" ]]; then
    export JAVA_HOME="$java_17_home"
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
fi

if [[ "${MOBI_DISABLE_GRADLE_DAEMON:-true}" == "true" ]]; then
  export GRADLE_OPTS="-Dorg.gradle.daemon=false ${GRADLE_OPTS:-}"
fi

tmpdir="${TMPDIR:-/tmp}"
tmpdir="${tmpdir%/}"
dart_define_file="$(mktemp "$tmpdir/mobi-dart-defines.XXXXXX")"
trap 'rm -f "${dart_define_file:-}"' EXIT

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

if [[ ! -f android/key.properties ]]; then
  echo "Missing android/key.properties. Copy android/key.properties.example and point it to the release keystore." >&2
  exit 1
fi

target="${1:-appbundle}"
target_platform_args=()
if [[ -n "${ANDROID_TARGET_PLATFORMS:-}" ]]; then
  target_platform_args+=(--target-platform="$ANDROID_TARGET_PLATFORMS")
fi
gradle_property_args=()
if [[ -n "${ANDROID_RELEASE_SHRINK:-}" ]]; then
  gradle_property_args+=(--android-project-arg="mobi.release.shrink=$ANDROID_RELEASE_SHRINK")
fi

case "$target" in
  appbundle)
    output="build/app/outputs/bundle/release/app-release.aab"
    rm -f "$output"
    "$FLUTTER_BIN" build appbundle --release \
      "${target_platform_args[@]}" \
      "${gradle_property_args[@]}" \
      --dart-define-from-file="$dart_define_file"

    test -s "$output"

    echo
    echo "Built AAB: $output"
    ;;
  apk)
    output="build/app/outputs/flutter-apk/app-release.apk"
    gradle_output="build/app/outputs/apk/release/app-release.apk"
    rm -f "$output" "$gradle_output"
    "$FLUTTER_BIN" build apk --release \
      "${target_platform_args[@]}" \
      "${gradle_property_args[@]}" \
      --dart-define-from-file="$dart_define_file"

    if [[ ! -s "$output" && -s "$gradle_output" ]]; then
      mkdir -p "$(dirname "$output")"
      cp "$gradle_output" "$output"
    fi
    test -s "$output"

    echo
    echo "Built APK: $output"
    ;;
  *)
    echo "Usage: $0 [appbundle|apk]" >&2
    exit 1
    ;;
esac
