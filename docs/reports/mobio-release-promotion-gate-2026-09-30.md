# Mobio Android candidate and promotion gate — 30 September 2026

This is a source and local-test record for M075 and M081 in the
[production-readiness register](mobio-production-readiness-remaining-tasks-2026-09-29.md).
It is not a signed release, Play upload, hosted CI pass, or G08 approval.

## Files added and why

| File | Reason |
| --- | --- |
| `scripts/release/android_candidate_manifest.py` | Produce a candidate JSON only after a structurally valid, JAR-signed AAB exists. Bind exact commit/tree, source version/package, twelve installed hardening migration hashes, model manifest hash, build-input record and AAB hash. Verify actual package/version equality from the compiled base Android manifest during build-input recording, candidate creation and promotion verification. Require a separate fresh HMAC-signed approval with a distinct named reviewer, compared without case differences, and all twelve artifact-bound check receipts before upload. Reject stale, altered and wrong-package inputs. |
| `scripts/tests/test_android_candidate_manifest.py` | Exercise approval success in a disposable synthetic repository and failures for dirty source, unsigned/tampered AAB, changed public build inputs, version override, unreviewed build environment, shortened/wrong commit, wrong package or track, stale candidate, missing or skipped receipts, same builder/reviewer, invalid approval signature and absent key. A real AAPT2 synthetic compiled manifest and negative protobuf fixtures also prove actual identity equality and reject missing, malformed, duplicate, wrong or conflicting identity, even when a changed artifact's build record and approval are rebound. The synthetic receipts do not establish real device, provider or store readiness. |
| `scripts/tests/test_google_play_upload_receipt.py` | Run the actual shell upload fallback with executable local gcloud/curl fakes. Prove that only the approved positive integer version receipt permits a track update and commit; missing, wrong, mistyped, malformed, duplicate and noncanonical replies stop beforehand. Approval is a clearly marked synthetic gate in this isolated receipt fixture; cryptographic and compiled-artifact approval verification remain covered by the manifest suite. No provider connection or real upload occurs. |
| `docs/reports/mobio-release-promotion-gate-2026-09-30.md` | Record the changed files, local verification, release limits and outstanding evidence for review. |

## Existing files changed and why

| Files | Reason |
| --- | --- |
| `.github/workflows/release.yml`, `.github/workflows/android-release.yml` | Build and upload signed AAB plus candidate and build-input records as GitHub artifacts. Remove automatic Google Play uploads and GitHub Release publication. Keep required Flutter, linked backend, signing and secret-history validation. Remove Play credentials from candidate jobs and reduce `contents` permission to read. |
| `scripts/release/build_android_release.sh` | Record the four public build-value digests, named environment, source/package/build version, target options and AAB hash from the same temporary Dart defines file passed to Flutter. Raw public values stay out of the artifact record. |
| `scripts/ci/verify_release_config.sh`, `scripts/release/go_no_go_check.sh` | Let candidate builds validate signing without a Play service-account credential; keep that credential mandatory in the production go/no-go invocation. |
| `scripts/release/upload_google_play_release.sh`, `android/fastlane/Fastfile` | Reject missing or invalid artifact-bound approval before Play credentials or network access. Direct Fastlane deploy and internal AAB lanes invoke the same verifier. The gcloud/curl fallback requires the successful upload receipt's versionCode to be a canonical positive int32 integer equal to the approved source/compiled-AAB version before updating or committing a track. Retire immediate build-and-upload, metadata-only upload, and direct track promotion paths. Skip unreviewed metadata, screenshot and release-note upload. |
| `scripts/tests/test_production_gates.py`, `test/release/scope_boundary_test.dart` | Assert the candidate workflows contain no publishing action, the manifest is produced between build and artifact upload, signing validation does not require Play credentials, and an unapproved upload stops before any external tool. Update the Dart release contract to the candidate-only behavior. |
| `docs/release/README.md`, `android/fastlane/README.md` | Describe candidate, receipt, approval, key-custody and upload contracts. |
| `docs/release/google-play-submission.md`, `docs/release/google-play-sensitive-permissions-2026-06-21.md` | Mark old Play claims and upload directions as dated evidence; point to the current candidate/approval gate. |

## Local verification

- Final candidate manifest unit tests: 31 passed, including real `jarsigner` rejection of an unsigned synthetic AAB, actual compiled-manifest readback, malformed/wrong-identity fixtures, independently rebound input/approval rejection, and same-actor reviewer rejection despite case differences. The positive fixture was generated locally by Android SDK AAPT2 36.0.0 using `--proto-format` and contains no signing material or runtime secrets.
- Final manifest and production-gate rerun: 31 manifest tests and 36 promotion tests passed (`/tmp/mobio-m075-android-reviewer-final-tests.log`). Python bytecode compilation, secret-pattern scan, repository structure and whitespace checks also passed after the compiled-manifest validator changes.
- Final Play upload receipt suite: 9/9 passed (`/tmp/mobio-play-upload-receipt-tests.log`). The real shell entrypoint confirms one correct integer receipt, rejects all tested unusable/mismatched acknowledgements before track PUT/commit, and retains the approval-before-provider ordering. Bash syntax and Python compilation passed. These tests are separate from the 67-test manifest/promotion run above. The required receipt type follows the official [Google Play Bundle resource](https://developers.google.com/android-publisher/api-ref/rest/v3/edits.bundles); a JSON success response for a different version cannot authorize promotion of that version.
- Earlier workflow validation: Bash syntax, Fastlane Ruby syntax, pinned Actions, repository structure, secret-pattern scan and `git diff --check` passed.
- Earlier pinned Dart 3.12 static analysis: exit 0 with 92 info-level findings. Earlier focused Flutter release scope test: 16 passed. Current repository-wide results are recorded in the aggregate local-readiness report.
- Earlier full pinned Flutter suite: exit 1, 969 passed and 152 reference-golden failures. This matches the known unresolved M076 baseline; no visual baseline was silently updated.
- Approved Android release script stopped before compilation because `.env` and all four required public build values are absent. No AAB or Play upload was produced.

## Required evidence still open

- Actual compiled AAB package/version equality is now an enforced local validator gate. The dependency-free, size/field-bounded protobuf reader follows the official [AOSP AAPT2 Resources.proto schema](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/tools/aapt2/Resources.proto), cross-checks raw and compiled values and Android identity attribute IDs, and records a compiled-manifest digest. A missing/malformed/ambiguous manifest, different package/name/code or nonzero major version cannot be promoted. Existing candidates without the new readback must be recreated. A real signed candidate has not been built because private release configuration is unavailable; trusted provenance of signing and the named environment remains required for M081/G08.
- All twelve check receipts must come from real, current tests and independent review; HMAC authenticates the approval file, not the truth of its referenced observations. Reviewer key custody, environment protection, and named promotion roles remain open under M080. Existing GitHub Actions runs fail before jobs start, and the private free-plan protection API returned 403 in the prior readback.
- M076 full Flutter reference goldens, M077 hosted CI, M078 forward-upgrade rehearsal, M079 hosted Auth/PostgREST, M002 trusted signing provenance, M044–M050 physical Android/Play checks, and G06/G08/G10 acceptance remain open. The Drive permission readback at 22:36 UTC on 29 September still showed `anyone` as `reader` on folder `120JIOTyeNX6nHaHPDqS3UgbaTWyJAE57`; M001 awaits the user's access change and a fresh folder/child review.
- Paid transport, institutional SMS and Face-USSD remain outside this candidate's enabled features until their own dated approval and acceptance gates pass.

**Decision: NO-GO for production promotion.** The added controls prevent the
repository's automatic Play/GitHub release paths and make manual Play uploads
require a matching approval, while the external evidence and release authority
remain outstanding.
