# Mobio Mobile Runtime Evidence

Date: 2026-06-08

## Current-Code Validation

- `dart analyze`: passed with no issues after the scheduled-trip edit, first-run setup route, permission onboarding, shared moderation sheets, admin detail sheets, adaptive shell, and readiness-matrix changes.
- Focused readiness suite: passed.
  - `test/release/mobile_readiness_contract_test.dart`
  - `test/core/router/app_router_test.dart`
  - `test/features/profile/widgets/profile_notification_consent_section_test.dart`
- Full Flutter suite: passed, `178` tests.

## Android Evidence

- Release APK build before the final first-run route addition: passed.
  - Output: `build/app/outputs/flutter-apk/app-release.apk`
  - Size: `69.9MB`
- Physical Android smoke before the final first-run route addition: passed.
  - Device: `Pixel 4a`, Android 13 API 33, serial `13111JEC215558`
  - Evidence log: `docs/release/evidence/android-smoke-20260608T000023Z.log`
  - Screenshot: `docs/release/evidence/android-smoke-20260608T000023Z.png`
  - Observed screen: WhatsApp login screen. Device status showed no internet connection, so post-login trip/profile/admin runtime flows could not be exercised on that device session.
- Current-code Android release refresh after the first-run route addition: blocked.
  - Command: `./scripts/release/build_android_release.sh apk`
  - Result: terminated by the 900-second guard without producing a new APK.
  - Output state: `build/app/outputs/flutter-apk/app-release.apk` missing because the script removes the prior output at the start of the build.
- Current-code Android debug refresh after the first-run route addition: blocked.
  - Command: `flutter build apk --debug --dart-define-from-file=<temporary file>`
  - Result: OS killed the build process after about 243 seconds.
  - Existing debug APK is stale from 2026-05-23 and was not used as current evidence.

## iOS Evidence

- iOS no-codesign release build before the final first-run route addition: passed.
  - Output: `build/ios/iphoneos/Runner.app`
  - Size: `37.5MB`
  - Evidence log: `docs/release/evidence/ios-release-verify-20260608T000100Z.log`
  - `FIREBASE_IOS_APP_ID` was absent, so the build was run with `REQUIRE_IOS_FIREBASE=false` and an empty Firebase iOS app id define.
- Physical iOS runtime launch attempt: blocked.
  - Device: wireless iPhone detected by Flutter.
  - Evidence log: `docs/release/evidence/ios-device-run-20260608T021600Z.log`
  - Result: no valid local Apple development signing certificate/provisioning profile was available for device deployment.
- iOS simulator runtime launch attempt: blocked.
  - Simulator: `iPhone 17`, iOS 26.3.
  - Result: simulator boot stayed in CoreSimulator data migration for more than five minutes; the waiting process was terminated to avoid leaving an orphaned session.

## Remaining Runtime Proof Gap

Current-code route-level runtime screenshots for trip edit, `/profile/setup`, permission dialogs, chat moderation sheets, admin report details, admin audit details, and large-screen shell still require either:

1. A successful current-code Android build on this machine after Gradle resource pressure is resolved, plus a connected device with internet/test account access.
2. A valid Apple development signing setup for physical iOS, or a healthy booted iOS simulator.
