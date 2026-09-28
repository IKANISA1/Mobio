#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
APP_DIR="$ROOT_DIR/apps/momobio_sms_bridge"
ADB="${ADB:-adb}"
APKSIGNER="${APKSIGNER:-apksigner}"
SERIAL="${ANDROID_SERIAL:?Select the authorized institutional UAT device with ANDROID_SERIAL}"
EXPECTED="${COLLECTOR_EXPECTED_CERT_SHA256:?Set the approved release certificate SHA-256; never a private key}"
APK="$APP_DIR/app/build/outputs/apk/release/app-release.apk"
EVIDENCE_DIR="${1:-$ROOT_DIR/build/qa/momobio-sms-bridge/$(date -u +%Y%m%dT%H%M%SZ)}"
for tool in "$ADB" "$APKSIGNER" python3; do command -v "$tool" >/dev/null; done
mkdir -p "$EVIDENCE_DIR"
# Passwords are consumed by Gradle from environment, never echoed or passed on its command line.
"$ROOT_DIR/android/gradlew" -p "$APP_DIR" --no-daemon :app:assembleRelease > "$EVIDENCE_DIR/build.log" 2>&1
test -s "$APK"
"$APKSIGNER" verify --verbose --print-certs "$APK" > "$EVIDENCE_DIR/signature.txt" 2>&1
python3 "$APP_DIR/scripts/verify_release_certificate.py" "$EVIDENCE_DIR/signature.txt" "$EXPECTED"
# Updating with a different certificate MUST fail. Never uninstall or clear pending receipts to bypass this.
"$ADB" -s "$SERIAL" get-state
"$ADB" -s "$SERIAL" install -r "$APK" > "$EVIDENCE_DIR/install.txt" 2>&1
"$ADB" -s "$SERIAL" shell am start -n com.momobio.app/.MainActivity > "$EVIDENCE_DIR/launch.txt" 2>&1
"$ADB" -s "$SERIAL" shell dumpsys package com.momobio.app > "$EVIDENCE_DIR/package.txt"
# No SMS permission grants, force-stop, battery overrides, or enrollment mutations are automated here.
python3 - "$APK" "$EVIDENCE_DIR" <<'VERIFY'
import hashlib,json,sys
from pathlib import Path
apk=Path(sys.argv[1]); out=Path(sys.argv[2])
(out/'installation.json').write_text(json.dumps({'apk_sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),
  'certificate_verified':True,'installed_update':True,'functional_uat':'not_run',
  'production_ready':False},indent=2)+'\n')
VERIFY
printf '%s\n' 'INSTALLATION ONLY. Complete the receipt-collector device acceptance matrix; do not label empty queue as payment success.'
printf '%s\n' "$EVIDENCE_DIR"
