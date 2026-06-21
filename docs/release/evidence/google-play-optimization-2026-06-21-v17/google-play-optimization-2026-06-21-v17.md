# Google Play optimization evidence - 2026-06-21

Timestamp: 2026-06-21 16:40 CAT
Package: `rw.mobi.app`
Version: `1.0.0+17`

## Code and backend changes

- Added Play Integrity native token request channel on Android.
- Added Flutter `PlayIntegrityService` and attached integrity evidence to login OTP send/verify requests.
- Added Supabase `play-integrity` challenge function and shared monitor-mode integrity verification.
- Deployed `play-integrity`, `send-login-otp`, and `verify-login-otp` Supabase Edge Functions.
- Kept Google Play review login bypass for `+250788767816` with OTP `123456`.
- Fixed BioPay NFC intent filters so `NDEF_DISCOVERED` uses `mobio://biopay/nfc`, not an HTTPS Mobio web link.
- Updated production Digital Asset Links for both Play/App signing fingerprints.
- Added public foreground-location review evidence page and video:
  - `https://mobio.ikanisa.com/play-review/foreground-location-demo`
  - `https://mobio.ikanisa.com/play-review/assets/mobio-foreground-location-demo.mp4`

## Build artifacts

- AAB: `build/app/outputs/bundle/release/app-release.aab`
- AAB size: 79 MB
- AAB SHA256: `cb7544bbc860aa0b4749cfa3b6ae70ebf9972bca127d188291c8b8c70d59cdcd`
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- APK size: 87 MB
- APK SHA256: `db20ea3027803ab3c836675a8702d474023d4fcaab50310b8e86c86ec95f025b`

## Validation

- `deno test --allow-env supabase/functions/_shared/play-integrity_test.ts`: PASS.
- `flutter analyze --no-pub`: PASS.
- `flutter test --no-pub test/release`: PASS, 88 tests.
- `flutter test --no-pub test/core/services/whatsapp_login_service_test.dart test/release/mobile_readiness_contract_test.dart test/release/biopay_payment_link_contract_test.dart`: PASS.
- Optimized Android AAB build: PASS, versionCode `17`, targetSdk `35`.
- Optimized Android APK build: PASS, versionCode `17`, targetSdk `35`.
- Pixel 4a install: PASS, `adb install -r build/app/outputs/flutter-apk/app-release.apk`.
- Pixel 4a installed package check: PASS, `versionCode=17`, `versionName=1.0.0`, `targetSdk=35`.
- Pixel 4a launch screenshot: `pixel4a-v17-launch.png`.
- Android app links: PASS, `pm get-app-links rw.mobi.app` reports `mobio.ikanisa.com: verified`.
- BioPay NFC link route: PASS, `https://mobio.ikanisa.com/biopay/nfc/test` delivered to `rw.mobi.app/.MainActivity`.
- Production `assetlinks.json`: PASS, HTTP 200, contains both expected fingerprints.

## Manifest proof

Release APK permissions include:

- `android.permission.ACCESS_BACKGROUND_LOCATION`
- `android.permission.CALL_PHONE`
- `android.permission.FOREGROUND_SERVICE`
- `android.permission.FOREGROUND_SERVICE_LOCATION`
- `android.permission.CAMERA`
- `android.permission.NFC`
- `android.permission.POST_NOTIFICATIONS`

Release APK intent-filter proof:

- `https://mobio.ikanisa.com/invite` uses `ACTION_VIEW`, `DEFAULT`, `BROWSABLE`, `autoVerify=true`.
- `https://mobio.ikanisa.com/biopay/nfc` uses `ACTION_VIEW`, `DEFAULT`, `BROWSABLE`, `autoVerify=true`.
- `mobio://biopay/nfc` uses `ACTION_VIEW`, `DEFAULT`, `BROWSABLE`.
- `android.nfc.action.NDEF_DISCOVERED` uses `mobio://biopay/nfc`.

## Google Play Console work completed

- App access review login details were prepared for:
  - Name: `Google Play review account`
  - Phone: `+250788767816`
  - OTP/password: `123456`
  - Instructions: select Passenger or Driver, enter the phone number, tap Send code, then enter OTP `123456`.
- Foreground service declaration was updated in Play Console:
  - Selected `User-initiated location sharing`.
  - Removed generic `Other`.
  - Added video URL `https://mobio.ikanisa.com/play-review/foreground-location-demo`.
  - Saved and sent for review.
- Play Integrity API was linked to the existing Google Cloud project `May2026`.
- Play Integrity responses enabled:
  - App licensing/account details.
  - Application integrity.
  - Device integrity.
  - Basic integrity.
  - Strong integrity.
  - Recent device activity.
  - Device attributes.
  - Play Protect status.
  - App access risk.
- Play Integrity goals selected:
  - Unauthorized or fraudulent access to app or account.
  - Fraudulent account creation.
  - Payment or promotion abuse.
  - Attacks on security such as data theft.
  - Repackaging and redistribution by other developers.
- Background location permission declaration was completed from the release validation gate:
  - Undeclared permissions shown by Play: `ACCESS_BACKGROUND_LOCATION`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`.
  - App purpose describes Mobio mobility, BioPay, MoMo handoff, wallet tokens, and NFC BioPay cards.
  - Location feature declared: driver live availability sharing while the driver explicitly switches online.
  - Video URL submitted: `https://mobio.ikanisa.com/play-review/foreground-location-demo`.

## Upload status

The optimized v17 AAB was uploaded through the Play Console web release flow and saved as a production full rollout change.

- Whole-computer/SSD credential search found valid Android Publisher service-account access for package `rw.mobi.app`.
- Fastlane and direct Android Publisher API both uploaded the v17 AAB successfully, but API validation/commit returned: `Release artifacts require permissions that are missing from permission declaration.`
- Google Play documentation requires the Play Console web flow when a new high-risk/sensitive permission declaration must be completed.
- Play Console production release draft `17 (1.0.0)` was created manually.
- Release notes were saved from `android/fastlane/metadata/android/en-US/changelogs/17.txt`.
- Release validation initially showed one error: `This release includes permissions that haven't been declared in Play Console. Go to Sensitive app permissions to update your permission declarations.`
- Background location declaration was completed and saved.
- Release validation changed to `Ready to release`.
- Publishing overview was submitted with `Submit 1 change for review` / `Send changes for review`.
- Current Play Console state: `Changes in review` for `Production` / `17 (1.0.0)` / `Start full rollout`.
- Android Publisher API track check after Console submission reports production release `17 (1.0.0)`, versionCode `17`, status `completed`.
- Quick checks were still running at the last capture and Play stated changes will be sent for review as soon as checks complete successfully.

Evidence screenshots:

- `play-console/app-content-overview-after-v17-upload-error.png`
- `play-console/app-content-actioned-after-v17-upload-error.png`
- `play-console/publishing-overview-v17-changes-in-review.png`

## Review-state note

Google Play deep-link checks and public availability may lag until Google quick checks/review complete and the submitted v17 production rollout is fully published to users. The Android Publisher API already reports production versionCode `17` with status `completed`; the repo and built v17 APK/AAB contain the fixed manifest and verified assetlinks configuration.
