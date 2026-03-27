#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

: "${KEYSTORE_BASE64:?Missing KEYSTORE_BASE64}"
: "${KEY_ALIAS:?Missing KEY_ALIAS}"
: "${KEY_PASSWORD:?Missing KEY_PASSWORD}"
: "${STORE_PASSWORD:?Missing STORE_PASSWORD}"

keystore_path="android/app/release.keystore"
key_properties_path="android/key.properties"

echo "$KEYSTORE_BASE64" | base64 -d > "$keystore_path"

cat > "$key_properties_path" <<EOF
storePassword=$STORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=$KEY_ALIAS
storeFile=app/release.keystore
EOF
