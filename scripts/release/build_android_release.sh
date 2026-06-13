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

java_major_version() {
  java -version 2>&1 |
    awk -F '"' '/version/ {
      split($2, parts, ".")
      if (parts[1] == "1") {
        print parts[2]
      } else {
        print parts[1]
      }
      exit
    }'
}

select_java_17() {
  if [[ -x /usr/libexec/java_home ]]; then
    /usr/libexec/java_home -v 17 2>/dev/null | tail -n 1
  fi
}

java_17_home=""
current_java_major="$(java_major_version || true)"
if [[ -z "${JAVA_HOME:-}" || -z "$current_java_major" || "$current_java_major" -gt 21 ]]; then
  java_17_home="$(select_java_17 || true)"
fi
if [[ -n "$java_17_home" ]]; then
  export JAVA_HOME="$java_17_home"
  export PATH="$JAVA_HOME/bin:$PATH"
  current_java_major="$(java_major_version || true)"
fi
if [[ -z "$current_java_major" || "$current_java_major" -gt 21 ]]; then
  echo "Android release builds require Java 17-21. Current Java is:" >&2
  java -version >&2
  echo "Install Java 17 or set JAVA_HOME to a supported JDK." >&2
  exit 1
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
version_args=()
if [[ -n "${ANDROID_BUILD_NAME:-}" ]]; then
  version_args+=(--build-name="$ANDROID_BUILD_NAME")
fi
if [[ -n "${ANDROID_BUILD_NUMBER:-}" ]]; then
  version_args+=(--build-number="$ANDROID_BUILD_NUMBER")
fi
gradle_property_args=()
if [[ -n "${ANDROID_RELEASE_SHRINK:-}" ]]; then
  gradle_property_args+=(--android-project-arg="mobi.release.shrink=$ANDROID_RELEASE_SHRINK")
fi

case "$target" in
  appbundle)
    output="build/app/outputs/bundle/release/app-release.aab"
    rm -f "$output"
    build_cmd=("$FLUTTER_BIN" build appbundle --release --no-pub)
    if ((${#target_platform_args[@]})); then
      build_cmd+=("${target_platform_args[@]}")
    fi
    if ((${#version_args[@]})); then
      build_cmd+=("${version_args[@]}")
    fi
    if ((${#gradle_property_args[@]})); then
      build_cmd+=("${gradle_property_args[@]}")
    fi
    build_cmd+=(--dart-define-from-file="$dart_define_file")
    "${build_cmd[@]}"

    test -s "$output"

    echo
    echo "Built AAB: $output"
    ;;
  apk)
    output="build/app/outputs/flutter-apk/app-release.apk"
    gradle_output="build/app/outputs/apk/release/app-release.apk"
    rm -f "$output" "$gradle_output"
    build_cmd=("$FLUTTER_BIN" build apk --release --no-pub)
    if ((${#target_platform_args[@]})); then
      build_cmd+=("${target_platform_args[@]}")
    fi
    if ((${#version_args[@]})); then
      build_cmd+=("${version_args[@]}")
    fi
    if ((${#gradle_property_args[@]})); then
      build_cmd+=("${gradle_property_args[@]}")
    fi
    build_cmd+=(--dart-define-from-file="$dart_define_file")
    "${build_cmd[@]}"

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
