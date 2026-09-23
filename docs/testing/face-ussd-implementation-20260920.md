# Face-to-USSD implementation evidence — 20 September 2026

## Status and scope

The supplied implementation package is implemented in the local checkout. The
production feature remains disabled until deployment, recognition-policy and
operator acceptance are evidenced. No deployment or money transfer is claimed.

Owner authorization and the supplied source documents are preserved in
[`docs/product/face-ussd-20260920`](../product/face-ussd-20260920/APPROVAL.md).
The starting commit was `9e21d3dc4939eafe52f23fe4fe5cd43f3620b415` on `main`, with
existing uncommitted mobile review work. That work was retained. This change
does not implement face-only account registration/login: WhatsApp authentication
remains authoritative; an existing recipient account can opt into face discovery.

The intended implemented journey is:

1. Recipient selects an owned, active receiving MoMo method, explicitly opts in
   and captures one still. The receiving number may differ from the login number.
2. Backend reserves a revision and cleanup intent before writing an embedding.
   The enrollment becomes active only after the model-specific index can search it.
3. A signed-in payer, with no face enrollment requirement, captures the recipient.
   The authenticated backend applies the accepted matching policy and resolves
   the recipient's current selected receiving method and route version.
4. Android stops the camera and opens the amount-free USSD route once through
   the existing ACTION_DIAL bridge. MoMo owns recipient confirmation, amount and
   PIN. Match/dialer opening never establishes a payment or payment success.

## Implemented changes

| Layer | Implementation |
|---|---|
| Auth/session | `requireAppUser` validates the exact bearer with Auth and exposes its actual session claim. SQL enforces session/user ownership, expiry and verified WhatsApp account authority. Existing per-user limits remain. |
| SQL lifecycle | Forward migrations `20260920150000`, `20260920150100`, `20260920150200`; explicit receiving-method binding/version, consent, idempotency/request digest, revisions, pending activation, replacement, pause/resume/remove, cleanup and readiness. |
| Receiving route | Shared canonical phone formatter with existing discovery; current selected active method only, provider-specific configured route, typed expiring shortcut. No login-phone fallback, monetary request, default amount or anonymous legacy bridge. |
| Face facade | Existing Edge endpoint is authenticated and delegates only inference/search to the private Worker. Structured errors, finite body/provider/DB deadlines and no raw request logging. |
| Worker/index | Authenticated Cloudflare Worker, fixed bounded container pool, version-specific cosine Vectorize namespace, dimension/metric/output checks and opaque candidates. Async insertion is not enrollment success; delete acceptance is not deletion evidence. |
| Inference | Stateless CPU OpenCV YuNet/SFace, bounded decode, EXIF orientation, one-face and quality checks, landmark alignment and finite L2-normalized 128-dimensional output. No raw-image storage, image-URL fetching, runtime model download or container database. |
| Maintenance | Existing pg_cron/pg_net/Vault pattern; recorded-session activation and explicit-ID cleanup. Old IDs cannot delete a current replacement. Observed-absent tombstones are rechecked daily for very late insertions. |
| Enrollment UI | One capture, explicit receiving-method selection and short consent; update/pause/resume/remove, processing state and method-management round trip. Changing a receiving number does not require recapture. |
| Scan UI | One upload per scan; Android handoff guarded against duplicate taps, rebuild, resume, backgrounding, account changes and stale responses. No-match offers retry/manual/QR, never enrollment of the payer. |
| Camera | Ownership generations, bounded initialization/capture/disposal, no audio, late capture-file cleanup. Camera stops before network resolution/handoff and before opening manual/QR/method-management routes; return never restarts it automatically. |
| Platforms/accessibility | Honest copy alternative on iOS/web/desktop; EN/FR/RW task/error strings; narrow-screen, 200% text, named control and 48px target checks. Existing design components retained. |
| Admin | OpenCV provider labels; configured, model-loaded, compatible-index, database-contract and acceptance evidence separated. Shortcut preparation rate is an operational metric, not recognition accuracy. Existing historical request records remain historical. |
| AWS migration | Active Rekognition/signing/liveness adapter and fallback removed. Legacy active/paused enrollment becomes re-enrollment-required; old callable face RPC grants revoked by forward migration. Remote deletion and secret revocation have not occurred. |

The [changed-file manifest](face-ussd-changed-files-20260920.txt) lists this
implementation's source, configuration, tests, docs and scoped visual baselines.
Native Android handoff code was reused, not replaced with ACTION_CALL.

## Reproducible model contract

See [`model-manifest.json`](../../services/face-inference/model-manifest.json)
for immutable artifact URLs, preprocessing, hashes and source commit
`47534e27c9851bb1128ccc0102f1145e27f23f98`.

- YuNet `face_detection_yunet_2023mar.onnx`, MIT notice retained;
  SHA-256 `8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4`.
- SFace `face_recognition_sface_2021dec.onnx`, Apache-2.0 notice retained;
  SHA-256 `0ba9fbfa01b5270c96627c4ef784da859931e02f04419c829e83484087c34e79`.
- `opencv-python-headless==4.11.0.86`, NumPy 2.2.6 and Pillow 11.3.0 are
  pinned with dependency hashes. Python 3.12.13 slim-bookworm base is pinned
  to manifest digest `sha256:4766d8b510c428e595d74b9cc5bbb2fae8e26316fffb4adc89908d79aacd58a2`.
- Model version `yunet2023mar-sface2021dec-opencv4.11-v1`; BGR uint8,
  longest side at most 1024, YuNet five landmarks, `alignCrop`, normalized
  128-dimensional embedding, cosine search. Maximum upload 1.5MB and decoded
  image 4MP. One CPU thread and serialized mutable model execution.

The policy is deliberately disabled with no invented match threshold. The
maintained `evaluate.py` requires a consent-attested cohort, separate enrollment
and probe captures, unknown probes and explicit policy parameters. No people's
faces were harvested or used in evaluation during this implementation.

## Local verification

Evidence logs are in `build/qa/face-ussd-20260920/` (local generated artifacts).
Flutter 3.44.3/Dart 3.12 were used. Public runtime defines were supplied through
the existing build scripts; no `.env`, private key or token was added to Git.

| Check | Observed outcome | Evidence |
|---|---|---|
| Dart analysis | Pass, no issues | `analyze-final.log` |
| Flutter functional/regression suite | 812 passed across 104 test files; excludes the standalone whole-app reference-golden suite | `flutter-functional-verified.log` |
| Final camera/navigation regression | 31 passed after the final lifecycle fix; includes 3 new manual/QR/method-management camera-stop cases | `face-lifecycle-final.log` |
| Scoped visual baselines | 12 reviewed face enrollment/scan, profile and BioPay admin mobile/desktop captures passed | `face-golden-tests.log`, `face-visual-final/` |
| Real PostgreSQL/PostgREST contract | Pass on PostgreSQL 17.11/PostgREST 16.3; migrations execute and real HTTP RPCs verify session, selected-number A/B binding, payer independence, edits, replacement, ambiguity, pause/remove, route failure, no amount row, cleanup and legacy revocation | `database-tests.log` |
| Deno Edge suite | 123 passed, 0 failed, 1 ignored by existing suite | `deno-full-tests.log` |
| Worker | 7 tests passed; TypeScript check and standalone esbuild bundle passed | `worker-tests.log`, `worker-analysis.log`, `worker-bundle.log` |
| Actual OpenCV + HTTP | 8 passed with real pinned models: loading, actual embedding/detection execution, structured no-face response, normalization, pixel/upload limits and no arbitrary URL fetch | `model-tests.log` |
| Android OS intent | Physical Pixel 4a/Android 13 opened the user-supplied route with its final `#`; closed with Back, no Call/SIM/PIN/transfer | `device-dialer-check.json` |
| Android release APK | Pass, 92,565,207 bytes; APK v2 signature verifies; not installed or submitted | `android-release-verified.log`, `apk-build.json`, `apk-signature.log` |
| Web review preview | Pass; rebuilt once after the complete batch and inspected in Codex at 390×844 | `build/ui-review-20260920/comment-batch-14/build-result.json`, `browser-review.json` |
| Secret/structure/whitespace checks | Pass; repository structure covers 2076 source/document files | `secret-scan.log`, `repository-structure.log`; `git diff --check` |

The database fixture uses the relevant historical BioPay migrations plus the
three new migrations and a minimal Auth schema. It proves actual SQL/RPC
behavior, not compatibility with an uninspected production schema. Its synthetic
score values test authority; they are not calibrated recognition thresholds.

The model tests execute the models using synthetic/blank inputs and controlled
alignment fixtures. They establish functioning model/runtime plumbing, not
real-person recognition accuracy. A successful host smoke is not a successful
Linux container-image smoke.

The first whole-app Flutter run reported 161 image-reference differences plus
two old text expectations. The text expectations were updated to the authorized
UI behavior. Only the 12 scoped face/profile/admin image baselines were reviewed
and updated. The remaining whole-app visual differences from the broader mobile
review work have not been accepted, and the entire reference-golden suite is
not claimed green. The functional suite was rerun separately in full.

One intermediate test/build run exhausted disk space. Only identified disposable
Mobio compiler/test directories and older generated preview backups were removed;
source, current preview, latest backup and evidence receipts were retained.
The interrupted run is not counted as a pass.

Release APK: `build/app/outputs/flutter-apk/app-release.apk`; SHA-256
`e115ab8c1293511b99e3f8e72c7b0eae4bb670e3024c4593147c81ee7752cf97`.
The release script used the four required public runtime values recovered from
the checkout's existing compiled preview because this recovered checkout has no
`.env`. That proves a correctly configured build, not live backend availability.
Gradle reported an existing future Kotlin-plugin migration warning; it did not
prevent this build. No signing material was changed or exposed.

In the refreshed browser preview, enrollment exposed a named receiving-method
selector, unchecked consent and a disabled camera action until prerequisites.
The sample method selection appeared correctly; method management opened and
Back returned to enrollment. Scan Back returned to BioPay; the Profile tab
exposed the registration entry. Admin displayed OpenCV and separate
Not ready/No/Not observed/Not recorded status fields. These are explicitly
labelled local sample-data views, not deployed observations. No browser camera,
biometric upload, real consent record or remote enrollment was performed.

Review entry: `http://127.0.0.1:64152/review.html?screen=biopay_face_enroll`.
The screen menu also includes Scan to pay, Receiving methods and BioPay admin.

## Commands

From the repository root, select the intended Flutter 3.44/Dart 3.12 SDK:

```sh
"$FLUTTER_BIN" test --no-pub --concurrency=2 --reporter expanded
"$DART_BIN" analyze
deno test --allow-env --allow-net --allow-read supabase/functions
PG_BIN=/path/to/postgres/bin POSTGREST_BIN=/path/to/postgrest python3 scripts/qa/test_face_ussd_db.py
FLUTTER_BIN=/path/to/flutter scripts/release/build_android_release.sh apk
scripts/qa/scan_secrets.sh
python3 scripts/ci/check_repository_structure.py
git diff --check
```

The general Flutter command includes the still-open whole-app reference goldens.
To reproduce the passing functional selection, enumerate `test/**/*_test.dart`
and exclude only `revolut_reference_golden_test.dart`. The final scoped test
command is `flutter test --no-pub test/features/biopay/face_shortcut_widgets_test.dart
test/features/biopay/face_capture_test.dart test/features/biopay/face_shortcut_test.dart`.

From `cloudflare/face-service`: `pnpm install --frozen-lockfile`, `pnpm test`,
`pnpm check`; `pnpm build` additionally needs a working Docker daemon.
See the [inference README](../../services/face-inference/README.md) for hashed
dependency/model installation, host tests, container and cohort commands.

## Checks not completed and release gates

1. **Linux container image:** Docker daemon did not answer bounded `docker info`
   calls; Wrangler image build could not complete. Actual host inference passed,
   but the pinned image must still build and pass HTTP health/embed smoke.
2. **Deployment:** no Cloudflare Worker/Container/Vectorize deployment, target
   Supabase migration, Edge deployment, Vault/cron setup or deployed secret
   change was performed. Check the complete target schema and authenticated
   deployed health before enabling any user flow.
3. **Recognition acceptance:** no consented representative cohort was supplied.
   There are no measured wrong-recipient, no-match, ambiguity, latency or
   recognition-accuracy results. Calibrate, freeze, independently accept and
   record the model policy before enabling it.
4. **Operator/full app device acceptance:** the OS-level ACTION_DIAL check does
   not prove a new-app scan-to-dialer flow, receiving-number B on-device, current
   MoMo prompts or dual-SIM selection. No operator session or transfer was
   started. The draft route stays disabled pending attended validation.
5. **Physical accessibility/platforms:** widget checks passed; real TalkBack,
   permission interruption and iOS/web/desktop capability acceptance remain.
6. **Production data location and AWS retirement:** processing/storage regions,
   retention arrangements, named AWS inventory/deletion and secret revocation
   require the operator sequence. Historical migrations/evidence were preserved.
7. **Release/whole-system QA:** no CI, store submission, deployed release or owner
   acceptance is implied; unrelated whole-app golden differences remain open.

The [device acceptance checklist](face-ussd-device-acceptance.md) maps every
specified acceptance case to local and live evidence. The
[deployment/re-enrollment/AWS retirement runbook](../operations/face-ussd-runbook.md)
contains the remaining operational steps and rollback. Rollback disables face
discovery while keeping manual/QR journeys; it does not restore AWS fallback.
