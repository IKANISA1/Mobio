#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

package_name="${ANDROID_PACKAGE_NAME:-rw.mobi.app}"
aab_path="${ANDROID_RELEASE_AAB:-build/app/outputs/bundle/release/app-release.aab}"
track="${PLAY_RELEASE_TRACK:-internal}"
release_status="${PLAY_RELEASE_STATUS:-draft}"
version_code="$(
  awk -F'+' '/^version:/ {
    split($2, parts, /[[:space:]]/)
    print parts[1]
    exit
  }' pubspec.yaml
)"
changelog_path="android/fastlane/metadata/android/en-US/changelogs/${version_code}.txt"

usage() {
  cat <<'EOF'
Upload the current Android AAB to Google Play.

Required artifact:
  build/app/outputs/bundle/release/app-release.aab

Credential options:
  1. PLAY_STORE_SERVICE_ACCOUNT_JSON contains a Google service-account JSON object.
  2. PLAY_STORE_JSON_KEY points to a Google service-account JSON file.
  3. GOOGLE_PLAY_SERVICE_ACCOUNT_JSON contains a JSON object, a path to a JSON file, or base64 JSON.
  4. GOOGLE_PLAY_USE_GCLOUD_OAUTH=true uses a refreshed local gcloud account with androidpublisher scope.

Production guard:
  PLAY_RELEASE_TRACK=production also requires PLAY_PRODUCTION_APPROVED=true.

Examples:
  PLAY_RELEASE_TRACK=internal PLAY_RELEASE_STATUS=draft ./scripts/release/upload_google_play_release.sh
  PLAY_RELEASE_TRACK=production PLAY_RELEASE_STATUS=completed PLAY_PRODUCTION_APPROVED=true ./scripts/release/upload_google_play_release.sh
  GOOGLE_PLAY_USE_GCLOUD_OAUTH=true GCLOUD_ACCOUNT=you@example.com PLAY_RELEASE_TRACK=production PLAY_RELEASE_STATUS=completed PLAY_PRODUCTION_APPROVED=true ./scripts/release/upload_google_play_release.sh
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

case "$track" in
  internal|alpha|beta|production) ;;
  *)
    echo "PLAY_RELEASE_TRACK must be one of: internal, alpha, beta, production" >&2
    exit 1
    ;;
esac

case "$release_status" in
  draft|completed|inProgress|halted) ;;
  *)
    echo "PLAY_RELEASE_STATUS must be one of: draft, completed, inProgress, halted" >&2
    exit 1
    ;;
esac

if [[ "$track" == "production" && "${PLAY_PRODUCTION_APPROVED:-false}" != "true" ]]; then
  echo "PLAY_PRODUCTION_APPROVED=true is required for production-track uploads." >&2
  exit 1
fi

if [[ -z "$version_code" ]]; then
  echo "Could not read Android versionCode from pubspec.yaml." >&2
  exit 1
fi

if [[ ! -s "$aab_path" ]]; then
  echo "AAB not found at $aab_path. Build it first with ./scripts/release/build_android_release.sh appbundle." >&2
  exit 1
fi

json_from_candidate() {
  local candidate="$1"
  [[ -n "$candidate" ]] || return 1

  if [[ -f "$candidate" ]]; then
    python3 - "$candidate" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
if data.get("type") != "service_account" or not data.get("client_email"):
    raise SystemExit(2)
print(json.dumps(data, separators=(",", ":")))
PY
    return
  fi

  CANDIDATE="$candidate" python3 - <<'PY'
import base64, json, os, sys

raw = os.environ["CANDIDATE"].strip()
values = [raw]
try:
    values.append(base64.b64decode(raw).decode("utf-8"))
except Exception:
    pass

for value in values:
    try:
        data = json.loads(value)
    except Exception:
        continue
    if data.get("type") == "service_account" and data.get("client_email"):
        print(json.dumps(data, separators=(",", ":")))
        raise SystemExit(0)

raise SystemExit(2)
PY
}

service_account_json=""
for candidate in \
  "${PLAY_STORE_SERVICE_ACCOUNT_JSON:-}" \
  "${PLAY_STORE_JSON_KEY:-}" \
  "${GOOGLE_PLAY_SERVICE_ACCOUNT_JSON:-}" \
  "${GOOGLE_APPLICATION_CREDENTIALS:-}" \
  "${GOOGLE_SA_KEY_PATH:-}"; do
  if service_account_json="$(json_from_candidate "$candidate" 2>/dev/null)"; then
    break
  fi
  service_account_json=""
done

if [[ -n "$service_account_json" ]]; then
  export PLAY_STORE_SERVICE_ACCOUNT_JSON="$service_account_json"
  echo "Uploading $aab_path to Google Play via Fastlane supply."
  echo "package=$package_name track=$track status=$release_status versionCode=$version_code"
  (
    cd android
    PLAY_RELEASE_TRACK="$track" \
      PLAY_RELEASE_STATUS="$release_status" \
      PLAY_PRODUCTION_APPROVED="${PLAY_PRODUCTION_APPROVED:-false}" \
      fastlane deploy
  )
  exit 0
fi

if [[ "${GOOGLE_PLAY_USE_GCLOUD_OAUTH:-false}" != "true" ]]; then
  echo "No valid Google Play service-account JSON was found." >&2
  echo "Set PLAY_STORE_SERVICE_ACCOUNT_JSON, PLAY_STORE_JSON_KEY, or GOOGLE_PLAY_SERVICE_ACCOUNT_JSON." >&2
  echo "The local GOOGLE_APPLICATION_CREDENTIALS file is not enough unless it is a service_account JSON." >&2
  echo "Alternatively set GOOGLE_PLAY_USE_GCLOUD_OAUTH=true after running interactive gcloud reauthentication." >&2
  exit 2
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud is required for GOOGLE_PLAY_USE_GCLOUD_OAUTH=true." >&2
  exit 127
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required for Google Play API upload." >&2
  exit 127
fi

token_args=(--scopes=https://www.googleapis.com/auth/androidpublisher)
if [[ -n "${GCLOUD_ACCOUNT:-}" ]]; then
  token_args=("${GCLOUD_ACCOUNT}" "${token_args[@]}")
fi

token="$(gcloud auth print-access-token "${token_args[@]}")"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/mobio-play-upload.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

api_base="https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${package_name}"
upload_base="https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/${package_name}"

curl_json() {
  curl -fsS \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    "$@"
}

edit_json="$tmp_dir/edit.json"
curl_json -X POST -d '{}' "$api_base/edits" > "$edit_json"
edit_id="$(python3 - "$edit_json" <<'PY'
import json, sys
print(json.load(open(sys.argv[1])).get("id", ""))
PY
)"
if [[ -z "$edit_id" ]]; then
  echo "Google Play edit creation did not return an edit id." >&2
  exit 1
fi

bundle_json="$tmp_dir/bundle.json"
curl -fsS \
  -H "Authorization: Bearer $token" \
  -H "Content-Type: application/octet-stream" \
  --data-binary "@$aab_path" \
  "${upload_base}/edits/${edit_id}/bundles?uploadType=media" > "$bundle_json"

uploaded_version_code="$(python3 - "$bundle_json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
print(data.get("versionCode", ""))
PY
)"
if [[ -z "$uploaded_version_code" ]]; then
  echo "Google Play bundle upload did not return a versionCode." >&2
  exit 1
fi

release_notes=""
if [[ -f "$changelog_path" ]]; then
  release_notes="$(python3 - "$changelog_path" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read().strip()
print(text[:500])
PY
)"
fi

track_body="$tmp_dir/track.json"
VERSION_CODE="$uploaded_version_code" \
RELEASE_STATUS="$release_status" \
RELEASE_NOTES="$release_notes" \
python3 - <<'PY' > "$track_body"
import json, os

release = {
    "versionCodes": [os.environ["VERSION_CODE"]],
    "status": os.environ["RELEASE_STATUS"],
}
notes = os.environ.get("RELEASE_NOTES", "").strip()
if notes:
    release["releaseNotes"] = [{"language": "en-US", "text": notes}]

print(json.dumps({"releases": [release]}, separators=(",", ":")))
PY

curl_json -X PUT -d "@$track_body" "$api_base/edits/${edit_id}/tracks/${track}" > "$tmp_dir/track-response.json"
curl_json -X POST -d '{}' "$api_base/edits/${edit_id}:commit?changesNotSentForReview=false" > "$tmp_dir/commit.json"

echo "Google Play upload committed."
echo "package=$package_name track=$track status=$release_status versionCode=$uploaded_version_code edit=$edit_id"
