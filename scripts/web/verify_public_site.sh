#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
site_dir="${1:-$repo_root/landing}"

if [[ ! -d "$site_dir" ]]; then
  echo "Public site directory not found: $site_dir" >&2
  exit 1
fi

required_files=(
  "index.html"
  "privacy-policy.html"
  "terms-and-conditions.html"
  "account-deletion.html"
  ".well-known/assetlinks.json"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$site_dir/$file" ]]; then
    echo "Missing public site file: $site_dir/$file" >&2
    exit 1
  fi
done

python3 - <<'PY' "$site_dir/.well-known/assetlinks.json" "$site_dir/.well-known/apple-app-site-association"
import json
import os
import sys
from pathlib import Path

path = Path(sys.argv[1])
aasa_path = Path(sys.argv[2])
data = json.loads(path.read_text(encoding="utf-8"))

def fail(message: str) -> None:
    raise SystemExit(message)

if not isinstance(data, list) or not data:
    fail("assetlinks.json must contain a non-empty array")

target = data[0].get("target", {})
if target.get("namespace") != "android_app":
    fail("assetlinks target namespace mismatch")
if target.get("package_name") != "rw.mobi.app":
    fail("assetlinks package_name mismatch")
fingerprints = target.get("sha256_cert_fingerprints")
expected = "DA:9E:5E:AB:50:D0:85:05:BF:0B:78:7C:EA:B5:DB:5B:40:77:8E:BE:77:62:95:72:16:8A:72:37:D7:79:81:C0"
if not isinstance(fingerprints, list) or expected not in fingerprints:
    fail("assetlinks certificate fingerprint missing")

team_id = os.environ.get("APPLE_TEAM_ID", "").strip()
expected_app_id = f"{team_id}.rw.mobi.app" if team_id else ""

if not aasa_path.exists():
    if team_id:
        fail("apple-app-site-association missing while APPLE_TEAM_ID is set")
    print("warning: APPLE_TEAM_ID not set; skipping AASA validation", file=sys.stderr)
else:
    aasa = json.loads(aasa_path.read_text(encoding="utf-8"))
    details = aasa.get("applinks", {}).get("details", [])
    app_ids = []
    for detail in details:
        if "appIDs" in detail and isinstance(detail["appIDs"], list):
            app_ids.extend(detail["appIDs"])
        if "appID" in detail:
            app_ids.append(detail["appID"])
    if expected_app_id and expected_app_id not in app_ids:
        fail("apple-app-site-association appID mismatch")
PY

site_text="$(mktemp)"
trap 'rm -f "$site_text"' EXIT
find "$site_dir" -name '*.html' -type f -print0 \
  | xargs -0 awk 'BEGINFILE { print "\n--- " FILENAME " ---" } { print }' \
  | tr '[:upper:]' '[:lower:]' > "$site_text"

required_phrases=(
  "nearby discovery"
  "scheduled trip posts"
  "whatsapp handoff"
  "account deletion"
  "does not process in-app ride payments"
  "does not provide automatic fare quotes"
  "biopay"
  "momo ussd"
  "background location"
)

for phrase in "${required_phrases[@]}"; do
  if ! grep -Fq "$phrase" "$site_text"; then
    echo "Missing required public-site phrase: $phrase" >&2
    exit 1
  fi
done

prohibited_phrases=(
  "biometric payments"
  "pay instantly"
  "pay with face"
  "mtn momo"
  "route calculations"
  "enable ride booking"
  "ride bookings"
  "start a ride"
  "payment options"
)

for phrase in "${prohibited_phrases[@]}"; do
  if grep -Fq "$phrase" "$site_text"; then
    echo "Prohibited stale public-site phrase found: $phrase" >&2
    exit 1
  fi
done

echo "public-site scope verification passed"
