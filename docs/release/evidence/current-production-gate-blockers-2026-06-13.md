# Current Production Gate Blockers

Date: 2026-06-13
Repository: `/Volumes/PRO-G40/MOBI/mobi_app`
Status: **NO-GO**

## Superseding Update - 2026-06-13 12:23 CAT

The earlier linked-backend, migration dry-run, BioPay live, and physical-smoke
blockers recorded below have now been cleared for the current local build.
Production remains **NO-GO** only because release approval/evidence,
post-exposure credential rotation, and approved admin-console UAT items remain
open.

Cleared in the final pass:

- `REQUIRE_LINKED_SUPABASE=true scripts/ci/verify_backend.sh` passed against
  project `paysnhuxngsvzdpwlosv`.
- `supabase db push --linked --dry-run --yes` reported the remote database is
  up to date.
- Live edge smoke proved:
  - `biopay-face-provider/health`: HTTP 200, `provider=aws_rekognition`,
    `production_ready=true`, USSD handoff boundary present.
  - `create-payment-intent`, `verify-payment-status`, `parse-sms`,
    `reconcile-momo-sms`, `admin-review-transaction`, and `biopay-api`:
    HTTP 410 scope-boundary responses; payment remains outside the app.
- `flutter analyze`: passed.
- Full `flutter test`: passed all 257 tests after BioPay home cleanup and
  golden refresh.
- `scripts/qa/verify_biopay_live_readiness.sh` with AWS, Supabase, and Android
  device proof required passed 55 checks, 0 failures, 0 warnings.
- Final APK build:
  - Path: `build/app/outputs/flutter-apk/app-release.apk`
  - SHA-256:
    `061da26a0bd9887c429b613586043b0762a905445ea305fc9eda9b68c2d975c3`
  - Size: 83 MB
- Final Pixel 4a install/smoke passed:
  `docs/release/evidence/android-smoke-2026-06-13-current/smoke-20260613T102258Z.log`.
- Role-aware APK readable-string scan found no service-role JWT, Supabase
  `sbp_` access token, Supabase DB password marker, or AWS key marker. Public
  anon client JWT may be present as expected.

Remaining hard blockers:

- Rotate/revoke every Supabase service-role key and `sbp_` access token pasted
  into the session. Rotate anon config too if the project owner treats the
  pasted anon key as compromised; if anon changes, rebuild and reinstall the
  APK.
- Run the final aggregate go/no-go gate with approved, non-template evidence
  for Android signing, Play service-account retention/use, and current Play
  Console internal/closed-track upload validation.
- Complete admin BioPay console device UAT after an approved allowlisted admin
  OTP session. Passenger BioPay/profile device UAT is now captured under
  `docs/release/evidence/device-uat-2026-06-13-current/manifest.md`.

This file records the current blocker state after local frontend, backend, BioPay, APK build, and physical install progress. It intentionally contains no secret values.

Update: the earlier APK generation, fresh physical install, and BioPay live warning-only blockers have been cleared by the 2026-06-13 10:25-10:26 CAT run. The release is still **NO-GO** until the remaining approval/credential/device-foreground gates below are cleared.

## Gates Re-run

```bash
ANDROID_SERIAL=13111JEC215558 \
  REQUIRE_BIOPAY_LIVE=true \
  BIOPAY_EVIDENCE_FILE=docs/release/evidence/biopay-live-readiness-2026-06-13-current.md \
  scripts/qa/verify_biopay_live_readiness.sh

GO_NO_GO_DRY_RUN=true RUN_FLUTTER_GATE=false RUN_ANDROID_SMOKE=false RELEASE_TARGET=android \
  scripts/release/go_no_go_check.sh

$ANDROID_HOME/build-tools/36.1.0/aapt2 dump permissions \
  build/app/outputs/flutter-apk/app-release.apk

ANDROID_SERIAL=13111JEC215558 \
  ANDROID_UAT_EVIDENCE_DIR=docs/release/evidence/device-uat-2026-06-13 \
  ANDROID_UAT_STEP=foreground-gate-locked-check \
  scripts/qa/capture_android_uat_state.sh

ANDROID_RELEASE_SHRINK=false \
  scripts/release/build_android_release.sh apk

ANDROID_SERIAL=13111JEC215558 \
  ANDROID_SMOKE_EVIDENCE_DIR=docs/release/evidence/android-smoke-2026-06-13-current \
  scripts/release/smoke_android_release.sh
```

Additional APK string scan:

- Server-only patterns checked: service-role markers, Supabase `sbp_` token shape, `SUPABASE_DB_PASSWORD`, AWS access key names.
- Result: no server-only forbidden pattern was found in the APK string scan.
- Note: the APK contains JWT-shaped client configuration material, expected for public Supabase anon configuration. If public client configuration changes, rebuild and reinstall the APK.

## Current Positive Evidence

- `scripts/qa/scan_secrets.sh` passed.
- `scripts/qa/check_secret_history.sh` passed.
- BioPay static restoration, routes, USSD-only boundary, AWS Rekognition code path, native camera/NFC permissions, Deno face-provider tests, and focused Flutter BioPay/router/boundary tests passed.
- Physical device capability checks passed inside BioPay live gate:
  - Pixel `13111JEC215558` exposes camera.
  - Pixel `13111JEC215558` exposes NFC.
  - Installed package requests camera and NFC.
  - Device resolves `ACTION_DIAL tel:` USSD intents.
- Strict BioPay live proof passed with `REQUIRE_BIOPAY_LIVE=true`:
  - Deployed edge health returned HTTP 200.
  - Provider proved as `aws_rekognition`.
  - `production_ready=true` and provider collection metadata were present.
- Guarded APK generation passed through `scripts/release/build_android_release.sh apk`.
  - APK: `build/app/outputs/flutter-apk/app-release.apk`
  - SHA-256: `061da26a0bd9887c429b613586043b0762a905445ea305fc9eda9b68c2d975c3`
- Fresh Pixel install proof exists in `docs/release/evidence/android-smoke-2026-06-13-current/smoke-20260613T102258Z.log`:
  - `versionCode=12`
  - `versionName=1.0.0`
  - `primaryCpuAbi=arm64-v8a`
  - current APK foreground smoke passed
- `flutter analyze`: no issues found.
- `flutter test`: 257 tests passed.
- Built APK permission surface:
  - `INTERNET`
  - `ACCESS_NETWORK_STATE`
  - `ACCESS_FINE_LOCATION`
  - `ACCESS_COARSE_LOCATION`
  - `CAMERA`
  - `NFC`
  - `POST_NOTIFICATIONS`
  - `WAKE_LOCK`
  - `VIBRATE`
  - Firebase/Google Play support permissions

## Current Hard Blockers

### P0: Credential Rotation After Pasted Secrets

Supabase service-role and `sbp_` access-token values were pasted into the
session. Code and APK scans passed, but production release should not proceed
until those exposed credentials are revoked/rotated.

Required next proof:

- Rotate/revoke the pasted Supabase service-role key and access tokens.
- Rotate anon config too if the owner treats pasted anon config as compromised.
- If anon config changes, rebuild the APK and repeat physical smoke.

### P0: Release Signing Gate

The aggregate release gate requires Android signing env. Current shell is missing `KEYSTORE_BASE64`.

Required next proof:

- Provide Android signing secrets through CI/local secret storage.
- Re-run `scripts/ci/verify_release_config.sh` with `REQUIRE_ANDROID_SIGNING=true`.

### P0: Play Service Account Use Decision

The release gate requires `PLAY_SERVICE_ACCOUNT_RETAINED=true` plus owner-approved retention/use evidence.

Existing context:

- `docs/release/evidence/play-service-account-retention-2026-06-12.md` records a prior owner-approved retention decision.
- That prior decision can clear the gate when it is explicitly pointed to by the release command.

Required next proof:

- Point `PLAY_SERVICE_ACCOUNT_RETENTION_EVIDENCE` to the non-template retention/use evidence file.

### P0: Play Console Upload Validation

The release gate requires `PLAY_CONSOLE_UPLOAD_VALIDATED=true` and a non-template `PLAY_CONSOLE_UPLOAD_EVIDENCE` file.

Existing context:

- `docs/release/evidence/play-console-upload-2026-06-12-v13.md` proves an older version-code 13 internal draft upload.
- It does not prove upload validation for the current 2026-06-13 APK/AAB build.

Required next proof:

- Validate internal/closed-track upload in Play Console.
- Save evidence without secrets and point the gate to it.

### P0: Admin BioPay Console Device UAT

The final APK now installs, passes hardened foreground smoke, and has current
physical-device screenshot/UI-hierarchy evidence for reachable passenger
BioPay/profile flows.

Current positive evidence:

- `docs/release/evidence/android-smoke-2026-06-13-current/smoke-20260613T102258Z.log`
- `docs/release/evidence/device-uat-2026-06-13-current/manifest.md`

Captured current-APK screens include BioPay home, QR, scanner, NFC, face scan,
face enrollment, profile, edit profile, and the admin auth gate.

Remaining blocker:

- The app correctly requires an allowlisted admin WhatsApp OTP session before
  showing the admin BioPay console. This UAT pass did not send an OTP, mutate an
  allowlist, use a service-role bypass, or fabricate admin access.

Required next proof:

- Provide an approved allowlisted admin WhatsApp OTP session or explicit owner
  approval to send/use one.
- Capture admin BioPay operations after login, including summary, payees,
  requests, system status, and external-confirmation controls.

## Resolved During This Run

- APK generation is repeatable through the guarded release script. The script now refuses concurrent release builds with a lock under `${TMPDIR:-/tmp}/mobi_android_release_build.lock`.
- Fresh install proof is written by the smoke script immediately after `adb install -r`, before any foreground/keyguard checks.
- BioPay live AWS/edge/device proof is no longer warning-only when `REQUIRE_BIOPAY_LIVE=true`; the script proves deployed edge health and Android device capability as hard pass/fail checks.
- App-owned Android Kotlin configuration is migrated to Built-in Kotlin. The remaining Flutter KGP warning is upstream plugin-owned for `app_settings`, `device_info_plus`, `firebase_analytics`, `firebase_remote_config`, `flutter_nfc_kit`, and `mobile_scanner`; `shared_preferences_android` was cleared by upgrading to `2.4.26`.

## Connector State

Supabase MCP connector test:

```text
400: "We couldn't connect your account. Please try again."
```

The connector cannot currently clear linked Supabase/advisor gates.
