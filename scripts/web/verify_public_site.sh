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
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$site_dir/$file" ]]; then
    echo "Missing public site file: $site_dir/$file" >&2
    exit 1
  fi
done

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
  "biopay"
  "biopay —"
  "#biopay"
)

for phrase in "${prohibited_phrases[@]}"; do
  if grep -Fq "$phrase" "$site_text"; then
    echo "Prohibited stale public-site phrase found: $phrase" >&2
    exit 1
  fi
done

echo "public-site scope verification passed"
