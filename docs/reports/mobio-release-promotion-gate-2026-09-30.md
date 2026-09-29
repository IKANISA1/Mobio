# Mobio Android candidate and promotion gate — 30 September 2026

This is a source and local-test record for M075 and M081 in the
[production-readiness register](mobio-production-readiness-remaining-tasks-2026-09-29.md).
It is not a signed release, Play upload, hosted CI pass, or G08 approval.

## Files added and why

| File | Reason |
| --- | --- |
| `scripts/release/android_candidate_manifest.py` | Produce a candidate JSON only after a structurally valid, JAR-signed AAB exists. Bind exact commit/tree, source version/package, twelve installed hardening migration hashes, model manifest hash, build-input record and AAB hash. Require a separate fresh HMAC-signed approval with a distinct named reviewer and all eleven artifact-bound check receipts before upload. Reject stale, altered and wrong-package inputs. |
| `scripts/tests/test_android_candidate_manifest.py` | Exercise approval success in a disposable synthetic repository and failures for dirty source, unsigned/tampered AAB, changed public build inputs, version override, unreviewed build environment, shortened/wrong commit, wrong package or track, stale candidate, missing or skipped receipts, same builder/reviewer, invalid approval signature and absent key. The synthetic receipts do not establish real device, provider or store readiness. |
| `docs/reports/mobio-release-promotion-gate-2026-09-30.md` | Record the changed files, local verification, release limits and outstanding evidence for review. |

## Existing files changed and why

| Files | Reason |
| --- | --- |
| `.github/workflows/release.yml`, `.github/workflows/android-release.yml` | Build and upload signed AAB plus candidate and build-input records as GitHub artifacts. Remove automatic Google Play uploads and GitHub Release publication. Keep required Flutter, linked backend, signing and secret-history validation. Remove Play credentials from candidate jobs and reduce `contents` permission to read. |
| `scripts/release/build_android_release.sh` | Record the four public build-value digests, named environment, source/package/build version, target options and AAB hash from the same temporary Dart defines file passed to Flutter. Raw public values stay out of the artifact record. |
| `scripts/ci/verify_release_config.sh`, `scripts/release/go_no_go_check.sh` | Let candidate builds validate signing without a Play service-account credential; keep that credential mandatory in the production go/no-go invocation. |
| `scripts/release/upload_google_play_release.sh`, `android/fastlane/Fastfile` | Reject missing or invalid artifact-bound approval before Play credentials or network access. Direct Fastlane deploy and internal AAB lanes invoke the same verifier. Retire immediate build-and-upload, metadata-only upload, and direct track promotion paths. Skip unreviewed metadata, screenshot and release-note upload. |
| `scripts/tests/test_production_gates.py`, `test/release/scope_boundary_test.dart` | Assert the candidate workflows contain no publishing action, the manifest is produced between build and artifact upload, signing validation does not require Play credentials, and an unapproved upload stops before any external tool. Update the Dart release contract to the candidate-only behavior. |
| `docs/release/README.md`, `android/fastlane/README.md` | Describe candidate, receipt, approval, key-custody and upload contracts. |
| `docs/release/google-play-submission.md`, `docs/release/google-play-sensitive-permissions-2026-06-21.md` | Mark old Play claims and upload directions as dated evidence; point to the current candidate/approval gate. |

## Local verification

- Candidate manifest unit tests: 18 passed, including real `jarsigner` rejection of an unsigned synthetic AAB and build-input recording/rejection fixtures.
- Production-gate tests: 35 passed. Bash syntax, Fastlane Ruby syntax, pinned Actions, repository structure, secret-pattern scan and `git diff --check` passed.
- Pinned Dart 3.12 static analysis: exit 0 with 92 info-level findings. Focused Flutter release scope test: 16 passed.
- Full pinned Flutter suite: exit 1, 969 passed and 152 reference-golden failures. This matches the known unresolved M076 baseline; no visual baseline was silently updated.
- Approved Android release script stopped before compilation because `.env` and all four required public build values are absent. No AAB or Play upload was produced.

## Required evidence still open

- The new build-input record binds the defines supplied to the release script, but does not yet prove **actual AAB version equality** from the compiled Android manifest or establish independent provenance of the environment name. Exact artifact inspection and trusted build provenance remain necessary for M081/G08. The source pubspec version alone is insufficient.
- All eleven check receipts must come from real, current tests and independent review; HMAC authenticates the approval file, not the truth of its referenced observations. Reviewer key custody, environment protection, and named promotion roles remain open under M080. Existing GitHub Actions runs fail before jobs start, and the private free-plan protection API returned 403 in the prior readback.
- M076 full Flutter reference goldens, M077 hosted CI, M078 forward-upgrade rehearsal, M079 hosted Auth/PostgREST, M002 trusted signing provenance, M044–M050 physical Android/Play checks, and G06/G08/G10 acceptance remain open. The Drive permission readback at 22:36 UTC on 29 September still showed `anyone` as `reader` on folder `120JIOTyeNX6nHaHPDqS3UgbaTWyJAE57`; M001 awaits the user's access change and a fresh folder/child review.
- Paid transport, institutional SMS and Face-USSD remain outside this candidate's enabled features until their own dated approval and acceptance gates pass.

**Decision: NO-GO for production promotion.** The added controls prevent the
repository's automatic Play/GitHub release paths and make manual Play uploads
require a matching approval, while the external evidence and release authority
remain outstanding.
