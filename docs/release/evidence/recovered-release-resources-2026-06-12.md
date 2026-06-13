# Recovered Release Resources Inventory

Date: 2026-06-12
Scope: local MOBI repo, `/Volumes/PRO-G40`, and `/Users/jeanbosco` credential
and release-resource search.

No secret values are stored in this file.

## Signing Resources

### Active Android Upload Keystore

Path:

`/Volumes/PRO-G40/MOBI/mobi_app/android/mobi-upload.jks`

Verification:

- Referenced by `/Volumes/PRO-G40/MOBI/mobi_app/android/key.properties`.
- `keyAlias`: `upload`.
- `keytool` verified alias `upload` in `android/mobi-upload.jks`.
- Entry type: `PrivateKeyEntry`.
- Creation date: `2026-03-24`.
- Valid until: `2053-08-09`.
- SHA-256 certificate fingerprint:
  `DA:9E:5E:AB:50:D0:85:05:BF:0B:78:7C:EA:B5:DB:5B:40:77:8E:BE:77:62:95:72:16:8A:72:37:D7:79:81:C0`.

Local file digest:

- `android/mobi-upload.jks`:
  `74768338f1b2460af3506f8a230d41d3173c576efd27f87558e1ec37ae86e0b9`.

### Secondary Keystore Candidate

Path:

`/Volumes/PRO-G40/MOBI/mobi_app/android/app/upload-keystore.jks`

Local file digest:

- `android/app/upload-keystore.jks`:
  `acc6a2837b7e899782b704e76b7dea48492ec66cc13ac5535d6886a28625ce78`.

Status:

- Present, but not the active `storeFile` in `android/key.properties`.

### Release Password/Alias File

Path:

`/Volumes/PRO-G40/MOBI/mobi_app/android/key.properties`

Status:

- Present.
- Contains `storePassword`, `keyPassword`, `keyAlias`, and `storeFile`.
- Values were used locally for validation but are not copied into this evidence.

## Google Play / Service Account Resources

### Play Service Account JSON

Path:

`/Users/jeanbosco/Downloads/easymoai-208b85b24685.json`

Verification:

- JSON `type`: `service_account`.
- Project id: `easymoai`.
- Client email: `firmos-agents@easymoai.iam.gserviceaccount.com`.
- Private key material exists in the file.
- Private key id prefix: `208b85b2...`.
- File digest:
  `98d9df5eada31748ee66db6b7b9a25e758b6fc9b8cc7b3a47179a0d8ae3f143f`.

This matches the service-account identity recorded in:

`/Volumes/PRO-G40/MOBI/mobi_app/docs/release/evidence/play-console-upload-2026-06-12-v13.md`

### Google Cloud SDK State

Relevant paths:

- `/Users/jeanbosco/.config/gcloud/cache/firmos-agents@easymoai.iam.gserviceaccount.com/resource.cache`
- `/Users/jeanbosco/.config/gcloud/credentials.db`
- `/Users/jeanbosco/.config/gcloud/access_tokens.db`
- `/Users/jeanbosco/.config/gcloud/application_default_credentials.json`

Observed active account:

- `info@ikanisa.com`

Status:

- gcloud has cached resource state for the same service-account identity used
  by the Play upload evidence.

## Play Upload Evidence

Path:

`/Volumes/PRO-G40/MOBI/mobi_app/docs/release/evidence/play-console-upload-2026-06-12-v13.md`

Status:

- Existing evidence for Google Play internal draft upload.
- Package: `rw.mobi.app`.
- Track: `internal`.
- Version code: `13`.
- Version name: `1.0.0`.
- Result recorded as successful Play upload.
- Accepted by the aggregate go/no-go evidence check when used as
  `PLAY_CONSOLE_UPLOAD_EVIDENCE`.

## Key Retention Decision

The owner explicitly instructed on 2026-06-12:

- keep the current Play/service-account keys as they are,
- do not rotate any keys,
- do not revoke the current key.

Retention evidence:

`docs/release/evidence/play-service-account-retention-2026-06-12.md`

The aggregate gate now accepts either:

- rotation/revocation evidence, or
- owner-approved retention evidence.

## Validation Performed With Recovered Resources

### Release Config

`scripts/ci/verify_release_config.sh` passed when fed from:

- `android/mobi-upload.jks`
- `android/key.properties`
- `/Users/jeanbosco/Downloads/easymoai-208b85b24685.json`
- `.env`

### Aggregate Go/No-Go Dry Run

The aggregate dry run was executed with:

- recovered Android signing env,
- recovered Play service-account JSON,
- linked Supabase credentials,
- existing Play upload evidence,
- Flutter and Android smoke skipped in dry-run mode.

Passed:

- Committed secret scan.
- Git secret-history proof.
- Linked Supabase backend gates.
- Release config and signing gates.
- Play Console upload evidence gate.

Still blocked:

- Dry-run mode cannot approve production.

## Search Notes

Search methods used:

- MOBI repo filename scan for keystores, `.env`, Firebase, Play, and Supabase
  files.
- MOBI repo content scan for release env names and signing config.
- `/Users/jeanbosco` filename scan for keystores, service-account JSON, Firebase
  files, and `.env` files.
- `/Volumes/PRO-G40` filename/content searches with build/cache folders pruned.
- macOS Spotlight search for service-account, Play, `easymoai`, and keystore
  names.
- Shell history search with token redaction.
- Fastlane logs and release evidence scan.

Long-running broad recursive searches were stopped after the concrete resources
above were found and validated.
