# Android Play Production Release - 2026-06-21 - v15

## Result

- Package: `rw.mobi.app`
- Version: `1.0.0+15`
- Google Play track: `production`
- Release status requested: `completed`
- Fastlane result: `Successfully finished the upload to Google Play`
- Track verification: `google_play_track_version_codes` returned `[15]` for `production`

## Artifacts

- AAB: `build/app/outputs/bundle/release/app-release.aab`
  - SHA-256: `f38b927bda23b8b17b3d9db3bafd8d05cca1605ec9cb14191cb182ecf4c1bef2`
  - Size: `81M`
- APK: `build/app/outputs/flutter-apk/app-release.apk`
  - SHA-256: `3d481b80732e8e903d153cabf349a4cc6a04ae53075b8fcc7456d002b507b6e0`
  - Size: `94M`

## Release Manifest

The final uploaded release manifest no longer declares the Play-blocking high-risk permissions:

- Removed: `android.permission.CALL_PHONE`
- Removed: `android.permission.ACCESS_BACKGROUND_LOCATION`
- Kept: foreground location, camera, NFC, notifications, foreground service, and foreground service location.

MoMo and NFC handoffs remain `tel:*182...%23` links. Android opens the external phone/USSD dialer with `ACTION_DIAL`, without requesting direct phone-call permission.

## Verification

- `flutter analyze --no-pub`: passed
- `verify_release_config.sh`: passed
- `scan_secrets.sh`: passed
- Focused BioPay/mobile readiness tests: passed
- Full non-golden Flutter suite: `338` tests passed
- APK signature verification: passed with APK Signature Scheme v2
- Device smoke:
  - Device: Pixel 4a `13111JEC215558`
  - Android: `13`
  - Installed version: `versionCode=15`, `versionName=1.0.0`, `targetSdk=35`
  - Result: passed
  - Log: `build/reports/android-smoke/smoke-20260621T111728Z.log`
  - Screenshot: `build/reports/android-smoke/smoke-20260621T111728Z.png`
  - UI tree: `build/reports/android-smoke/smoke-20260621T111728Z.xml`

## Residual Follow-Up

The app launched and Play production accepted v15, but device logcat showed Firebase Installations / Firebase Messaging failing with `403 CONSUMER_SUSPENDED` for the configured Firebase project. This affects Firebase token registration and push messaging until the Firebase project/API key is restored or replaced.
