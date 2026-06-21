# Google Play optimization evidence - 2026-06-21

Timestamp: 2026-06-21 15:59 CAT
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

## Upload status

The optimized v17 AAB is ready for Google Play upload, but upload could not be completed from this machine in this run:

- Fastlane `deploy` failed before upload because the available credential data is not a Google Play service-account JSON: `Invalid Google Credentials file provided - no credential type found.`
- Direct Google Play Developer API upload was also blocked because both local gcloud accounts require interactive reauthentication and cannot refresh tokens non-interactively.

Remaining action: provide or create a valid Google Play Android Publisher service-account JSON with access to package `rw.mobi.app`, or reauthenticate gcloud interactively, then rerun the production upload.

## Review-state note

Google Play deep-link checks may still show the old production version `15 (1.0.0)` until a build containing versionCode `17` is uploaded and processed. The repo and built v17 APK/AAB contain the fixed manifest and verified assetlinks configuration.
