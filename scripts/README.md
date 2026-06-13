# Scripts

Production script groups:

- `admin/`: privileged administrative bootstrap utilities.
- `ci/`: verification gates used locally and by GitHub Actions.
- `qa/`: local security and environment checks, including working-tree and Git
  history secret scans.
- `release/`: release build wrappers.
- `web/`: PWA and website deployment helpers.

Useful release commands:

- `scripts/release/build_android_release.sh appbundle`
- `scripts/release/build_android_release.sh apk`
- `scripts/release/smoke_android_release.sh`
- `scripts/qa/capture_android_uat_state.sh`
- `scripts/qa/verify_biopay_live_readiness.sh`
- `scripts/release/go_no_go_check.sh`
- `scripts/qa/scan_secrets.sh`
- `scripts/qa/check_secret_history.sh`
- `scripts/qa/preflight_secret_history_purge.sh`

BioPay recovery proof:

- `scripts/qa/verify_biopay_live_readiness.sh` runs static repo checks for the
  restored BioPay QR, NFC, face enrollment, face scan, admin Ops, and USSD-only
  payment boundary. It writes evidence under `docs/release/evidence`.
- Set `REQUIRE_BIOPAY_AWS_LIVE=true` to require AWS Rekognition provider env:
  `FACE_PROVIDER=aws_rekognition`, `AWS_REGION`, `AWS_ACCESS_KEY_ID`,
  `AWS_SECRET_ACCESS_KEY`, and `AWS_REKOGNITION_COLLECTION_ID`.
- Set `REQUIRE_BIOPAY_SUPABASE_LIVE=true` with `BIOPAY_FACE_HEALTH_URL` and
  `SUPABASE_ANON_KEY` to prove the deployed edge-function health endpoint.
- Set `REQUIRE_BIOPAY_DEVICE_LIVE=true` with an unlocked authorized Android
  device to prove installed camera/NFC permissions and tel: USSD dialer
  capability.
- Set `REQUIRE_BIOPAY_LIVE=true` to require all three live proofs together.
  `scripts/release/go_no_go_check.sh` enables this strict BioPay mode by
  default unless `RUN_BIOPAY_GATE=false` is used in dry-run mode.

Final go/no-go requires external Play evidence paths:

- `PLAY_SERVICE_ACCOUNT_ROTATION_EVIDENCE`
- `PLAY_SERVICE_ACCOUNT_RETENTION_EVIDENCE`
- `PLAY_CONSOLE_UPLOAD_EVIDENCE`

Use a real non-template evidence file in `docs/release/evidence`. Rotation is
not mandatory when the owner explicitly approves retaining the current Play
service-account key and provides `PLAY_SERVICE_ACCOUNT_RETAINED=true` with
`PLAY_SERVICE_ACCOUNT_RETENTION_EVIDENCE`. Do not commit secret values or Play
service-account JSON.

Do not move existing script paths without updating GitHub Actions and README commands in the same change.
