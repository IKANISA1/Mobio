#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
APP_DIR="$ROOT_DIR/apps/momobio_sms_bridge"
ADB="${ADB:-/Volumes/PRO-G40/AppData/android/sdk/platform-tools/adb}"
APKSIGNER="${APKSIGNER:-/Volumes/PRO-G40/AppData/android/sdk/build-tools/36.1.0/apksigner}"
SERIAL="${ANDROID_SERIAL:-13111JEC215558}"
PKG="com.momobio.app"
UNSIGNED="$APP_DIR/app/build/outputs/apk/release/app-release-unsigned.apk"
SIGNED="$APP_DIR/app/build/outputs/apk/release/mo-mobio-sms-bridge-internal-release.apk"
EVIDENCE_DIR="${1:-$APP_DIR/qa/device-uat-$(date +%Y%m%d-%H%M%S)}"

mkdir -p "$EVIDENCE_DIR"

run() {
  echo "+ $*" | tee -a "$EVIDENCE_DIR/commands.log"
  "$@" 2>&1 | tee -a "$EVIDENCE_DIR/commands.log"
}

capture() {
  local name="$1"
  run "$ADB" -s "$SERIAL" shell screencap -p "/sdcard/$name.png"
  run "$ADB" -s "$SERIAL" pull "/sdcard/$name.png" "$EVIDENCE_DIR/$name.png"
}

dump_ui() {
  local remote="$1"
  local local="$2"
  local deadline=$((SECONDS + 20))
  while (( SECONDS < deadline )); do
    echo "+ $ADB -s $SERIAL shell uiautomator dump /sdcard/$remote" | tee -a "$EVIDENCE_DIR/commands.log"
    "$ADB" -s "$SERIAL" shell rm -f "/sdcard/$remote" >/dev/null 2>&1 || true
    "$ADB" -s "$SERIAL" shell uiautomator dump "/sdcard/$remote" 2>&1 | tee -a "$EVIDENCE_DIR/commands.log" || true
    if "$ADB" -s "$SERIAL" shell test -f "/sdcard/$remote"; then
      if run "$ADB" -s "$SERIAL" pull "/sdcard/$remote" "$EVIDENCE_DIR/$local"; then
        return 0
      fi
    else
      echo "uiautomator dump did not create /sdcard/$remote; retrying" | tee -a "$EVIDENCE_DIR/commands.log"
    fi
    sleep 2
  done
  return 1
}

wait_for_terminal_sync() {
  local remote="$1"
  local local="$2"
  local deadline=$((SECONDS + 120))
  while (( SECONDS < deadline )); do
    dump_ui "$remote" "$local"
    if grep -q 'text="Running"' "$EVIDENCE_DIR/$local" &&
      grep -q 'text="Queued: 0"' "$EVIDENCE_DIR/$local"; then
      return 0
    fi
    if grep -q 'text="Upload error"' "$EVIDENCE_DIR/$local"; then
      return 1
    fi
    sleep 5
  done
  return 1
}

run "$ADB" devices -l
run "$ADB" -s "$SERIAL" shell getprop ro.product.model
run "$ADB" -s "$SERIAL" shell getprop ro.build.version.release

run "$ROOT_DIR/android/gradlew" -p "$APP_DIR" :app:assembleRelease
cp "$UNSIGNED" "$SIGNED"
run "$APKSIGNER" sign \
  --ks "$HOME/.android/debug.keystore" \
  --ks-key-alias androiddebugkey \
  --ks-pass pass:android \
  --key-pass pass:android \
  "$SIGNED"
run "$APKSIGNER" verify --print-certs "$SIGNED"

run "$ADB" -s "$SERIAL" install -r "$SIGNED"
run "$ADB" -s "$SERIAL" shell pm clear "$PKG"
run "$ADB" -s "$SERIAL" shell pm grant "$PKG" android.permission.READ_SMS
run "$ADB" -s "$SERIAL" shell pm grant "$PKG" android.permission.RECEIVE_SMS
run "$ADB" -s "$SERIAL" shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS || true
run "$ADB" -s "$SERIAL" shell dumpsys deviceidle whitelist +"$PKG" || true
run "$ADB" -s "$SERIAL" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1
sleep 2

run "$ADB" -s "$SERIAL" shell pidof "$PKG"
run "$ADB" -s "$SERIAL" shell dumpsys package "$PKG"
run "$ADB" -s "$SERIAL" shell dumpsys activity services "$PKG"
run "$ADB" -s "$SERIAL" shell dumpsys jobscheduler
dump_ui "$PKG-uiautomator.xml" "uiautomator-initial.xml"
capture "momobio-sms-bridge-initial"

wait_for_terminal_sync "$PKG-uiautomator-auto-sync.xml" "uiautomator-after-auto-sync.xml"
capture "momobio-sms-bridge-after-auto-sync"

run "$ADB" -s "$SERIAL" shell pm revoke "$PKG" android.permission.READ_SMS
run "$ADB" -s "$SERIAL" shell pm revoke "$PKG" android.permission.RECEIVE_SMS
run "$ADB" -s "$SERIAL" shell am force-stop "$PKG"
run "$ADB" -s "$SERIAL" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1
sleep 2
dump_ui "$PKG-uiautomator-permission.xml" "uiautomator-permission-needed.xml"
capture "momobio-sms-bridge-permission-needed"

run "$ADB" -s "$SERIAL" shell pm grant "$PKG" android.permission.READ_SMS
run "$ADB" -s "$SERIAL" shell pm grant "$PKG" android.permission.RECEIVE_SMS
run "$ADB" -s "$SERIAL" shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS || true
run "$ADB" -s "$SERIAL" shell am force-stop "$PKG"
run "$ADB" -s "$SERIAL" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1
wait_for_terminal_sync "$PKG-uiautomator-final.xml" "uiautomator-final.xml"
capture "momobio-sms-bridge-final"
run "$ADB" -s "$SERIAL" shell input keyevent HOME
sleep 5
run "$ADB" -s "$SERIAL" shell pidof "$PKG"
run "$ADB" -s "$SERIAL" shell dumpsys activity services "$PKG"

cat > "$EVIDENCE_DIR/manifest.md" <<EOF
# Mo Mobio Device UAT

- Device serial: $SERIAL
- Package: $PKG
- APK: $SIGNED
- Initial screenshot: momobio-sms-bridge-initial.png
- Automatic sync screenshot: momobio-sms-bridge-after-auto-sync.png
- Permission screenshot: momobio-sms-bridge-permission-needed.png
- Final regrant screenshot: momobio-sms-bridge-final.png
- Commands: commands.log
- UI dumps: uiautomator-*.xml

EOF

echo "$EVIDENCE_DIR"
