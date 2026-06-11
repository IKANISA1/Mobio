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
  PLAY_SERVICE_ACCOUNT_ROTATED \
  PLAY_SERVICE_ACCOUNT_ROTATION_EVIDENCE \
  "Play service-account key revoked/rotated in Google Cloud IAM"
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
