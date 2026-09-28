#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
for command in python3 node; do
  command -v "$command" >/dev/null || { echo "UNAVAILABLE: $command; no PASS" >&2; exit 2; }
done
python3 -m unittest discover -s scripts/tests -p test_sms_intake_contracts.py -v
python3 -m unittest discover -s scripts/tests -p test_increment04_applier.py -v
node --experimental-transform-types --loader ./scripts/tests/edge/fixture-loader.mjs \
  --test scripts/tests/edge/intake.test.mjs
printf '%s\n' 'PASS: local source/guard and Node handler fixtures only; PostgreSQL, Deno, device and deployment acceptance remain separate.'
