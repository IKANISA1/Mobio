#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
for tool in python3 node; do
  command -v "$tool" >/dev/null || { echo "UNAVAILABLE: $tool; no privacy checks PASS" >&2; exit 2; }
done
node --experimental-strip-types --test scripts/tests/privacy/*.test.mjs
python3 -m unittest discover -s scripts/tests -p 'test_privacy_evidence.py' -v
python3 -m unittest discover -s scripts/tests -p 'test_privacy_runner.py' -v
python3 -m unittest discover -s scripts/tests -p 'test_increment09_applier.py' -v
echo 'PASS: request-gateway fixtures, local evidence verification and tooling. NOT SQL, Flutter or provider erasure.'
