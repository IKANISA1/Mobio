#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

source "$repo_root/scripts/lib/flutter.sh"

target_platform="${TARGET_PLATFORM:-android-arm64}"
timestamp="$(date +%Y%m%d%H%M%S)"
output_dir="${SIZE_OUTPUT_DIR:-build/size/${target_platform}/${timestamp}}"
dart_define_file="$(mktemp "${TMPDIR:-/tmp}/mobi-size-dart-defines.XXXXXX.json")"
before_marker="$(mktemp "${TMPDIR:-/tmp}/mobi-size-before.XXXXXX")"
trap 'rm -f "${dart_define_file:-}" "${before_marker:-}"' EXIT

mkdir -p "$output_dir"
touch "$before_marker"

python3 "$repo_root/scripts/lib/runtime_defines.py" "$dart_define_file"

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
