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
  echo "== Play service-account key decision =="

  local rotation_ok=false
  if [[ "${PLAY_SERVICE_ACCOUNT_ROTATED:-false}" == "true" ]]; then
    local rotation_evidence="${PLAY_SERVICE_ACCOUNT_ROTATION_EVIDENCE:-}"
    if [[ -n "$rotation_evidence" &&
      -f "$rotation_evidence" &&
      "$rotation_evidence" != *.example.md ]]; then
      echo "PASS: Play service-account key revoked/rotated in Google Cloud IAM ($rotation_evidence)"
      rotation_ok=true
    else
      echo "FAIL: set PLAY_SERVICE_ACCOUNT_ROTATION_EVIDENCE to an existing non-template evidence file." >&2
      failures=$((failures + 1))
      return
    fi
  fi

  if [[ "$rotation_ok" == "true" ]]; then
    return
  fi

  if [[ "${PLAY_SERVICE_ACCOUNT_RETAINED:-false}" != "true" ]]; then
    echo "FAIL: set PLAY_SERVICE_ACCOUNT_ROTATED=true after rotation, or PLAY_SERVICE_ACCOUNT_RETAINED=true after owner-approved key retention." >&2
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

  echo "PASS: Play service-account key retained by owner decision ($retention_evidence)"
}

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

if [[ "${RUN_BIOPAY_GATE:-true}" == "true" ]]; then
  run_gate \
    "BioPay live readiness gate" \
    env REQUIRE_BIOPAY_LIVE="${REQUIRE_BIOPAY_LIVE:-true}" \
    ./scripts/qa/verify_biopay_live_readiness.sh
elif [[ "$dry_run" == "true" ]]; then
  echo
  echo "== BioPay live readiness gate =="
  echo "SKIP: dry-run only; this is not production evidence."
else
  echo "RUN_BIOPAY_GATE=false is only allowed with GO_NO_GO_DRY_RUN=true." >&2
  exit 1
fi

require_play_service_account_decision
require_evidence \
  PLAY_CONSOLE_UPLOAD_VALIDATED \
  PLAY_CONSOLE_UPLOAD_EVIDENCE \
  "Play Console internal/closed-track upload validated"

if [[ "${RUN_ANDROID_SMOKE:-true}" == "true" ]]; then
  run_gate "Physical Android release smoke" ./scripts/release/smoke_android_release.sh
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
