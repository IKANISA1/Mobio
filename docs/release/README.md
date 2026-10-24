# Release

Release source of truth currently lives in:

- `../../.github/workflows/release.yml`
- `../../scripts/release`
- `../../scripts/ci/verify_release_config.sh`
- `../../scripts/release/go_no_go_check.sh`
- `evidence/`
- Root `README.md` release sections.

Every release must run Flutter verification, backend verification, migration/lint checks, signing validation, and artifact generation before deployment.

Store reviewer access is operated through the [controlled review runbook](store-review-access.md).
Keep its credentials in the private store console and secret store; public documentation
contains instructions and evidence references only.

## Android candidate and Play promotion

The tag and manual GitHub workflows now build a **candidate only**. They do not
upload to Google Play or publish a GitHub Release. A successful workflow stores
the signed AAB, `build/release-candidate.json`,
`build/android-release-build-inputs.json`, and symbols as artifacts. The
candidate record binds the full Git commit and tree, Android source version and
package, hardening migration hashes, validated Face model policy and its manifest hash, exact AAB hash, named
build environment, and SHA-256 digests of the four public Dart defines used by
the release script. The build-input record contains digests, not raw values;
it is made from the same temporary defines file passed to Flutter. Candidate
creation rejects Android build-name or number overrides that differ from the
source version.
Build-input recording, candidate creation and promotion verification also read
the AAB's compiled base Android manifest. Its actual package, `versionName` and
`versionCode` must equal the source; the candidate records their readback and
the compiled manifest SHA-256. Missing, duplicate, malformed or conflicting
identity fields fail closed, including nonzero `versionCodeMajor` and disagreement
between raw and compiled attribute values.
The AAB must have valid bundle structure and a verifiable JAR signature.
`build/release-candidate.json` is generated after the AAB build and is never a
release approval.

The release owner must review the exact downloaded candidate and collect
current evidence for every required receipt ID defined in
`scripts/release/android_candidate_manifest.py`: `flutter_full`,
`backend_linked`, `db_clean_replay`, `db_forward_upgrade`,
`auth_postgrest_matrix`, `mobio_feature_gate`, `signed_android_device`, `store_preflight`,
`privacy_security`, `repository_protection`, `drive_access`, and
`release_operations`. A receipt is a JSON object containing `schema_version: 1`,
`check_id`, `status: "passed"`, `commit`, `artifact_sha256`,
`candidate_sha256`, `completed_at` (UTC ISO 8601), and an `https://` evidence
reference. Its `completed_at` records the review of the underlying evidence
for this candidate. Store all receipts beside the approval and list each one
in `checks` as `{ "id": "...", "file": "...", "sha256": "..." }`.
The receipts must be verified against the referenced test, device, provider,
store, access and operations records. A signed receipt is not proof that the
underlying observation is true.
The `mobio_feature_gate` receipt must reflect the integrated feature gate with
live BioPay checks required. A skipped or unavailable required child check
cannot support a passed receipt.

The separate approval JSON contains exactly `schema_version: 1`,
`candidate_sha256`, `reviewer`, `approved_at`, `track`, `release_status`,
`checks`, and `signature_hmac_sha256`. The signature is the lowercase hex
HMAC-SHA256 of the same object **without** `signature_hmac_sha256`, encoded as
UTF-8 JSON with sorted keys, no extra whitespace (`separators=(",", ":")`),
and `ensure_ascii=False`. Its key is the reviewer-controlled, base64-encoded
`MOBIO_RELEASE_APPROVAL_HMAC_KEY_B64` (at least 32 decoded bytes). Keep that key
outside this repository and outside build jobs. The reviewer must be a named
person distinct from `build_actor`; the release owner controls key issuance,
revocation and audit history. The key alone cannot enforce organizational
separation, especially while the GitHub `Mobio` environment has no protection
rules and administrators can bypass it.

After independent review, use a clean checkout at the exact candidate commit
with the matching AAB and build-input record under `build/`, and an approval
bundle outside the repository. The
approval is valid for at most seven days; the candidate is valid for at most
fourteen days. Then invoke:

```sh
MOBIO_ANDROID_CANDIDATE_MANIFEST=/private/release/release-candidate.json \
MOBIO_ANDROID_RELEASE_APPROVAL=/private/release/approval.json \
MOBIO_RELEASE_APPROVAL_HMAC_KEY_B64=<provided-through-private-secret-store> \
PLAY_RELEASE_TRACK=internal PLAY_RELEASE_STATUS=draft \
./scripts/release/upload_google_play_release.sh
```

The uploader verifies the AAB, source, package, artifact hash, receipt hashes,
check statuses, freshness, reviewer distinction and signature before it reads
Play credentials or starts an API call. Production requires an approval bound
to `track=production` and the requested status, plus the existing
`PLAY_PRODUCTION_APPROVED=true` operational flag. Direct Fastlane `deploy` and
`upload_aab` use the same gate; `build_and_deploy`, `metadata` and
`promote_to_production` are disabled because they cannot bind a separately
reviewed binary or metadata change to the upload. The enabled lanes skip
metadata, images and screenshots. A Play upload still requires
human authorization and actual store/device/provider evidence; a local gate
pass alone is not release acceptance.

## Native smoke checks

The Android release smoke command requires an authorized physical device by
default:

```sh
ANDROID_SERIAL=<physical-device-serial> ./scripts/release/smoke_android_release.sh
```

For local emulator QA, explicitly opt in:

```sh
ANDROID_SERIAL=<emulator-serial> ANDROID_SMOKE_ALLOW_EMULATOR=true \
  ./scripts/release/smoke_android_release.sh
```

The evidence records `device_type` and `physical_device_evidence`. The production
go/no-go command always disables the emulator opt-in, even if the calling shell
enables it. Neither command substitutes for authenticated workflow/device UAT.
The smoke command resolves Mobio's launcher activity and starts it directly.

Current local build evidence is in
[`local-verification-20260905.md`](../development/local-verification-20260905.md).
The subsequent [native QA report](../development/native-qa-20260906.md) records
the country-picker fix, current tests, native checks, and artifact updates.
The May `go-no-go.md` report is historical; apply the dated product approvals
listed in `AGENTS.md` when interpreting its older scope statements.
