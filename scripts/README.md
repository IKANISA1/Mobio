# Scripts

Production script groups:

- `admin/`: privileged administrative bootstrap utilities.
- `ci/`: verification gates used locally and by GitHub Actions.
- `lib/`: shared Flutter/Dart selection and public runtime configuration parsing.
- `tests/`: local Python tests for build helpers and architecture enforcement.
- `qa/`: local security and environment checks, including working-tree and Git
  history secret scans.
- `release/`: release build wrappers.
- `web/`: PWA and website deployment helpers.

Useful release commands:

- `scripts/ci/bootstrap_flutter.sh` prepares dependencies and generated models.
- `scripts/ci/verify_flutter.sh` checks architecture, helpers, analysis and tests.
- `python3 scripts/ci/check_repository_structure.py` validates source ownership.

- `scripts/release/build_android_release.sh appbundle`
- `scripts/release/build_android_release.sh apk`
- `scripts/release/smoke_android_release.sh`
- `scripts/qa/capture_android_uat_state.sh`
- `scripts/qa/verify_mobio_feature_readiness.sh`
- `scripts/qa/verify_biopay_live_readiness.sh`
- `scripts/qa/verify_biopay_nfc_card_uat.sh`
- `scripts/release/go_no_go_check.sh`
- `scripts/qa/scan_secrets.sh`
- `scripts/qa/check_secret_history.sh`
- `scripts/qa/preflight_secret_history_purge.sh`

Mobio integrated feature proof:

- `scripts/qa/verify_mobio_feature_readiness.sh` is the Mobio-wide feature
  readiness wrapper used by the final go/no-go gate. It covers shell/scope,
  privacy/discoverability, wallet/tokens/subscriptions/Mobio Plus, scheduling,
  public transport, admin, reports/blocks, notifications, and BioPay as one
  feature inside the Mobio app.
- Set `RUN_MOBIO_CONTRACT_TESTS=false` only for local debugging when the broader
  Flutter gate already proved contract tests in the same run.
- Set `RUN_MOBIO_BIOPAY_FEATURE_GATE=false` only for local debugging when the
  BioPay feature gate was already proved in the same run.

BioPay feature proof:

- `scripts/qa/verify_biopay_live_readiness.sh` runs static repo checks for the
  restored BioPay QR, NFC, face enrollment, face scan, admin Ops, and USSD-only
  payment boundary as one feature of Mobio. It writes evidence under
  `docs/release/evidence`.
- Set `REQUIRE_BIOPAY_FACE_LIVE=true` with `BIOPAY_FACE_HEALTH_URL`, a verified
  `BIOPAY_AUTH_TOKEN`, and `SUPABASE_ANON_KEY` to inspect authenticated model,
  index, database, route and acceptance readiness. Server-only configuration is
  `FACE_SERVICE_URL` and `FACE_SERVICE_TOKEN`; no face-related AWS secrets.
- See `docs/product/face-ussd-20260920/APPROVAL.md` for the current scope.
- Set `REQUIRE_BIOPAY_DEVICE_LIVE=true` with an unlocked authorized Android
  device to prove installed camera/NFC permissions and tel: USSD dialer
  capability.
- Set `REQUIRE_BIOPAY_LIVE=true` to require all three live proofs together.
  `scripts/release/go_no_go_check.sh` enables this strict mode through the
  Mobio integrated feature gate by default unless
  `RUN_MOBIO_FEATURE_GATE=false` is used in dry-run mode.
- `scripts/qa/verify_biopay_nfc_card_uat.sh` captures the NFC-card-specific
  Android evidence: installed app filters, domain verification, NFC service
  state, HTTPS/custom NFC payload resolution, and USSD dialer handoff. Set
  `NFC_UAT_MANUAL_SECONDS=90` or higher to capture a timed physical card
  write/read/optional-lock session with logcat, window state, and screenshot.
  Add `NFC_UAT_REQUIRE_MANUAL=1` when a physical card must be treated as a
  hard gate; the script then requires a Mobio-started manual phase, tag
  detection, write verification, final dialer handoff, and no fatal app errors.

Final go/no-go requires external Play and Google/Firebase evidence paths:

- `PLAY_SERVICE_ACCOUNT_RETENTION_EVIDENCE`
- `PLAY_CONSOLE_UPLOAD_EVIDENCE`
- `GOOGLE_MAPS_SERVER_SECRET_EVIDENCE`
- `FCM_HTTP_V1_SECRET_EVIDENCE`
- `IOS_FIREBASE_APNS_EVIDENCE` when the release target includes iOS
- `IOS_CRASHLYTICS_SYMBOLS_EVIDENCE` when the release target includes iOS

Use a real non-template evidence file in `docs/release/evidence`. The Play
service-account gate is cleared by owner-approved retention/use evidence:
`PLAY_SERVICE_ACCOUNT_RETAINED=true` with
`PLAY_SERVICE_ACCOUNT_RETENTION_EVIDENCE`. The Google/Firebase gates are
cleared by validation acknowledgements plus existing non-template evidence
files. Do not commit secret values, API keys, private keys, service-account JSON,
or credential screenshots.

Do not move existing script paths without updating GitHub Actions and README commands in the same change.
