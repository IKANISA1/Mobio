# Final native UI production APK evidence - 2026-06-13

## Scope reviewed

- Reviewed the available 2026-06-13 UI review evidence in:
  - `docs/product/revolut_full_repo_flutter_admin_comparative_audit_2026-06-13.md`
  - `docs/product/revolut_recommendations_implementation_log_2026-06-13.md`
  - `docs/release/evidence/fullstack-uat-qa-results-2026-06-13.md`
- Confirmed the implementation log covers the native Flutter surfaces, not only the Codex web preview:
  - BioPay four-card passenger flow.
  - BioPay QR, scanner, face scan, face enrollment, NFC, and USSD-bounded copy.
  - Admin BioPay operations route and compatibility routing.
  - Profile, edit profile, profile setup, notifications, chat, nearby, trip detail/edit, config error, not found, and admin detail routes.
  - Shared modal/bottom-sheet standardization and admin desktop/tablet density fixes.

## Native Flutter verification

Command:

```sh
dart analyze
```

Result:

```text
No issues found.
```

Command:

```sh
FLUTTER_BIN=/Volumes/PRO-G40/flutter_3_44/bin/flutter \
/Volumes/PRO-G40/flutter_3_44/bin/flutter test --concurrency=1 \
  test/features/biopay/biopay_payment_surfaces_test.dart \
  test/features/biopay/biopay_admin_console_test.dart \
  test/features/preview/revolut_reference_golden_test.dart \
  test/core/router/app_router_test.dart \
  test/release/scope_boundary_test.dart \
  test/release/mobile_readiness_contract_test.dart \
  test/release/admin_panel_production_readiness_contract_test.dart
```

Result:

```text
All tests passed. 138 passing tests.
```

Coverage from this run included the BioPay payment/admin tests, the 101-case route golden matrix, router contracts, production scope boundaries, mobile readiness contracts, and admin panel production-readiness contracts.

## Cleanup before build

- Stopped the stale Codex web-preview Flutter process from the prior web-view review.
- Stopped old Gradle daemons.
- Force-stopped the installed Android app before reinstall.
- Deleted old generated APK/AAB outputs under `build/app/outputs`.
- Rechecked that no stale MOBI Flutter/Gradle build processes and no old APK/AAB artifacts remained before starting the fresh build.

## Fresh production APK

Command:

```sh
scripts/release/build_android_release.sh apk
```

Result:

```text
Built APK: build/app/outputs/flutter-apk/app-release.apk
```

Artifact:

- `build/app/outputs/flutter-apk/app-release.apk`
- Size: 87.8 MB reported by Flutter, 84 MB on disk.
- SHA-256: `f51d4ef889b8669858008eae404e39956aa84b9b70fcddfec457ce1379dab163`

The Gradle copy at `build/app/outputs/apk/release/app-release.apk` has the same SHA-256.

APK sensitive-secret scan result:

```text
# Historical service-role assignment omitted during repository consolidation.
SUPABASE_ACCESS_TOKEN=not_found
AWS_ACCESS_KEY_ID=not_found
AWS_SECRET_ACCESS_KEY=not_found
literal_AWS_SECRET_ACCESS_KEY=not_found
literal_service_role=not_found
```

## Physical Pixel 4a install and smoke

Device:

- Serial: `13111JEC215558`
- Model: Pixel 4a
- Android: 13 / SDK 33

Install:

```text
Performing Streamed Install
Success
```

Installed package:

```text
package=rw.mobi.app
versionCode=12
versionName=1.0.0
primaryCpuAbi=arm64-v8a
apkSigningVersion=2
```

Release smoke command:

```sh
ANDROID_SERIAL=13111JEC215558 \
ANDROID_SMOKE_EVIDENCE_DIR=docs/release/evidence/android-smoke-2026-06-13-final-ui \
scripts/release/smoke_android_release.sh
```

Result:

```text
Android release smoke passed.
```

Evidence files:

- `docs/release/evidence/android-smoke-2026-06-13-final-ui/smoke-20260613T145552Z.log`
- `docs/release/evidence/android-smoke-2026-06-13-final-ui/smoke-20260613T145552Z.png`
- `docs/release/evidence/android-smoke-2026-06-13-final-ui/smoke-20260613T145552Z.xml`
- `docs/release/evidence/android-smoke-2026-06-13-final-ui/smoke-20260613T145552Z-window.txt`

Foreground proof:

```text
pid=25702
current_focus=Window{... rw.mobi.app/rw.mobi.app.MainActivity}
```

The screenshot and UI tree show the native WhatsApp login screen rendered on-device with passenger/driver selection and Rwanda phone-number input.

## Live BioPay face-provider health

Checked after APK build/install:

```text
HTTP 200
provider=aws_rekognition
production_ready=true
provider_collection_id=mobio-biopay-prod
payment_boundary=USSD dialer handoff only; no in-app settlement.
```

## Remaining UAT limitation

The current physical device state is unauthenticated after install. The fresh production APK has been installed and launch-smoked on the Pixel, and the reviewed authenticated routes are covered by native Flutter tests/goldens, but a fresh on-device walk-through of authenticated BioPay/admin screens still requires a valid passenger/admin login OTP and any required admin approval.
