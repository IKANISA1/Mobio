#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

failures=0
dry_run="${GO_NO_GO_DRY_RUN:-false}"
release_target="${RELEASE_TARGET:-all}"

case "$release_target" in
  all|android|ios) ;;
  *)
    echo "RELEASE_TARGET must be one of: all, android, ios" >&2
    exit 1
    ;;
esac

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

run_gate() {
  local name="$1"
  shift

  echo
  echo "== $name =="
  if "$@"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name" >&2
    failures=$((failures + 1))
  fi
}

require_evidence() {
  local ack_name="$1"
  local evidence_name="$2"
  local description="$3"

  echo
  echo "== $description =="

  if [[ "${!ack_name:-false}" != "true" ]]; then
    echo "FAIL: set $ack_name=true after external evidence exists." >&2
    failures=$((failures + 1))
    return
  fi

  local evidence_path="${!evidence_name:-}"
  if [[ -z "$evidence_path" || ! -f "$evidence_path" ]]; then
    echo "FAIL: set $evidence_name to an existing evidence file." >&2
    failures=$((failures + 1))
    return
  fi

  if [[ "$evidence_path" == *.example.md ]]; then
    echo "FAIL: $evidence_name must not point to an example template." >&2
    failures=$((failures + 1))
    return
  fi

  echo "PASS: $description ($evidence_path)"
}

require_play_service_account_decision() {
  echo
  echo "== Play service-account credential decision =="

  if [[ "${PLAY_SERVICE_ACCOUNT_RETAINED:-false}" != "true" ]]; then
    echo "FAIL: set PLAY_SERVICE_ACCOUNT_RETAINED=true after owner-approved credential retention/use." >&2
    failures=$((failures + 1))
    return
  fi

  local retention_evidence="${PLAY_SERVICE_ACCOUNT_RETENTION_EVIDENCE:-}"
  if [[ -z "$retention_evidence" || ! -f "$retention_evidence" ]]; then
    echo "FAIL: set PLAY_SERVICE_ACCOUNT_RETENTION_EVIDENCE to an existing owner-approval evidence file." >&2
    failures=$((failures + 1))
    return
  fi

  if [[ "$retention_evidence" == *.example.md ]]; then
    echo "FAIL: PLAY_SERVICE_ACCOUNT_RETENTION_EVIDENCE must not point to an example template." >&2
    failures=$((failures + 1))
    return
  fi

  echo "PASS: Play service-account credential retained by owner decision ($retention_evidence)"
}

current_android_version_code() {
  awk -F'+' '/^version:/ {
    split($2, parts, /[[:space:]]/)
    print parts[1]
    exit
  }' pubspec.yaml
}

require_current_play_console_upload_evidence() {
  require_evidence \
    PLAY_CONSOLE_UPLOAD_VALIDATED \
    PLAY_CONSOLE_UPLOAD_EVIDENCE \
    "Play Console internal/closed-track upload validated"

  local evidence_path="${PLAY_CONSOLE_UPLOAD_EVIDENCE:-}"
  if [[ -z "$evidence_path" || ! -f "$evidence_path" || "$evidence_path" == *.example.md ]]; then
    return
  fi

  local expected_version_code
  expected_version_code="$(current_android_version_code)"
  if [[ -z "$expected_version_code" ]]; then
    echo "FAIL: could not read Android version code from pubspec.yaml." >&2
    failures=$((failures + 1))
    return
  fi

  if ! python3 scripts/release/check_play_version_evidence.py "$evidence_path" "$expected_version_code"; then
    echo "FAIL: $evidence_path does not prove Play upload for current versionCode $expected_version_code." >&2
    failures=$((failures + 1))
    return
  fi

  echo "PASS: Play Console upload evidence matches current versionCode $expected_version_code"
}

run_gate "Reviewed hardening migrations prepared" python3 ./scripts/ci/prepare_hardening_migrations.py --check

if [[ "${RUN_FLUTTER_GATE:-true}" == "true" ]]; then
  run_gate "Flutter analyze/test gate" ./scripts/ci/verify_flutter.sh
elif [[ "$dry_run" == "true" ]]; then
  echo
  echo "== Flutter analyze/test gate =="
  echo "SKIP: dry-run only; this is not production evidence."
else
  echo "RUN_FLUTTER_GATE=false is only allowed with GO_NO_GO_DRY_RUN=true." >&2
  exit 1
fi

run_gate "Committed secret scan" ./scripts/qa/scan_secrets.sh
run_gate "Git secret history purge proof" ./scripts/qa/check_secret_history.sh
run_gate \
  "Linked Supabase backend gates" \
  env REQUIRE_LINKED_SUPABASE=true ./scripts/ci/verify_backend.sh
run_gate \
  "Release config and signing gates" \
  env \
    REQUIRE_ANDROID_SIGNING=true \
    REQUIRE_SECRET_HISTORY_CLEAN=true \
    REQUIRE_IOS_FIREBASE="$([[ "$release_target" == "android" ]] && echo false || echo true)" \
    REQUIRE_IOS_NATIVE="$([[ "$release_target" == "android" ]] && echo false || echo true)" \
    ./scripts/ci/verify_release_config.sh

require_evidence \
  GOOGLE_MAPS_SERVER_SECRET_VALIDATED \
  GOOGLE_MAPS_SERVER_SECRET_EVIDENCE \
  "Google Maps server key configured for maps-gateway"

require_evidence \
  FCM_HTTP_V1_SECRET_VALIDATED \
  FCM_HTTP_V1_SECRET_EVIDENCE \
  "FCM HTTP v1 service-account secrets configured for send-push"

if [[ "$release_target" != "android" ]]; then
  require_evidence \
    IOS_FIREBASE_APNS_VALIDATED \
    IOS_FIREBASE_APNS_EVIDENCE \
    "iOS Firebase registration and APNs capability/key validated"

  require_evidence \
    IOS_CRASHLYTICS_SYMBOLS_VALIDATED \
    IOS_CRASHLYTICS_SYMBOLS_EVIDENCE \
    "iOS Crashlytics dSYM upload validated"
fi

mobio_feature_gate="${RUN_MOBIO_FEATURE_GATE:-${RUN_BIOPAY_GATE:-true}}"
if [[ "$mobio_feature_gate" == "true" ]]; then
  run_gate \
    "Mobio integrated feature readiness gates" \
    env REQUIRE_BIOPAY_LIVE="${REQUIRE_BIOPAY_LIVE:-true}" \
    ./scripts/qa/verify_mobio_feature_readiness.sh
elif [[ "$dry_run" == "true" ]]; then
  echo
  echo "== Mobio integrated feature readiness gates =="
  echo "SKIP: dry-run only; this is not production evidence."
else
  echo "RUN_MOBIO_FEATURE_GATE=false is only allowed with GO_NO_GO_DRY_RUN=true." >&2
  exit 1
fi

require_play_service_account_decision
require_current_play_console_upload_evidence

if [[ "${RUN_ANDROID_SMOKE:-true}" == "true" ]]; then
  run_gate "Physical Android release smoke" \
    env ANDROID_SMOKE_ALLOW_EMULATOR=false ./scripts/release/smoke_android_release.sh
elif [[ "$dry_run" == "true" ]]; then
  echo
  echo "== Physical Android release smoke =="
  echo "SKIP: dry-run only; this is not production evidence."
else
  echo "RUN_ANDROID_SMOKE=false is only allowed with GO_NO_GO_DRY_RUN=true." >&2
  exit 1
fi

echo
if [[ "$dry_run" == "true" ]]; then
  echo "NO-GO: dry-run mode cannot approve production." >&2
  exit 1
fi

if [[ "$failures" -ne 0 ]]; then
  echo "NO-GO: $failures production gate(s) failed." >&2
  exit 1
fi

echo "GO: all production gates passed."
