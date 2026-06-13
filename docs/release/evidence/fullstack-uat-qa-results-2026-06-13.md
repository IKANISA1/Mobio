# MOBI Fullstack UAT and QA Results

Date: 2026-06-13
Status: Automated backend, BioPay live, APK build, physical-smoke, and passenger BioPay/profile device-UAT gates now pass. Production readiness remains **NO-GO** until credential rotation/approval evidence, Play upload validation, and admin BioPay console UAT with an approved admin OTP session are complete.

## Summary

The fullstack UAT plan has been created at:

- `/Volumes/PRO-G40/MOBI/mobi_app/docs/release/evidence/fullstack-uat-qa-plan-2026-06-13.md`
- `/Volumes/PRO-G40/MOBI/mobi_app/docs/release/evidence/current-production-gate-blockers-2026-06-13.md`

Initial static and automated gates were executed. The first run found visual regression and scanner test-harness blockers; those frontend blockers have now been fixed and revalidated. Linked Supabase security/storage gates also passed after authenticated CLI execution, and the legacy out-of-scope payment functions were redeployed so production now returns the current MOBI scope boundary. A fresh release APK was built and installed on the physical Pixel 4a.

The app is still not production-ready because pasted Supabase credentials must be rotated/revoked, release credential-use evidence must be explicitly pointed to approved non-template files, current Play Console upload validation is still missing, and the admin BioPay console still needs an approved live admin OTP session for device UAT.

## Superseding Device UAT Pass - 2026-06-13 13:15 CAT

Full current-APK passenger BioPay/profile UAT was executed on the physical Pixel 4a. Evidence is saved under:

- `docs/release/evidence/device-uat-2026-06-13-current/manifest.md`

Captured and passed:

- BioPay home: no search row, no Activity screen, and only Face, NFC, Get QR, and Scan actions.
- QR receive.
- QR scanner.
- NFC receive.
- Face scan standby and active states.
- Face enrollment standby and active states using AWS Rekognition copy/provider metadata.
- Profile top and lower sections, including BioPay Face setup entry and hidden admin gateway.
- Edit Profile.
- Admin auth gate.

Not completed:

- Admin BioPay console operations screen. The installed app correctly requires an allowlisted WhatsApp admin OTP session. The UAT reached and captured the admin auth gate, but no OTP send, allowlist mutation, service-role bypass, or live admin login was performed without explicit owner approval.

## Superseding Final Pass - 2026-06-13 12:23 CAT

- Linked Supabase verification passed against project `paysnhuxngsvzdpwlosv`.
- `supabase db push --linked --dry-run --yes` reported the remote database is up to date.
- Live edge smoke proved the AWS BioPay face provider health endpoint and confirmed out-of-scope payment/SMS/admin transaction endpoints return HTTP 410 scope-boundary responses.
- `flutter analyze` passed.
- Full `flutter test` passed all 257 tests.
- `scripts/qa/verify_biopay_live_readiness.sh` passed with AWS, Supabase, and Android device proof required: 55 checks, 0 failures, 0 warnings.
- Final release APK: `build/app/outputs/flutter-apk/app-release.apk`
  - SHA-256: `061da26a0bd9887c429b613586043b0762a905445ea305fc9eda9b68c2d975c3`
  - Size: 83 MB
- Final physical Pixel 4a smoke passed:
  `docs/release/evidence/android-smoke-2026-06-13-current/smoke-20260613T102258Z.log`.
- Role-aware APK readable-string scan found no service-role JWT, Supabase `sbp_` access token, Supabase DB password marker, or AWS key marker. Public anon JWT config may be present as expected.

## Commands Run

```bash
/Volumes/PRO-G40/flutter_3_44/bin/flutter pub get
scripts/qa/scan_secrets.sh
scripts/qa/audit_storage_realtime.sh
/Volumes/PRO-G40/flutter_3_44/bin/flutter analyze
/Volumes/PRO-G40/flutter_3_44/bin/flutter test
scripts/ci/verify_backend.sh
/Volumes/PRO-G40/flutter_3_44/bin/flutter test --update-goldens test/features/preview/revolut_reference_golden_test.dart
/Volumes/PRO-G40/flutter_3_44/bin/flutter test test/features/preview/revolut_reference_golden_test.dart
/Volumes/PRO-G40/flutter_3_44/bin/flutter test
supabase db push --linked --dry-run --yes
supabase functions deploy create-payment-intent verify-payment-status parse-sms reconcile-momo-sms admin-review-transaction biopay-api
scripts/release/build_android_release.sh apk
adb -s 13111JEC215558 install -r build/app/outputs/flutter-apk/app-release.apk
adb -s 13111JEC215558 shell monkey -p rw.mobi.app -c android.intent.category.LAUNCHER 1
```

## Gate Results

| Area | Result | Evidence |
| --- | --- | --- |
| Dependency sync | PASS | `flutter pub get` completed. 95 packages have newer incompatible versions. |
| Static Dart/Flutter analysis | PASS | `flutter analyze` reported no issues. |
| Local secret-pattern scan | PASS | `scripts/qa/scan_secrets.sh` reported `secret-pattern scan passed`. |
| Supabase storage/realtime audit | PASS | Authenticated `scripts/qa/audit_storage_realtime.sh` exited 0 with no failure rows. |
| Backend local function tests | PASS | `scripts/ci/verify_backend.sh` passed local Deno tests. |
| Backend linked security assertions | PASS | Authenticated `scripts/ci/verify_backend.sh` reported backend security assertions passed. |
| Supabase migration dry-run | PASS | `supabase db push --linked --dry-run --yes` reported the remote database is up to date. |
| Legacy payment/API boundary functions | PASS | Six deployed functions return HTTP 410 with `mobio_scope_unavailable`, explicitly preserving USSD dialer assistance only and excluding in-app payment/PSP/card/MoMo processing. |
| Flutter test suite | PASS | Full suite passed after scanner test-channel mock and corrected BioPay/profile golden baselines. |
| Android release APK build | PASS | Locked release script built `build/app/outputs/flutter-apk/app-release.apk`. Final SHA-256: `061da26a0bd9887c429b613586043b0762a905445ea305fc9eda9b68c2d975c3`. |
| APK server-secret scan | PASS | Role-aware readable-string scan found no service-role JWT, Supabase `sbp_` access token, DB password marker, or AWS key marker. Public anon JWT config may be present as expected. |
| APK permission surface | PASS | Built APK requests expected camera/NFC/network/location/notification/Firebase support permissions; no SMS read/receive permission is present. |
| Physical Pixel install | PASS | `adb install -r` installed the fresh APK successfully on Pixel 4a `13111JEC215558`. |
| Physical Pixel startup smoke | PASS | Final current APK installed, launched, foregrounded, and passed hardened smoke. Evidence: `docs/release/evidence/android-smoke-2026-06-13-current/smoke-20260613T102258Z.log`. |
| Aggregate go/no-go gate | NO-GO | Remaining blockers are credential rotation/revocation after pasted secrets, Android signing/Play service-account evidence, current Play upload validation, and admin BioPay console device UAT after approved admin OTP login. |

## Backend Result Detail

`scripts/ci/verify_backend.sh` passed these local function tests:

- `supabase/functions/biopay-api/index_test.ts`
- `supabase/functions/biopay-face-provider/index_test.ts`
- `supabase/functions/_shared/otp-security_test.ts`
- `supabase/functions/_shared/phone_test.ts`
- `supabase/functions/_shared/whatsapp-cloud_test.ts`

Linked backend gates now have positive evidence:

- `scripts/ci/verify_backend.sh` passed authenticated linked security assertions against project `paysnhuxngsvzdpwlosv`.
- `scripts/qa/audit_storage_realtime.sh` exited 0 with no failure rows.
- Live edge function smoke tests confirmed current scope-unavailable responses for `create-payment-intent`, `verify-payment-status`, `parse-sms`, `reconcile-momo-sms`, `admin-review-transaction`, and `biopay-api`.

Remaining backend limitation:

- No backend schema drift blocker remains from this pass. The remaining backend-adjacent production item is credential rotation/revocation because service-role and access-token values were pasted into the session.

## Frontend Result Detail

Initial `flutter test` failed in:

- `test/features/preview/revolut_reference_golden_test.dart`

Initial failing golden surfaces reported by the test runner:

- `profile_390x844`
- `profile_430x932`
- `biopay_home_390x844`
- `biopay_home_430x932`
- `biopay_qr_390x844`
- `biopay_qr_430x932`
- `biopay_scan_390x844`
- `biopay_scan_430x932`
- `biopay_face_scan_390x844`
- `biopay_face_scan_430x932`
- `biopay_face_enroll_390x844`
- `biopay_face_enroll_430x932`
- `biopay_nfc_390x844`
- `biopay_nfc_430x932`

Initial severity:

- BioPay golden failures are P0 for visual QA because the pixel diffs are extreme, commonly above 90 percent.
- Profile golden drift is smaller but repeatable and still must be reviewed before release.
- `MissingPluginException(No implementation found for method stop on channel dev.steenbakker.mobile_scanner/scanner/method)` appeared during scanner golden execution. This is a P1 test-harness blocker because it can make scanner visual tests noisy or unreliable.

Resolution:

- Added `test/helpers/mobile_scanner_test_channel.dart` to mock the mobile scanner method, event, and orientation channels in widget/golden tests.
- Updated `test/features/preview/revolut_reference_golden_test.dart` to install the scanner mock.
- Updated `test/features/biopay/biopay_payment_surfaces_test.dart` to install the scanner mock.
- Regenerated the stale visual baselines so BioPay goldens now match the corrected white BioPay reference direction instead of the rejected dark/activity design.
- Removed stale tracked `biopay_activity` golden images because the Activity screen is unsupported and no longer part of the product/test matrix.

Validation after fix:

- `flutter test test/features/biopay/biopay_payment_surfaces_test.dart` passed.
- `flutter test --update-goldens test/features/preview/revolut_reference_golden_test.dart` passed.
- `flutter test test/features/preview/revolut_reference_golden_test.dart` passed.
- Full `flutter test` passed all 257 tests.

Generated failure artifacts from the initial failing run:

- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_home_390x844_testImage.png`
- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_home_430x932_testImage.png`
- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_qr_390x844_testImage.png`
- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_qr_430x932_testImage.png`
- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_scan_390x844_testImage.png`
- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_scan_430x932_testImage.png`
- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_face_scan_390x844_testImage.png`
- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_face_scan_430x932_testImage.png`
- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_face_enroll_390x844_testImage.png`
- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_face_enroll_430x932_testImage.png`
- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_nfc_390x844_testImage.png`
- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_nfc_430x932_testImage.png`

Note: the `failures/` folder also contains older June 12 files for non-BioPay screens. Those older files are not treated as fresh findings from this Phase 1 run unless revalidated.

## Resolved Findings

### RESOLVED: Full Flutter test suite failed

The full Flutter test suite now passes after:

- correcting stale BioPay/profile golden baselines,
- deleting obsolete Activity golden baselines,
- and adding scanner channel mocks for deterministic test execution.

### RESOLVED: Legacy in-app payment/API functions had stale production scope text

Six production edge functions were redeployed to match the local USSD-only boundary:

- `create-payment-intent`
- `verify-payment-status`
- `parse-sms`
- `reconcile-momo-sms`
- `admin-review-transaction`
- `biopay-api`

Live smoke tests now return HTTP 410 with `mobio_scope_unavailable`, include `BioPay USSD dialer assistance`, and state `No in-app fare engine` plus `BioPay remains USSD dialer assistance only`.

### RESOLVED: Android release build reproducibility

The Android release script now uses an atomic lock to prevent concurrent release builds from corrupting Gradle/Flutter intermediates. A clean serialized APK build completed successfully:

- Output: `/Volumes/PRO-G40/MOBI/mobi_app/build/app/outputs/flutter-apk/app-release.apk`
- Size: 83 MB
- SHA-256: `061da26a0bd9887c429b613586043b0762a905445ea305fc9eda9b68c2d975c3`
- Final build time: 1148.0 seconds

The same APK installed successfully on the physical Pixel 4a.

## Current P0 Findings

### P0-1: Credential rotation and credential-use evidence must be explicit

Supabase tokens and other secrets were pasted into the working session, and earlier build command lines exposed dart-define temp paths in process listings. No final report should include secret values. Rotation is not a release blocker by owner direction; release evidence must show credentials were supplied through ignored local files, CI secrets, or another non-logged approved path.

Required resolution:

- Rotate/revoke the pasted Supabase service-role key and `sbp_` access tokens.
- Rotate anon config too if the owner treats pasted anon config as compromised; if anon changes, rebuild and reinstall the APK.
- Keep secret values out of committed files, reports, screenshots, and shell-visible command arguments.
- Point release gates to approved non-template credential-use/retention evidence.
- Re-run backend and release gates using the approved secret path.

### P0-2: Admin BioPay console device UAT requires approved admin login

The final APK installs, passes hardened foreground smoke, and now has physical-device screenshot/UI-hierarchy evidence for the passenger BioPay/profile flows.

Current evidence:

- Pixel 4a `13111JEC215558` connected.
- Final APK installed successfully.
- Hardened smoke passed with foreground app focus.
- Smoke evidence: `/Volumes/PRO-G40/MOBI/mobi_app/docs/release/evidence/android-smoke-2026-06-13-current/smoke-20260613T102258Z.log`
- Passenger BioPay/profile device UAT manifest: `/Volumes/PRO-G40/MOBI/mobi_app/docs/release/evidence/device-uat-2026-06-13-current/manifest.md`

Required resolution:

- Provide an approved allowlisted admin WhatsApp OTP session or explicit approval to send/use one.
- Capture `/admin/biopay` after login, including summary cards, payee/request/system status lists, and external-confirmation controls.

### P0-3: Current Play Console upload validation is missing

The final APK hash is current, but Play Console internal/closed-track validation has not been re-proved for this build.

Required resolution:

- Upload the current AAB/APK candidate to the approved Play test track.
- Save non-secret upload validation evidence.
- Point `PLAY_CONSOLE_UPLOAD_EVIDENCE` to that non-template evidence file.

## Current P1 Findings

### P1-1: Dependency aging needs review

`flutter pub get` reports 95 packages with newer incompatible versions. This is not an immediate blocker, but it increases upgrade and maintenance risk.

### P1-2: iOS Swift Package Manager warning

Flutter reports `permission_handler_apple` does not support Swift Package Manager for iOS. This is a future Flutter compatibility risk and should be tracked before iOS release hardening.

## BioPay-Specific Assessment

BioPay restoration has stronger automated evidence now:

- BioPay entry points and surfaces are covered by passing widget/golden tests.
- Face scan/enrollment paths are configured around AWS Rekognition.
- The current boundary remains USSD dialer handoff only.
- QR, NFC, face scan, and face enrollment surfaces exist.
- Legacy in-app payment/API functions now return out-of-scope responses that preserve USSD dialer assistance only.
- `BIOPAY_EVIDENCE_FILE=docs/release/evidence/biopay-live-readiness-2026-06-13-current.md REQUIRE_BIOPAY_AWS_LIVE=true REQUIRE_BIOPAY_SUPABASE_LIVE=true REQUIRE_BIOPAY_DEVICE_LIVE=true scripts/qa/verify_biopay_live_readiness.sh` passed 55 checks with 0 failures and 0 warnings.

BioPay is still not production-cleared because:

- Admin BioPay confirmation workflow still needs full live UAT after approved admin OTP login.

## Next Execution Batch

1. Rotate/revoke pasted Supabase service-role/access tokens and rebuild/retest if public anon config changes.
2. Provide approved non-logged Android signing and Play evidence paths.
3. Validate the current build in Play Console internal/closed testing.
4. Provide an approved allowlisted admin OTP session and capture admin BioPay console UAT.
5. Run the final aggregate go/no-go gate.
6. Write final go/no-go report.
