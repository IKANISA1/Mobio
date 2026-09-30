#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

# A partial run must never be reported as a successful integrated release gate.
# Validate before resolving Flutter, including explicitly empty/invalid values.
for setting in \
  "RUN_MOBIO_CONTRACT_TESTS=${RUN_MOBIO_CONTRACT_TESTS-true}" \
  "RUN_MOBIO_BIOPAY_FEATURE_GATE=${RUN_MOBIO_BIOPAY_FEATURE_GATE-true}"; do
  if [[ "${setting#*=}" != "true" ]]; then
    echo "INCOMPLETE: ${setting%%=*} must be true for integrated readiness." >&2
    exit 2
  fi
done

failures=0
source "$repo_root/scripts/lib/flutter.sh"
flutter_bin="$FLUTTER_BIN"

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

run_flutter_tests() {
  "$flutter_bin" test --no-pub "$@"
}

echo "Mobio integrated feature readiness"
echo "BioPay is treated here as one Mobio feature, alongside wallet, subscriptions, scheduling, public transport, admin, notifications, privacy, and backend scope."

if [[ "${RUN_MOBIO_CONTRACT_TESTS:-true}" == "true" ]]; then
  run_gate \
    "Mobio shell, privacy, discoverability, and scope contracts" \
    run_flutter_tests \
      test/release/mobile_readiness_contract_test.dart \
      test/release/scope_boundary_test.dart \
      test/release/discoverability_privacy_contract_test.dart \
      test/release/backend_scope_boundary_test.dart

  run_gate \
    "Wallet, tokens, subscriptions, Mobio Plus, and MoMo contracts" \
    run_flutter_tests \
      test/release/wallet_driver_plus_contract_test.dart \
      test/features/profile/widgets/profile_momo_section_test.dart

  run_gate \
    "Scheduling and public transport contracts" \
    run_flutter_tests \
      test/release/scheduling_production_hardening_contract_test.dart \
      test/release/public_transport_schema_contract_test.dart \
      test/models/public_transport_test.dart

  run_gate \
    "Admin, reports, blocks, and notifications contracts" \
    run_flutter_tests \
      test/release/admin_panel_production_readiness_contract_test.dart \
      test/release/report_block_contract_test.dart \
      test/release/notification_delivery_contract_test.dart
else
  echo
  echo "== Mobio feature contract tests =="
  echo "SKIP: RUN_MOBIO_CONTRACT_TESTS=false"
fi

if [[ "${RUN_MOBIO_BIOPAY_FEATURE_GATE:-true}" == "true" ]]; then
  run_gate \
    "BioPay feature readiness within Mobio" \
    env REQUIRE_BIOPAY_LIVE=true \
    ./scripts/qa/verify_biopay_live_readiness.sh
else
  echo
  echo "== BioPay feature readiness within Mobio =="
  echo "SKIP: RUN_MOBIO_BIOPAY_FEATURE_GATE=false"
fi

echo
if [[ "$failures" -ne 0 ]]; then
  echo "NO-GO: Mobio integrated feature readiness has $failures failure(s)." >&2
  exit 1
fi

echo "PASS: Mobio integrated feature readiness gates passed."
