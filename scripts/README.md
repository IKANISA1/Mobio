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
- `scripts/release/go_no_go_check.sh`
- `scripts/qa/scan_secrets.sh`
- `scripts/qa/check_secret_history.sh`
- `scripts/qa/preflight_secret_history_purge.sh`

Final go/no-go requires external Play evidence paths:

- `PLAY_SERVICE_ACCOUNT_ROTATION_EVIDENCE`
- `PLAY_CONSOLE_UPLOAD_EVIDENCE`

Use the safe templates in `docs/release/evidence`; do not commit secret values
or Play service-account JSON.

Do not move existing script paths without updating GitHub Actions and README commands in the same change.
