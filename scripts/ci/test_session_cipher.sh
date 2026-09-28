#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
for tool in kotlinc java; do
  command -v "$tool" >/dev/null || { echo "UNAVAILABLE: $tool; no PASS" >&2; exit 2; }
done
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
kotlinc "$root/android/app/src/main/kotlin/rw/mobi/app/SessionCipher.kt" \
  "$root/scripts/tests/kotlin/SessionCipherTest.kt" -include-runtime -d "$scratch/session-tests.jar"
java -jar "$scratch/session-tests.jar"
