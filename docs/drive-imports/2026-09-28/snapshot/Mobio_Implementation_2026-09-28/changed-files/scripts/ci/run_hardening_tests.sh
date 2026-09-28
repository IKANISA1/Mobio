#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"
for tool in python3 node javac java kotlinc; do
  command -v "$tool" >/dev/null || { echo "UNAVAILABLE: $tool is required; no aggregate PASS" >&2; exit 2; }
done
python3 -c 'import yaml' || { echo 'UNAVAILABLE: install scripts/ci/requirements.txt' >&2; exit 2; }
python3 -m unittest discover -s scripts/tests -p test_production_gates.py -v
python3 -m unittest discover -s scripts/tests -p test_hardening_preparation.py -v
python3 -m unittest discover -s scripts/tests -p test_play_version_evidence.py -v
python3 scripts/ci/check_github_actions_pinned.py
node --experimental-strip-types --test scripts/tests/edge/hardening.test.mjs
node --experimental-transform-types --loader ./scripts/tests/edge/fixture-loader.mjs \
  --test scripts/tests/edge/handlers.test.mjs
python3 -m unittest discover -s services/face-inference/tests -p test_server_bounds.py -v
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
kotlinc android/app/src/main/kotlin/rw/mobi/app/BioPayNfcPolicy.kt \
  scripts/tests/kotlin/BioPayNfcPolicyTest.kt -include-runtime -d "$scratch/nfc-policy-tests.jar"
java -jar "$scratch/nfc-policy-tests.jar"
echo 'PASS: hardening local unit/fixture/HTTP/JVM checks. NOT database, Deno, model accuracy, Android or iOS acceptance.'
