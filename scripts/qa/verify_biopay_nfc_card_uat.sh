#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

package_name="${ANDROID_PACKAGE_NAME:-rw.mobi.app}"
apk_path="${NFC_UAT_APK:-build/app/outputs/flutter-apk/app-release.apk}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
evidence_dir="${NFC_UAT_EVIDENCE_DIR:-docs/release/evidence/biopay-nfc-card-uat-$timestamp}"
manual_seconds="${NFC_UAT_MANUAL_SECONDS:-0}"
require_manual="${NFC_UAT_REQUIRE_MANUAL:-0}"
test_receiver="${NFC_UAT_RECEIVER:-123456}"
test_type="${NFC_UAT_TYPE:-momo_pay_code}"

mkdir -p "$evidence_dir"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

select_device() {
  if [[ -n "${ANDROID_SERIAL:-}" ]]; then
    adb devices | awk -v serial="$ANDROID_SERIAL" '$1 == serial && $2 == "device" { found = 1 } END { exit found ? 0 : 1 }' ||
      fail "ANDROID_SERIAL is not an authorized attached device: $ANDROID_SERIAL"
    printf '%s\n' "$ANDROID_SERIAL"
    return
  fi

  local devices
  mapfile -t devices < <(adb devices | awk 'NR > 1 && $2 == "device" { print $1 }')
  if [[ "${#devices[@]}" -eq 0 ]]; then
    fail "No authorized Android device found"
  fi
  if [[ "${#devices[@]}" -gt 1 ]]; then
    fail "Multiple Android devices found; set ANDROID_SERIAL"
  fi
  printf '%s\n' "${devices[0]}"
}

capture_focus() {
  adb -s "$device" shell dumpsys window | rg -m1 'mCurrentFocus=' || true
}

require_cmd adb
require_cmd rg

device="$(select_device)"
summary_file="$evidence_dir/summary.md"
device_file="$evidence_dir/device.txt"
package_file="$evidence_dir/package.txt"
nfc_file="$evidence_dir/nfc.txt"
links_file="$evidence_dir/app-links.txt"
resolve_file="$evidence_dir/intent-resolution.txt"
payload_log="$evidence_dir/payload-launch-logcat.txt"
manual_log="$evidence_dir/manual-card-logcat.txt"
manual_window="$evidence_dir/manual-card-window.txt"
manual_screenshot="$evidence_dir/manual-card-screenshot.png"
manual_start_focus="$evidence_dir/manual-start-focus.txt"
manual_start_screenshot="$evidence_dir/manual-start-screenshot.png"

if [[ -f "$apk_path" ]]; then
  adb -s "$device" install -r "$apk_path" >"$evidence_dir/install.txt" 2>&1
fi

{
  echo "device=$device"
  adb -s "$device" shell getprop ro.product.manufacturer | tr -d '\r'
  adb -s "$device" shell getprop ro.product.model | tr -d '\r'
  adb -s "$device" shell getprop ro.build.version.release | tr -d '\r'
  adb -s "$device" shell getprop ro.build.version.sdk | tr -d '\r'
  echo
  adb -s "$device" shell pm list features | tr -d '\r' | rg 'android.hardware.nfc|android.hardware.camera' || true
} >"$device_file"

adb -s "$device" shell dumpsys package "$package_name" >"$package_file"
adb -s "$device" shell dumpsys nfc >"$nfc_file" || true
adb -s "$device" shell pm get-app-links "$package_name" >"$links_file" 2>&1 || true

if [[ "$test_type" == "momo_pay_code" ]]; then
  tel_payload="tel:*182*8*1*$test_receiver%23"
else
  tel_payload="tel:*182*1*1*$test_receiver%23"
fi
custom_payload="mobio://biopay/nfc?type=$test_type&receiver=$test_receiver"

{
  echo "== Tel USSD NFC payload resolution =="
  adb -s "$device" shell cmd package resolve-activity --brief \
    -a android.intent.action.DIAL \
    -d "$tel_payload" || true
  echo
  echo "== Legacy custom scheme NFC payload resolution =="
  adb -s "$device" shell cmd package resolve-activity --brief \
    -a android.intent.action.VIEW \
    -c android.intent.category.BROWSABLE \
    -c android.intent.category.DEFAULT \
    -d "$custom_payload" || true
} >"$resolve_file"

adb -s "$device" shell am force-stop "$package_name" >/dev/null 2>&1 || true
adb -s "$device" shell am force-stop com.google.android.dialer >/dev/null 2>&1 || true
adb -s "$device" logcat -c || true
adb -s "$device" shell am start -W \
  -a android.intent.action.DIAL \
  -d "$tel_payload" >"$evidence_dir/tel-payload-launch.txt" 2>&1 || true
sleep 5
capture_focus >"$evidence_dir/tel-payload-focus.txt"
adb -s "$device" logcat -d -t 300 >"$payload_log" || true

if [[ "$manual_seconds" =~ ^[0-9]+$ ]] && [[ "$manual_seconds" -gt 0 ]]; then
  adb -s "$device" shell am force-stop com.google.android.dialer >/dev/null 2>&1 || true
  adb -s "$device" shell monkey -p "$package_name" -c android.intent.category.LAUNCHER 1 \
    >"$evidence_dir/manual-start-launch.txt" 2>&1 || true
  sleep 3
  capture_focus >"$manual_start_focus"
  adb -s "$device" exec-out screencap -p >"$manual_start_screenshot" || true

  cat <<EOF
Manual NFC card UAT window: ${manual_seconds}s

On the device:
1. Open Mobio Profile > Write NFC Card.
2. Enter the receiver value to write.
3. Tap Write NFC and hold a writable NTAG card until the app verifies it.
4. Optionally tap Lock Card and hold the same verified card.
5. Tap the written card again and confirm the dialer opens the USSD handoff.

Capturing logcat, window state, and screenshot when the timer ends.
EOF
  adb -s "$device" logcat -c || true
  sleep "$manual_seconds"
  adb -s "$device" logcat -d -t 1200 >"$manual_log" || true
  adb -s "$device" shell dumpsys window >"$manual_window" || true
  adb -s "$device" exec-out screencap -p >"$manual_screenshot" || true
fi

failures=0
check() {
  local name="$1"
  local command="$2"
  if eval "$command"; then
    echo "- PASS: $name" >>"$summary_file.tmp"
  else
    failures=$((failures + 1))
    echo "- FAIL: $name" >>"$summary_file.tmp"
  fi
}

: >"$summary_file.tmp"
check "device exposes NFC feature" "rg -q 'android.hardware.nfc' '$device_file'"
check "device NFC service is on" "rg -q 'mState=on' '$nfc_file'"
check "installed package has NFC permission" "rg -q 'android.permission.NFC' '$package_file'"
check "installed package has NDEF_DISCOVERED filter" "rg -q 'android.nfc.action.NDEF_DISCOVERED' '$package_file'"
check "installed package has custom mobio scheme filter" "rg -q 'Scheme: \"mobio\"' '$package_file'"
check "tel USSD NFC payload resolves to phone dialer" "rg -q 'com\\.google\\.android\\.dialer|com\\.android\\.dialer|dialer' '$resolve_file'"
check "tel USSD NFC payload launches phone dialer" "rg -q 'com\\.google\\.android\\.dialer|com\\.android\\.dialer|dialer' '$evidence_dir/tel-payload-focus.txt'"
check "payload launch has no fatal app errors" "! rg -qi 'FATAL EXCEPTION|ANR|FlutterError' '$payload_log'"
if [[ "$manual_seconds" =~ ^[0-9]+$ ]] && [[ "$manual_seconds" -gt 0 ]] && [[ "$require_manual" == "1" ]]; then
  check "manual phase started from Mobio" "rg -q 'rw\\.mobi\\.app/.MainActivity' '$manual_start_focus'"
  check "manual NFC write reached a tag" "rg -q 'NFC write tag detected' '$manual_log'"
  check "manual NFC write verified" "rg -q 'NFC write verified' '$manual_log'"
  check "manual card tap launches dialer handoff" "rg -q 'com\\.google\\.android\\.dialer|com\\.android\\.dialer' '$manual_window'"
  check "manual phase has no fatal app errors" "! rg -qi 'FATAL EXCEPTION|ANR|FlutterError' '$manual_log'"
fi

{
  echo "# BioPay NFC Card UAT Evidence"
  echo
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Repository: $repo_root"
  echo "Device: $device"
  echo "Package: $package_name"
  if [[ -f "$apk_path" ]]; then
    echo "APK: $apk_path"
    echo "APK SHA-256: $(shasum -a 256 "$apk_path" | awk '{ print $1 }')"
  fi
  echo "Tel USSD payload: $tel_payload"
  if [[ "$manual_seconds" =~ ^[0-9]+$ ]] && [[ "$manual_seconds" -gt 0 ]]; then
    echo "Manual physical card required: $require_manual"
  fi
  echo
  echo "## Automated Checks"
  cat "$summary_file.tmp"
  echo
  echo "## Evidence Files"
  echo "- Device: $device_file"
  echo "- Package dump: $package_file"
  echo "- NFC service: $nfc_file"
  echo "- App links: $links_file"
  echo "- Intent resolution: $resolve_file"
  echo "- Payload launch logcat: $payload_log"
  echo "- Tel payload focus: $evidence_dir/tel-payload-focus.txt"
  if [[ "$manual_seconds" =~ ^[0-9]+$ ]] && [[ "$manual_seconds" -gt 0 ]]; then
    echo "- Manual start focus: $manual_start_focus"
    echo "- Manual start screenshot: $manual_start_screenshot"
    echo "- Manual NFC card logcat: $manual_log"
    echo "- Manual NFC card window: $manual_window"
    echo "- Manual NFC card screenshot: $manual_screenshot"
  else
    echo
    echo "Manual physical card write/read was not run. Set NFC_UAT_MANUAL_SECONDS to capture it."
  fi
} >"$summary_file"
rm -f "$summary_file.tmp"

echo "Evidence written: $summary_file"
if [[ "$failures" -ne 0 ]]; then
  echo "NO-GO: BioPay NFC card UAT has $failures automated failure(s)." >&2
  exit 1
fi

echo "PASS: BioPay NFC automated UAT checks passed."
