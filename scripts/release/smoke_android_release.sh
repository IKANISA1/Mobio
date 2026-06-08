#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

package_name="${ANDROID_PACKAGE_NAME:-rw.mobi.app}"
apk_path="${ANDROID_RELEASE_APK:-build/app/outputs/flutter-apk/app-release.apk}"
evidence_dir="${ANDROID_SMOKE_EVIDENCE_DIR:-build/reports/android-smoke}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
evidence_file="$evidence_dir/smoke-$timestamp.log"
generated_signing_files=false

cleanup_generated_signing_files() {
  if [[ "$generated_signing_files" == "true" ]]; then
    rm -f android/key.properties android/app/release.keystore
  fi
}

trap cleanup_generated_signing_files EXIT

if ! command -v adb >/dev/null 2>&1; then
  echo "adb is required for Android release smoke." >&2
  exit 127
fi

if [[ -n "${ANDROID_SERIAL:-}" ]]; then
  if ! adb devices | awk -v serial="$ANDROID_SERIAL" '$1 == serial && $2 == "device" { found = 1 } END { exit found ? 0 : 1 }'; then
    echo "ANDROID_SERIAL is set but is not an authorized attached device: $ANDROID_SERIAL" >&2
    adb devices >&2
    exit 1
  fi
  device="$ANDROID_SERIAL"
else
  devices=()
  while IFS= read -r device_id; do
    devices+=("$device_id")
  done < <(adb devices | awk 'NR > 1 && $2 == "device" { print $1 }')

  if [[ "${#devices[@]}" -eq 0 ]]; then
    echo "No authorized Android device found. Connect one device and accept the USB debugging prompt." >&2
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

if [[ ! -f "$apk_path" ]]; then
  echo "Release APK not found at $apk_path; building it first."
  if [[ ! -f android/key.properties ]]; then
    if [[ -n "${KEYSTORE_BASE64:-}" &&
      -n "${KEY_ALIAS:-}" &&
      -n "${KEY_PASSWORD:-}" &&
      -n "${STORE_PASSWORD:-}" ]]; then
      echo "Writing temporary Android signing files from environment secrets."
      PRESERVE_ANDROID_SIGNING_FILES=true ./scripts/ci/write_android_signing_files.sh
      generated_signing_files=true
    fi
  fi
  ./scripts/release/build_android_release.sh apk
fi

apksigner="${APKSIGNER:-}"
if [[ -z "$apksigner" ]]; then
  for sdk_root in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Library/Android/sdk"; do
    if [[ -n "$sdk_root" && -d "$sdk_root/build-tools" ]]; then
      apksigner="$(find "$sdk_root/build-tools" -name apksigner -type f | sort | tail -1)"
    fi
  done
fi

if [[ -z "$apksigner" || ! -x "$apksigner" ]]; then
  echo "apksigner is required to verify the release APK before smoke." >&2
  exit 127
fi

mkdir -p "$evidence_dir"

{
  echo "Mobio Android release smoke"
  echo "timestamp=$timestamp"
  echo "device=$device"
  echo "package=$package_name"
  echo "apk=$apk_path"
  echo "apk_sha256=$(shasum -a 256 "$apk_path" | awk '{ print $1 }')"
  echo
  echo "== apk signature =="
  "$apksigner" verify --verbose --print-certs "$apk_path" 2>&1
  echo
  echo "== device properties =="
  adb -s "$device" shell getprop ro.product.manufacturer | tr -d '\r'
  adb -s "$device" shell getprop ro.product.model | tr -d '\r'
  adb -s "$device" shell getprop ro.build.version.release | tr -d '\r'
  adb -s "$device" shell getprop ro.build.version.sdk | tr -d '\r'
} > "$evidence_file"

echo "Installing $apk_path on $device..."
adb -s "$device" install -r "$apk_path" >> "$evidence_file" 2>&1

echo "Launching $package_name..."
adb -s "$device" shell monkey -p "$package_name" -c android.intent.category.LAUNCHER 1 >> "$evidence_file" 2>&1
sleep "${ANDROID_SMOKE_WAIT_SECONDS:-8}"

pid="$(adb -s "$device" shell pidof "$package_name" | tr -d '\r' || true)"
if [[ -z "$pid" ]]; then
  {
    echo
    echo "== recent logcat =="
    adb -s "$device" logcat -d -t 200
  } >> "$evidence_file" 2>&1
  echo "Mobio did not stay running after launch. Evidence: $evidence_file" >&2
  exit 1
fi

{
  echo
  echo "pid=$pid"
  echo
  echo "== recent logcat =="
  adb -s "$device" logcat -d -t 200
} >> "$evidence_file" 2>&1

echo "Android release smoke passed. Evidence: $evidence_file"
