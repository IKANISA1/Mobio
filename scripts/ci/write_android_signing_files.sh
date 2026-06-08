#!/usr/bin/env bash
set -euo pipefail
umask 077

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

: "${KEYSTORE_BASE64:?Missing KEYSTORE_BASE64}"
: "${KEY_ALIAS:?Missing KEY_ALIAS}"
: "${KEY_PASSWORD:?Missing KEY_PASSWORD}"
: "${STORE_PASSWORD:?Missing STORE_PASSWORD}"

keystore_path="android/app/release.keystore"
key_properties_path="android/key.properties"

cleanup() {
  rm -f "$keystore_path" "$key_properties_path"
}

trap cleanup EXIT

echo "$KEYSTORE_BASE64" | base64 -d > "$keystore_path"
chmod 600 "$keystore_path"

cat > "$key_properties_path" <<EOF
storePassword=$STORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=$KEY_ALIAS
storeFile=app/release.keystore
EOF
chmod 600 "$key_properties_path"

if [[ "${PRESERVE_ANDROID_SIGNING_FILES:-false}" == "true" ]]; then
  trap - EXIT
fi
