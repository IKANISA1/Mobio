#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

failures=0
warnings=0
checked=0
evidence_dir="${BIOPAY_EVIDENCE_DIR:-docs/release/evidence}"
evidence_file="${BIOPAY_EVIDENCE_FILE:-$evidence_dir/biopay-live-readiness-$(date +%F).md}"
require_aws_live="${REQUIRE_BIOPAY_AWS_LIVE:-false}"
require_supabase_live="${REQUIRE_BIOPAY_SUPABASE_LIVE:-false}"
require_device_live="${REQUIRE_BIOPAY_DEVICE_LIVE:-false}"
require_live="${REQUIRE_BIOPAY_LIVE:-false}"
package_name="${ANDROID_PACKAGE_NAME:-rw.mobi.app}"

mkdir -p "$evidence_dir"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

if [[ "$require_live" == "true" ]]; then
  require_aws_live=true
  require_supabase_live=true
  require_device_live=true
fi

status_lines=()

record() {
  local status="$1"
  local name="$2"
  local detail="$3"
  checked=$((checked + 1))
  status_lines+=("- $status: $name - $detail")
  case "$status" in
    PASS) echo "PASS: $name - $detail" ;;
    WARN)
      warnings=$((warnings + 1))
      echo "WARN: $name - $detail" >&2
      ;;
    FAIL)
      failures=$((failures + 1))
      echo "FAIL: $name - $detail" >&2
      ;;
    *) echo "$status: $name - $detail" ;;
  esac
}

contains_file() {
  local file="$1"
  local pattern="$2"
  [[ -f "$file" ]] && rg -q --fixed-strings "$pattern" "$file"
}

not_contains_file() {
  local file="$1"
  local pattern="$2"
  [[ -f "$file" ]] && ! rg -q --fixed-strings "$pattern" "$file"
}

require_static_contains() {
  local name="$1"
  local file="$2"
  local pattern="$3"
  if contains_file "$file" "$pattern"; then
    record PASS "$name" "$file contains '$pattern'"
  else
    record FAIL "$name" "$file must contain '$pattern'"
  fi
}

require_static_absent() {
  local name="$1"
  local file="$2"
  local pattern="$3"
  if not_contains_file "$file" "$pattern"; then
    record PASS "$name" "$file does not contain '$pattern'"
  else
    record FAIL "$name" "$file must not contain '$pattern'"
  fi
}

require_env() {
  local name="$1"
  if [[ -n "${!name:-}" ]]; then
    record PASS "env $name" "present"
  else
    record FAIL "env $name" "missing"
  fi
}

biopay_health_url() {
  if [[ -n "${BIOPAY_FACE_HEALTH_URL:-}" ]]; then
    printf '%s\n' "$BIOPAY_FACE_HEALTH_URL"
  elif [[ -n "${SUPABASE_URL:-}" ]]; then
    printf '%s/functions/v1/biopay-face-provider/health\n' "${SUPABASE_URL%/}"
  fi
}

prove_live_biopay_health() {
  local name="$1"
  local health_url
  health_url="$(biopay_health_url)"
  # The deployed health payload proves FACE_PROVIDER=aws_rekognition and
  # AWS_REKOGNITION_COLLECTION_ID without exposing local AWS credentials.
  require_env SUPABASE_ANON_KEY
  if [[ -z "$health_url" ]]; then
    record FAIL "$name" "BIOPAY_FACE_HEALTH_URL or SUPABASE_URL is required"
    return
  fi
  if [[ -z "${SUPABASE_ANON_KEY:-}" ]]; then
    return
  fi

  local health_body
  local health_code
  health_body="$(mktemp)"
  health_code="$(
    curl -sS \
      -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
      -H "apikey: $SUPABASE_ANON_KEY" \
      -o "$health_body" \
      -w "%{http_code}" \
      "$health_url" || true
  )"
  if [[ "$health_code" == "200" ]] &&
    rg -q '"provider"[[:space:]]*:[[:space:]]*"aws_rekognition"' "$health_body" &&
    rg -q '"production_ready"[[:space:]]*:[[:space:]]*true' "$health_body" &&
    rg -q '"provider_collection_id"[[:space:]]*:[[:space:]]*"[^"]+"' "$health_body" &&
    rg -q '"payment_boundary"' "$health_body"; then
    record PASS "$name" "HTTP 200 FACE_PROVIDER=aws_rekognition health at $health_url"
  else
    record FAIL "$name" "HTTP $health_code did not prove AWS provider health at $health_url"
  fi
  rm -f "$health_body"
}

section() {
  echo
  echo "== $1 =="
}

section "Static BioPay restoration boundary"
require_static_contains "BioPay route" "lib/core/router/app_router.dart" "path: '/biopay'"
require_static_contains "BioPay QR route" "lib/core/router/app_router.dart" "path: '/biopay/qr'"
require_static_contains "BioPay face scan route" "lib/core/router/app_router.dart" "path: '/biopay/face-scan'"
require_static_contains "BioPay enrollment route" "lib/core/router/app_router.dart" "path: '/biopay/enroll'"
require_static_contains "BioPay NFC route" "lib/core/router/app_router.dart" "path: '/biopay/nfc'"
require_static_absent "No public BioPay activity route" "lib/core/router/app_router.dart" "path: '/biopay/activity'"
require_static_contains "Admin BioPay route" "lib/core/router/app_router.dart" "path: '/admin/finance'"
require_static_contains "Profile BioPay enrollment entry" "lib/features/profile/profile_screen.dart" "BioPay Face"
require_static_contains "Profile routes to enrollment" "lib/core/router/screen_wrappers.dart" "context.push('/biopay/enroll')"

section "USSD-only payment boundary"
require_static_contains "USSD dialer handoff" "lib/core/services/biopay_ussd_service.dart" "Uri.parse('tel:"
require_static_contains "Dial action copy" "lib/features/biopay/biopay_flow_shared.dart" "Dial USSD"
require_static_contains "User paid claim copy" "lib/features/biopay/biopay_flow_shared.dart" "I finished USSD"
require_static_contains "External confirmation copy" "lib/features/biopay/biopay_admin_console_screen.dart" "Confirm external"
require_static_contains "Admin confirmations copy" "lib/features/biopay/biopay_admin_console_screen.dart" "Confirmations"
require_static_absent "No admin Activity screen copy" "lib/features/biopay/biopay_screen.dart" "title: 'Activity'"
require_static_contains "External confirmation RPC" "supabase/migrations/20260612133000_biopay_ussd_aws_reactivation.sql" "rpc_confirm_biopay_ussd_external"
require_static_contains "Face scan preview start" "lib/features/biopay/biopay_face_scan_screen.dart" "Start Face Scan"
require_static_contains "Face scan explicit match" "lib/features/biopay/biopay_face_scan_screen.dart" "Match face"
require_static_contains "QR share uses safe payload" "lib/features/biopay/biopay_flow_shared.dart" "data: buildBioPayQrPayload(request)"
require_static_absent "No visible raw USSD display" "lib/features/biopay/biopay_flow_shared.dart" "request.ussdCode"
require_static_absent "No payment-intents dependency" "lib/core/services/biopay_ussd_service.dart" "payment_intents"
require_static_absent "No in-app Pay command" "lib/features/biopay/biopay_flow_shared.dart" "'Pay'"
require_static_absent "Face scan does not auto-open USSD" "lib/features/biopay/biopay_face_scan_screen.dart" "openedRequest = await ussdService.openUssdDialer"

section "AWS face provider boundary"
require_static_contains "Edge function slug" "lib/core/services/biopay_face_service.dart" "biopay-face-provider"
require_static_contains "Liveness action" "lib/core/services/biopay_face_service.dart" "create_liveness_session"
require_static_contains "Enroll action" "lib/core/services/biopay_face_service.dart" "enroll_face"
require_static_contains "Match action" "lib/core/services/biopay_face_service.dart" "match_face"
require_static_contains "AWS provider edge" "supabase/functions/biopay-face-provider/index.ts" "aws_rekognition"
require_static_contains "AWS Rekognition API" "supabase/functions/biopay-face-provider/index.ts" "rekognition"
require_static_contains "AWS collection status" "supabase/functions/biopay-face-provider/index.ts" "provider_collection_id"
require_static_contains "AWS module versions" "supabase/functions/biopay-face-provider/index.ts" "module_versions"
require_static_contains "Enrollment challenge metadata" "supabase/functions/biopay-face-provider/index.ts" "enrollment_challenges"
require_static_contains "Enrollment sample metadata" "lib/core/services/biopay_face_service.dart" "enrollment_sample_count"
require_static_contains "Explicit liveness status" "lib/core/services/biopay_face_service.dart" "provider_liveness_not_required"
require_static_contains "Enrollment persistence RPC" "supabase/migrations/20260612133000_biopay_ussd_aws_reactivation.sql" "rpc_record_biopay_face_enrollment"
require_static_absent "No Google ML Kit dependency" "pubspec.yaml" "google_mlkit_face_detection"
require_static_absent "No TFLite dependency" "pubspec.yaml" "tflite_flutter"

section "Native permission surface"
require_static_contains "Android camera permission" "android/app/src/main/AndroidManifest.xml" "android.permission.CAMERA"
require_static_contains "Android NFC permission" "android/app/src/main/AndroidManifest.xml" "android.permission.NFC"
require_static_absent "No Android SMS read" "android/app/src/main/AndroidManifest.xml" "android.permission.READ_SMS"
require_static_absent "No Android SMS receive" "android/app/src/main/AndroidManifest.xml" "android.permission.RECEIVE_SMS"
require_static_contains "iOS camera usage" "ios/Runner/Info.plist" "NSCameraUsageDescription"
require_static_contains "iOS NFC usage" "ios/Runner/Info.plist" "NFCReaderUsageDescription"
require_static_contains "iOS NFC entitlement" "ios/Runner/Runner.entitlements" "com.apple.developer.nfc"

section "Local compiler checks"
if deno check supabase/functions/biopay-face-provider/index.ts >/tmp/biopay-deno-check.log 2>&1; then
  record PASS "Deno edge check" "biopay-face-provider compiles"
else
  record FAIL "Deno edge check" "see /tmp/biopay-deno-check.log"
fi

if deno test --allow-env supabase/functions/biopay-face-provider/index_test.ts >/tmp/biopay-deno-test.log 2>&1; then
  record PASS "Deno edge tests" "biopay-face-provider metadata contract passed"
else
  record FAIL "Deno edge tests" "see /tmp/biopay-deno-test.log"
fi

if /Volumes/PRO-G40/flutter_3_44/bin/flutter test \
  test/features/biopay \
  test/core/router/app_router_test.dart \
  test/release/scope_boundary_test.dart \
  test/release/backend_scope_boundary_test.dart \
  >/tmp/biopay-flutter-focused.log 2>&1; then
  record PASS "Focused Flutter BioPay tests" "feature, router, and boundary tests passed"
else
  record FAIL "Focused Flutter BioPay tests" "see /tmp/biopay-flutter-focused.log"
fi

section "Optional live AWS proof"
if [[ "$require_aws_live" == "true" ]]; then
  prove_live_biopay_health "Live AWS provider proof"
else
  record WARN "Live AWS provider proof" "skipped; set REQUIRE_BIOPAY_AWS_LIVE=true to require AWS env/config proof"
fi

section "Optional live Supabase edge proof"
if [[ "$require_supabase_live" == "true" ]]; then
  prove_live_biopay_health "Live Supabase BioPay face health"
else
  record WARN "Live Supabase edge proof" "skipped; set REQUIRE_BIOPAY_SUPABASE_LIVE=true with BIOPAY_FACE_HEALTH_URL and SUPABASE_ANON_KEY"
fi

section "Optional Android device proof"
if [[ "$require_device_live" == "true" ]]; then
  if ! command -v adb >/dev/null 2>&1; then
    record FAIL "adb" "required for device proof"
  else
    if [[ -n "${ANDROID_SERIAL:-}" ]]; then
      device="$ANDROID_SERIAL"
    else
      device_count="$(adb devices | awk 'NR > 1 && $2 == "device" { count++ } END { print count + 0 }')"
      if [[ "$device_count" -gt 1 ]]; then
        record FAIL "Android device" "multiple authorized devices; set ANDROID_SERIAL"
        device=""
      else
        device="$(adb devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')"
      fi
    fi
    if [[ -z "${device:-}" ]]; then
      record FAIL "Android device" "no authorized device"
    else
      features="$(adb -s "$device" shell pm list features | tr -d '\r' || true)"
      package_dump="$(adb -s "$device" shell dumpsys package "$package_name" | tr -d '\r' || true)"
      dialers="$(adb -s "$device" shell cmd package query-intent-activities -a android.intent.action.DIAL -d 'tel:*182%23' | tr -d '\r' || true)"
      if rg -q 'android.hardware.camera' <<<"$features"; then
        record PASS "Device camera feature" "$device exposes android.hardware.camera"
      else
        record FAIL "Device camera feature" "$device does not expose android.hardware.camera"
      fi
      if rg -q 'android.hardware.nfc' <<<"$features"; then
        record PASS "Device NFC feature" "$device exposes android.hardware.nfc"
      else
        record FAIL "Device NFC feature" "$device does not expose android.hardware.nfc"
      fi
      if rg -q 'android.permission.CAMERA' <<<"$package_dump" &&
        rg -q 'android.permission.NFC' <<<"$package_dump"; then
        record PASS "Installed package permissions" "$package_name requests camera and NFC"
      else
        record FAIL "Installed package permissions" "$package_name camera/NFC permissions not proven"
      fi
      if [[ -n "$dialers" ]]; then
        record PASS "USSD tel dialer capability" "device resolves ACTION_DIAL tel: intent"
      else
        record FAIL "USSD tel dialer capability" "device did not resolve ACTION_DIAL tel: intent"
      fi
    fi
  fi
else
  record WARN "Live Android camera/NFC/USSD proof" "skipped; set REQUIRE_BIOPAY_DEVICE_LIVE=true with an unlocked authorized device"
fi

{
  echo "# BioPay Live Readiness Evidence"
  echo
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Repository: $repo_root"
  echo
  echo "## Result"
  echo
  echo "- Checks run: $checked"
  echo "- Failures: $failures"
  echo "- Warnings: $warnings"
  echo "- Live AWS required: $require_aws_live"
  echo "- Live Supabase required: $require_supabase_live"
  echo "- Live Android device required: $require_device_live"
  echo "- Strict live proof required: $require_live"
  echo
  echo "## Checks"
  echo
  printf '%s\n' "${status_lines[@]}"
  echo
  echo "## Boundary"
  echo
  echo "Payment remains outside the app. BioPay only creates or resolves requests and opens a tel: USSD dialer handoff; external evidence is required for confirmed status."
} > "$evidence_file"

echo
echo "Evidence written: $evidence_file"

if [[ "$failures" -ne 0 ]]; then
  echo "NO-GO: BioPay readiness has $failures failure(s)." >&2
  exit 1
fi

echo "PASS: BioPay readiness static checks passed with $warnings warning(s)."
