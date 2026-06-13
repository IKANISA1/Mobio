#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

package_name="${ANDROID_PACKAGE_NAME:-rw.mobi.app}"
activity_name="${ANDROID_ACTIVITY_NAME:-rw.mobi.app/.MainActivity}"
evidence_dir="${ANDROID_UAT_EVIDENCE_DIR:-docs/release/evidence/device-uat-2026-06-12}"
step_name="${ANDROID_UAT_STEP:-manual-resume}"
wait_seconds="${ANDROID_UAT_WAIT_SECONDS:-6}"

if ! command -v adb >/dev/null 2>&1; then
  echo "adb is required for Android UAT capture." >&2
  exit 127
fi

if [[ -n "${ANDROID_SERIAL:-}" ]]; then
  device="$ANDROID_SERIAL"
else
  mapfile -t devices < <(adb devices | awk 'NR > 1 && $2 == "device" { print $1 }')
  if [[ "${#devices[@]}" -eq 0 ]]; then
    echo "No authorized Android device found. Connect a device and accept USB debugging." >&2
    adb devices >&2
    exit 1
  fi
  if [[ "${#devices[@]}" -gt 1 ]]; then
    echo "Multiple Android devices found. Set ANDROID_SERIAL to choose one." >&2
    adb devices >&2
    exit 1
  fi
  device="${devices[0]}"
fi

mkdir -p "$evidence_dir"

window_file="$evidence_dir/$step_name-window.txt"
summary_file="$evidence_dir/$step_name-summary.txt"
xml_file="$evidence_dir/$step_name.xml"
png_file="$evidence_dir/$step_name.png"
logcat_file="$evidence_dir/$step_name-logcat.txt"
package_file="$evidence_dir/$step_name-package.txt"

adb -s "$device" shell getprop ro.product.model | tr -d '\r' > "$evidence_dir/$step_name-device-model.txt"
adb -s "$device" shell getprop ro.build.version.release | tr -d '\r' > "$evidence_dir/$step_name-android-version.txt"
adb -s "$device" shell dumpsys package "$package_name" > "$package_file"

adb -s "$device" logcat -c || true
adb -s "$device" shell am start -n "$activity_name" >/dev/null
sleep "$wait_seconds"

adb -s "$device" shell dumpsys window > "$window_file"
adb -s "$device" exec-out screencap -p > "$png_file" || true
adb -s "$device" exec-out uiautomator dump /dev/tty > "$xml_file" || true
adb -s "$device" logcat -d > "$logcat_file" || true

helper="/Users/jeanbosco/.codex/plugins/cache/openai-curated/test-android-apps/c6ea566d/skills/android-emulator-qa/scripts/ui_tree_summarize.py"
if [[ -f "$helper" && -s "$xml_file" ]]; then
  python3 "$helper" "$xml_file" "$summary_file" || true
fi

if rg -q "mDreamingLockscreen=true|Enter your PIN|keyguard_pin_view" "$window_file" "$xml_file" 2>/dev/null; then
  echo "Android UAT capture stopped: device is locked. Evidence: $evidence_dir" >&2
  exit 2
fi

pid="$(adb -s "$device" shell pidof "$package_name" | tr -d '\r' || true)"
if [[ -z "$pid" ]]; then
  echo "Android UAT capture stopped: $package_name is not running. Evidence: $evidence_dir" >&2
  exit 3
fi

echo "Android UAT state captured. device=$device package=$package_name pid=$pid evidence=$evidence_dir"
