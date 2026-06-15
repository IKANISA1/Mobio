# Mobio Fresh APK Pixel 4a UAT Report

Date: 2026-06-15  
Repository: `/Volumes/PRO-G40/MOBI/mobi_app`  
Device: Pixel 4a, serial `13111JEC215558`  
Package: `rw.mobi.app`  
Build type: Android release APK

## Verdict

Status: **Partially completed / conditional GO**

The fresh APK was built, installed on the Pixel 4a, and passed the automated release smoke gate, release contract tests, app-link verification, and broad safe on-device UI navigation/clickability sweep. No app crash, fatal exception, ANR, FlutterError, PlatformException, NFC reader-mode binder failure, or BioPay NFC activation failure was found in the captured device logs.

The remaining blocking boundary is physical NFC card verification: the automated app-link and package checks passed, but actual NFC write/read/lock verification requires holding a real writable NFC card to the Pixel 4a during the UAT window. That physical card action was not executed in this run. The sweep also found that the write-card action was not discoverable from the visible NFC Tap screen text search.

## APK Cleanup, Build, and Install

Previous generated APK/AAB artifacts were removed from `build/` before building. Deleted artifacts included:

- `build/app/intermediates/intermediary_bundle/release/packageReleaseBundle/intermediary-bundle.aab`
- `build/app/outputs/apk/release/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`
- `build/app/outputs/flutter-apk/app-release.apk`

Fresh build command:

```sh
PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin ANDROID_RELEASE_SHRINK=false ./scripts/release/build_android_release.sh apk
```

Build result:

- `build/app/outputs/flutter-apk/app-release.apk`
- Size: 97.5 MB
- SHA-256: `0a220ebfe1b316b694c5684b85aed3c0bb6cd3d6e9608abca41d109859da55cf`

Fresh output verification:

- `build/app/outputs/apk/release/app-release.apk`
- `build/app/outputs/flutter-apk/app-release.apk`
- Both files have SHA-256 `0a220ebfe1b316b694c5684b85aed3c0bb6cd3d6e9608abca41d109859da55cf`

Install command:

```sh
adb -s 13111JEC215558 install -r build/app/outputs/flutter-apk/app-release.apk
```

Install result: `Success`

Installed package proof:

- versionCode: `14`
- versionName: `1.0.0`
- package: `rw.mobi.app`
- targetSdk: `35`
- signing: APK Signature Scheme v2 verified
- certificate DN: `CN=MOBI Rwanda, OU=Mobile, O=MOBI, L=Kigali, ST=Kigali, C=RW`

## Device Baseline

Device:

- Manufacturer: Google
- Model: Pixel 4a
- Android: 13
- SDK: 33
- NFC feature: present
- NFC service: enabled
- App link domain: `mobio.ikanisa.com` verified for `rw.mobi.app`
- NFC permission: granted at install/package level

Runtime permissions initially denied after reinstall, then granted for UAT:

- `android.permission.CAMERA`
- `android.permission.ACCESS_FINE_LOCATION`
- `android.permission.ACCESS_COARSE_LOCATION`
- `android.permission.POST_NOTIFICATIONS`

Baseline evidence:

- `docs/release/evidence/fresh-apk-device-baseline-2026-06-15/`
- `docs/release/evidence/full-device-uat-fresh-apk-2026-06-15/permissions-before.txt`
- `docs/release/evidence/full-device-uat-fresh-apk-2026-06-15/permissions-after.txt`

## Automated Gates

### Android Release Smoke

Command:

```sh
ANDROID_SERIAL=13111JEC215558 ANDROID_SMOKE_EVIDENCE_DIR=build/reports/android-smoke-fresh-uat ./scripts/release/smoke_android_release.sh
```

Result: **PASS**

Evidence:

- `build/reports/android-smoke-fresh-uat/smoke-20260615T124507Z.log`
- `build/reports/android-smoke-fresh-uat/smoke-20260615T124507Z.png`
- `build/reports/android-smoke-fresh-uat/smoke-20260615T124507Z.xml`
- `build/reports/android-smoke-fresh-uat/smoke-20260615T124507Z-window.txt`

### Release Contract Tests

Command:

```sh
/Volumes/PRO-G40/flutter_3_44/bin/flutter test --no-pub --concurrency=1 \
  test/release/mobile_readiness_contract_test.dart \
  test/release/scope_boundary_test.dart \
  test/release/profile_verified_contact_contract_test.dart \
  test/release/wallet_driver_plus_contract_test.dart \
  test/release/admin_panel_production_readiness_contract_test.dart
```

Result: **PASS**

Coverage: 34 release contract tests passed.

## BioPay NFC UAT

Command:

```sh
ANDROID_SERIAL=13111JEC215558 NFC_UAT_EVIDENCE_DIR=docs/release/evidence/fresh-apk-biopay-nfc-auto-2026-06-15 ./scripts/qa/verify_biopay_nfc_card_uat.sh
```

Automated result: **NO-GO due to manual/strict checks, with important follow-up proof**

Passed checks:

- Device exposes NFC feature.
- Device NFC service is on.
- Installed package has NFC permission.
- Installed package has HTTPS NFC app-link filter.
- Installed package has `NDEF_DISCOVERED` filter.
- Installed package has custom `mobio` scheme filter.
- `mobio.ikanisa.com` is verified for installed package.
- HTTPS NFC payload resolves to Mobio.

Script failures:

- `HTTPS NFC payload launches dialer handoff`
- `payload launch has no fatal app errors`

Follow-up investigation:

- No `FATAL EXCEPTION`, `ANR`, `FlutterError`, or `PlatformException` was found in the payload launch logcat.
- Manual timed replay showed the direct receiver HTTPS NFC payload opened the Android dialer at 1s, 2s, 4s, and 7s.
- This means the original dialer-handoff failure was a timing/expectation artifact in the script run, not a confirmed runtime failure.

Timed focus proof:

- `docs/release/evidence/fresh-apk-biopay-nfc-focus-timing-2026-06-15/focus-1s.txt`
- `docs/release/evidence/fresh-apk-biopay-nfc-focus-timing-2026-06-15/focus-2s.txt`
- `docs/release/evidence/fresh-apk-biopay-nfc-focus-timing-2026-06-15/focus-4s.txt`
- `docs/release/evidence/fresh-apk-biopay-nfc-focus-timing-2026-06-15/focus-7s.txt`

All timed focus files show:

```text
com.google.android.dialer/com.android.dialer.main.impl.MainActivity
```

Physical NFC card status:

- Physical NFC card write/read/lock was not executed in this run.
- Reason: a real writable NFC card must be held to the Pixel 4a during the manual UAT window.
- The automated script explicitly recorded: `Manual physical card write/read was not run. Set NFC_UAT_MANUAL_SECONDS to capture it.`

## Device UI/UX Sweep

Evidence directory:

- `docs/release/evidence/full-device-uat-fresh-apk-2026-06-15/`

Captured artifacts:

- 51 sweep events
- 24 screenshots
- 25 UIAutomator XML dumps
- 23 clickable inventories
- device logcat for the sweep

Safe clickability coverage completed:

- App launch and foreground focus.
- Bottom navigation:
  - Home
  - Trips
  - BioPay
  - Profile
- BioPay cards:
  - Get QR
  - Scan QR
  - Face Scan
  - NFC Tap
- Back navigation from each tested BioPay surface.
- Profile secondary screens:
  - Wallet
  - Mobio Plus
  - Edit profile
- Camera-dependent screens opened after permissions were granted.

Representative screenshots:

- `docs/release/evidence/full-device-uat-fresh-apk-2026-06-15/02-tab-home.png`
- `docs/release/evidence/full-device-uat-fresh-apk-2026-06-15/02-tab-trips.png`
- `docs/release/evidence/full-device-uat-fresh-apk-2026-06-15/02-tab-biopay.png`
- `docs/release/evidence/full-device-uat-fresh-apk-2026-06-15/02-tab-profile.png`
- `docs/release/evidence/full-device-uat-fresh-apk-2026-06-15/04-biopay-get-qr.png`
- `docs/release/evidence/full-device-uat-fresh-apk-2026-06-15/05-biopay-scan-qr.png`
- `docs/release/evidence/full-device-uat-fresh-apk-2026-06-15/06-biopay-face-scan.png`
- `docs/release/evidence/full-device-uat-fresh-apk-2026-06-15/07-biopay-nfc-tap.png`
- `docs/release/evidence/full-device-uat-fresh-apk-2026-06-15/11-profile-secondary-wallet.png`
- `docs/release/evidence/full-device-uat-fresh-apk-2026-06-15/11-profile-secondary-mobio-plus.png`
- `docs/release/evidence/full-device-uat-fresh-apk-2026-06-15/11-profile-secondary-edit-profile.png`

Logcat result:

- No app crash markers were found.
- No NFC activation failure marker was found.
- No reader-mode binder failure marker was found.
- System noise observed was unrelated to the app, including Android system/channel warnings and a `TransactionTooLargeException` from `NullBinder`.

## Not Covered by Automated Safe Sweep

These actions were intentionally not executed automatically because they can mutate data, spend money, place calls, or require external/manual input:

- Real USSD/mobile-money call confirmation.
- Real payment submission.
- Admin destructive or state-changing actions.
- Physical NFC write/read/lock with a real card.
- Exhaustive tapping of every destructive form submit button.

## Issues and Required Fixes

### 1. Physical NFC card UAT still required

Severity: High  
Status: Open

The APK has the required NFC permission, filters, app-link verification, and direct receiver handoff behavior. However, full NFC readiness cannot be signed off until a real NFC card is written, read back, verified, and optionally locked on the Pixel 4a.

Required next UAT:

```sh
ANDROID_SERIAL=13111JEC215558 \
NFC_UAT_EVIDENCE_DIR=docs/release/evidence/fresh-apk-biopay-nfc-physical-2026-06-15 \
NFC_UAT_MANUAL_SECONDS=45 \
./scripts/qa/verify_biopay_nfc_card_uat.sh
```

During the 45-second manual window, hold a writable NFC card to the Pixel 4a and keep it steady until the app confirms write/read/verification.

### 2. Write-card entry not discoverable from NFC Tap screen

Severity: Medium  
Status: Open

The route and implementation exist, but the automated UI sweep did not find a visible `Write NFC` entry from the NFC Tap screen. This is a UX discoverability issue and can block testers or operators from reaching the card-writing flow without a deep link or alternate navigation path.

Evidence:

- `docs/release/evidence/full-device-uat-fresh-apk-2026-06-15/09-nfc-write-card-entry-not-found.png`
- `docs/release/evidence/full-device-uat-fresh-apk-2026-06-15/09-nfc-write-card-entry-not-found.xml`

Recommended fix:

- Add a clearly visible `Write NFC card` action on the BioPay NFC screen for authorized/operator contexts, or add a deterministic navigation entry from the BioPay home surface.
- Add a widget test and device-sweep selector for that entry.

### 3. NFC UAT script strict failure should be corrected

Severity: Medium  
Status: Open

The script recorded a dialer-handoff failure even though timed replay proved the dialer became focused. The script should wait longer and evaluate focus after route handling settles.

Recommended fix:

- Poll `dumpsys window` for up to 7 seconds after the payload launch.
- Treat `com.google.android.dialer` focus as pass for direct `momo_pay_code` receiver payloads.
- Keep fatal-error checks separate from handoff checks so one timing issue does not mask the actual logcat state.

## Evidence Index

Fresh APK:

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/apk/release/app-release.apk`

Build/install/smoke:

- `build/reports/android-smoke-fresh-uat/smoke-20260615T124507Z.log`
- `build/reports/android-smoke-fresh-uat/smoke-20260615T124507Z.png`
- `build/reports/android-smoke-fresh-uat/smoke-20260615T124507Z.xml`
- `build/reports/android-smoke-fresh-uat/smoke-20260615T124507Z-window.txt`

Device baseline:

- `docs/release/evidence/fresh-apk-device-baseline-2026-06-15/`

Full device UAT:

- `docs/release/evidence/full-device-uat-fresh-apk-2026-06-15/device-sweep-events.jsonl`
- `docs/release/evidence/full-device-uat-fresh-apk-2026-06-15/device-sweep-logcat.txt`
- `docs/release/evidence/full-device-uat-fresh-apk-2026-06-15/*.png`
- `docs/release/evidence/full-device-uat-fresh-apk-2026-06-15/*.xml`

BioPay NFC:

- `docs/release/evidence/fresh-apk-biopay-nfc-auto-2026-06-15/summary.md`
- `docs/release/evidence/fresh-apk-biopay-nfc-auto-2026-06-15/payload-launch-logcat.txt`
- `docs/release/evidence/fresh-apk-biopay-nfc-focus-timing-2026-06-15/`

## Final Sign-Off State

Code/build/device state:

- Fresh APK built: **Completed**
- Fresh APK installed on Pixel 4a: **Completed**
- Release smoke: **Completed / Pass**
- Release contract tests: **Completed / Pass**
- Broad safe UI clickability sweep: **Completed / Pass with observations**
- NFC app-link/package readiness: **Completed / Pass**
- Direct receiver payload dialer handoff: **Completed / Pass after timed replay**

Open before full production/UAT sign-off:

- Physical NFC card write/read/verify/lock test on real card.
- Add or expose a visible write-card entry from the NFC UI.
- Harden the NFC UAT script timing logic.
