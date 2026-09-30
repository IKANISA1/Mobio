# M075: PWA candidate and promotion controls

Date: 2026-09-30. Scope: the repository's Cloudflare Pages publishing paths and
the inventory of shipped service publishing commands. Local implementation and
fixture verification are complete for these paths. No provider deployment,
production candidate, independent release approval or hosted CI acceptance was
performed by this work.

## Changed paths and purpose

| Path | Change and reason |
| --- | --- |
| `.github/workflows/cloudflare-pwa.yml` | Runs full Flutter analysis/tests, required linked-backend checks, current hardening-source checks and PWA packaging/worker checks. Uploads the prepared combined site and candidate after success; contains no Cloudflare publish step or API token. A failed/unavailable baseline prevents candidate upload. |
| `.github/workflows/cloudflare-pages.yml` | The legacy manual entrypoint delegates to the same combined candidate workflow. It cannot replace the combined app/admin site with a standalone landing deployment. |
| `scripts/web/deploy_cloudflare_pwas.sh` | Requires explicit arguments and delegates to the approval verifier's promotion command. It does not build, install a tool or use legacy positional defaults. |
| `scripts/web/pwa_candidate_manifest.py` | Records source/artifact/destination identity, verifies independent authenticated approval and every mandatory receipt, then stages and deploys unchanged verified bytes. Both direct Python invocation and shell invocation use this control. |
| `scripts/tests/test_pwa_candidate_manifest.py` | Exercises candidate creation, verification and the real shell entrypoint using an actual packaged/stamped synthetic site and a fake publishing adapter. |
| `test/release/admin_panel_production_readiness_contract_test.dart` | Updates the two Cloudflare workflow assertions to require full checks, candidate upload and separate controlled promotion. Existing admin routing/catalog/pagination/design assertions remain. |

## Exact artifact and source binding

The candidate contains schema/kind, UTC creation time, builder/run identity,
destination and source. Source records the clean full Git commit/tree, pubspec
version, hardening manifest SHA-256, Face model policy SHA-256, packaged release
identity and complete prepared site inventory. An inventory row records relative
filename, byte size and SHA-256. The artifact digest hashes the sorted canonical
JSON inventory, including `release.json`, the worker, association files, current
assets and any retained preceding asset cohort.

The release stamp must name the current clean commit and contain the exact file
hashes emitted by `stamp_bundle.py`: all prepared files except `release.json`.
The stamper initially excludes the worker while computing its release identity,
then inserts the stamped worker hash into `release.files`; the verifier respects
this shape. Packaged Pages and service workers must match current tested source.
The existing `verify_pwa_bundles.sh` validates the full app/admin/landing contract
at both candidate creation and promotion verification.

Inputs are bounded: at most 20,000 files/directories, 256 MiB per file, 1 GiB total
site bytes, and 8 MiB per JSON record. Symlinks in any path component, hard-linked
files, FIFOs/nonregular entries, duplicate JSON keys, nonfinite JSON, unsafe
receipt paths and unexpected schema fields are rejected. Regular reads check
file identity and size/time stability. Example approval/candidate/receipt files
are ineligible.

The manifest contains no raw credential or client configuration values. The
existing builder supplies all four required public runtime values through the
private Dart defines file. Actual compiled behavior and observations are part of
the artifact-bound review receipts; manifest generation alone does not establish
their truth.

## Mandatory approval and receipts

The immutable required check set contains twelve checks:

- `flutter_full`
- `backend_linked`
- `db_clean_replay`
- `db_forward_upgrade`
- `auth_postgrest_matrix`
- `mobio_feature_gate`
- `pwa_bundle`
- `pwa_browser`
- `privacy_security`
- `repository_protection`
- `drive_access`
- `release_operations`

No environment flag or caller-supplied subset can remove a check. Each receipt
must have `status: "passed"`. Failed, skipped, unavailable and not-applicable
substitutes are non-releasable. Android signed-device/store checks are not PWA
checks; the PWA requires its own bundle and browser observations.

Approval JSON has exactly `schema_version`, `candidate_sha256`, `reviewer`,
`approved_at`, `destination`, `checks`, `signature_hmac_sha256`. Each check pointer
contains exactly `id`, `file`, `sha256`, with an approved relative regular-file
path inside the approval bundle. Each pointed-to receipt has exactly
`schema_version`, `check_id`, `status`, `commit`, `artifact_sha256`,
`candidate_sha256`, `destination`, `completed_at`, `evidence_ref`.

`destination` contains the exact independently supplied `account`, `project`,
`branch`, `environment` strings. All candidate, approval and receipt destinations
must equal the requested destination. The same applies to exact commit,
artifact and candidate hashes. Observation references must be HTTPS URLs.

Candidates expire after 14 days. Approvals expire after 7 days, cannot predate
candidate creation, and require a named reviewer distinct from the builder
(case-insensitive). Each receipt must complete between candidate creation and
approval. Future time tolerance is five minutes. Approval signatures use
HMAC-SHA-256 over canonical UTF-8 JSON excluding `signature_hmac_sha256`, with
sorted keys, compact separators and `ensure_ascii=False`. Verification requires
the separately managed, base64-encoded key in
`MOBIO_PWA_RELEASE_APPROVAL_HMAC_KEY_B64` (at least 32 decoded bytes). The verifier
does not create approvals or claim to validate the factual truth of observations.

## Promotion invocation

After independent review has produced the real approval bundle, the supported
invocation consumes the existing unchanged prepared site:

```bash
./scripts/web/deploy_cloudflare_pwas.sh \
  --site build/pwa/site \
  --candidate build/pwa-candidate.json \
  --approval /path/to/review-bundle/approval.json \
  --account "$CLOUDFLARE_ACCOUNT_ID" \
  --project "$CLOUDFLARE_PAGES_PROJECT_NAME" \
  --branch main --environment Mobio
```

No deployment was run with this command during implementation. The gate requires
an available Cloudflare deployment credential and a reviewed local Wrangler
4.135.0 after validating all evidence. It uses `npx --no-install`; it cannot fetch
a replacement tool. It copies the prepared site to a private directory, checks
the complete staged tree digest again, makes the staged files/directories read
only and invokes Wrangler with the verified account/project/branch. The approval
key is removed from the child process environment. Staging is cleaned after
success or failure. Deployment failure is reported as failure.

## Service publishing inventory

Read-only search covered `.github/workflows`, `scripts`, `cloudflare` and
`services`, excluding generated outputs and vendor dependencies. The only
shipped real Cloudflare publisher was the Pages script/workflow now controlled
above. `cloudflare/face-service/package.json` exposes a build command
`wrangler deploy --dry-run --outdir dist`; it packages a worker and does not
publish it. `services/face-inference/Dockerfile` builds an image but exposes no
repository push/deploy entrypoint. No shipped Supabase function deployment,
database push or service-image publishing script/workflow was found. Therefore
no service publisher was activated or invented here. A future repository service
publisher must add its own exact artifact/destination and applicable required
receipts before becoming usable. Generic provider CLIs operated outside these
repository entrypoints are outside this inventory.

## Earlier PWA implementation verification

- The earlier scoped PWA run passed **36 Python tests**: 35 candidate/promotion cases plus the existing real
  packaging test. The positive case prepares the site through the real
  packager/stamper, verifies twelve synthetic signed receipts and runs the real
  shell promotion with a fake publishing adapter. The adapter records the exact
  staged artifact hash/destination, read-only staging and absence of the approval
  key. Negative cases block before that adapter can publish.
- Negative coverage includes every missing gate; failed/skipped/unavailable
  statuses; missing files/keys; stale/future/pre-candidate times; wrong artifact,
  source, candidate or each destination field; self approval; tampered hashes and
  signature; examples/unsafe paths/schema/flags; dirty or different clean source;
  modified/added/missing site bytes; symlink/hardlink/FIFO/oversized inputs;
  forged restamped worker/routing contracts; unreviewed tools; absent deployment
  credentials; and the retired positional shell invocation.
- The earlier scoped Flutter run passed **7 admin readiness contract tests**. Focused Dart analysis:
  **No issues found**. Shell syntax and Python compilation passed.
- Repository structure check: **2,984 source/document files; Flutter 3.44.3** at
  the pre-report check. Secret-pattern scan and `git diff --check` passed.

Logs: `/tmp/mobio-m075-pwa-final-tests.log`,
`/tmp/mobio-m075-pwa-dart-contract-tests.log`,
`/tmp/mobio-m075-pwa-analyze.log`, `/tmp/mobio-m075-pwa-structure.log`,
`/tmp/mobio-m075-pwa-secret-scan.log`. Full-repository integrated checks and the
aggregate seven-item completion evidence are owned by the aggregate report.

## Promotion-scope review and closeout corrections

The source review covered the shipped Android Play uploader, both direct
Fastlane upload lanes and both Pages workflow entrypoints. Android candidates
inspect the actual compiled base manifest and bind its package/version to source
and build inputs. Pages workflow entrypoints build candidates; Pages promotion
verifies the prepared tree through the gated script. The service inventory above
remains build/dry-run only. This inventory covers the existing repository
promotion entrypoints; independent use of generic provider CLIs is outside it.

This review found one concrete Android reviewer-separation defect: a correctly
signed approval naming `BUILD-BOT` was accepted for builder `build-bot`. Android
now uses a case-insensitive comparison, matching the PWA verifier, and the new
negative regression retains complete matching receipts and a valid signature.
The earlier Android manifest/production-gate run passed 31 manifest tests and
36 promotion-gate tests, including compiled identity fixtures. Those counts are
historical scoped receipts and overlap the later suites below. Log:
`/tmp/mobio-m075-android-reviewer-final-tests.log`.

### Fastlane artifact preservation

Closeout review found that the verifier could approve the original build path,
then replacement bytes at that path could reach `deploy` or `upload_aab`.
`android/fastlane/Fastfile` now captures the verifier's immutable JSON receipt,
requires its success status, requested track and lowercase SHA-256 digest, and
opens the source without following symlinks or blocking on a FIFO. A regular
source is copied into an exclusive file in a private temporary directory. Its
digest must equal the approved digest before credential access/upload. Both lanes
upload only this copy, made read only, and remove staging after success or any
failure. Replacing the writable build path during upload cannot change the
staged artifact.

**14 executable Fastlane cases passed** in
`scripts/tests/test_fastlane_approved_artifact.py`. They execute both actual Ruby
lane blocks with synthetic verifier/upload adapters. Coverage includes approved
bytes and track binding, absent/rejected/malformed approval receipts, replacement
after verification, original-path replacement during upload, symlink/FIFO inputs,
credential/upload errors, staging cleanup and retired lanes. **36 production-gate
tests passed** after the correction. Ruby/Bash syntax, Python compilation,
secret-pattern scan and whitespace checks passed in this scoped verification.
Logs: `/tmp/mobio-closeout-fastlane-tests.log`,
`/tmp/mobio-closeout-fastlane-production-gates.log`,
`/tmp/mobio-closeout-fastlane-secret-scan.log`.

### Strict Android archive signatures

The Android validator now runs `jarsigner -verify -strict` with fixed English
diagnostics. A plain successful exit can accept added unsigned entries; strict
verification and a narrow diagnostic allowlist reject unsigned additions,
tampered signed bytes, expired/future certificates and weak/disabled algorithms.
Strong complete Android archives signed by a self-signed certificate remain
eligible for candidate verification. Only the expected trust-path warnings are
allowed; unavailable tools, timeouts or unrecognized diagnostics fail closed.
This verifies archive coverage and signature mechanics; trusted signer provenance
is still a separate release requirement.

**42 Android candidate-manifest tests passed** in
`scripts/tests/test_android_candidate_manifest.py`: the earlier 31 cases plus
11 closeout regressions. The new cases include seven real ephemeral signed
archive fixtures and four tool/diagnostic cases. Temporary signing material was
removed. Python syntax, secret-pattern scan and whitespace checks passed. Log:
`/tmp/mobio-signature-closeout-tests.log`.

Full-repository integrated results and source publication are recorded in
`docs/reports/mobio-local-readiness-goal-2026-09-30.md`. Scoped suites above overlap
that run and must not be added to its totals. Synthetic approvals and provider
adapters establish local control flow and byte preservation; this work produced
no production candidate, provider deployment, Play acceptance or independent
release approval.

Android example-file completion: otherwise valid candidate and approval names
ending `.example.json` are now rejected, matching the existing example-receipt
restriction. Two reproducing tests failed before correction; all 34 current
candidate/compiled-manifest cases passed afterward, including three example
negatives. The Android module now has 45 cases; current integrated results are
recorded in the aggregate readiness report.

The final-source helper suite passed all 500 tests in 778.310 seconds, including
all 45 Android validator/signature cases. Focused results above overlap that
total; full Flutter integration is reported separately in the aggregate.
