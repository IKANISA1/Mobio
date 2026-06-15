# BioPay NFC, Face Scan, Enrollment, and Mobio Plus Defect Report

Date: 2026-06-15  
Repo: `/Volumes/PRO-G40/MOBI/mobi_app`  
Status: Code fixes applied and final APK installed on Pixel 4a; physical card write still needs a real-card hold test.

## 2026-06-15 Final Implementation Update

- Split NFC into two explicit paths:
  - Device NFC receive: Android HCE `BioPayHostApduService` with AID `F04D4F42494F00`; iOS remains reader-only unless Apple grants HCE entitlement.
  - Physical NFC cards: NDEF card writer/reader remains in the dedicated write-card flow.
- Added Android closed-app NFC dispatch:
  - `NDEF_DISCOVERED` for Mobio BioPay app links.
  - `TECH_DISCOVERED` for `android.nfc.tech.Ndef` and `android.nfc.tech.IsoDep`.
  - Native launch-intent parsing queues the NFC payload until Flutter is ready, then opens the BioPay handoff.
- Added foreground native reader mode while the app is open, with Flutter polling fallback.
- Avoided the Android reader/HCE conflict: when Device NFC receive is activated, foreground reader mode is suspended so Android host routing can advertise the HCE AID.
- Device NFC receive now persists after the user leaves the screen; the Android HCE service remains registered and available while NFC, screen-on, and device-unlock requirements are satisfied.
- Redesigned MoMo QR:
  - Generated QR payload is now direct MoMo USSD `tel:*182...%23`, not token JSON.
  - Scanner supports the new `tel:` QR and opens USSD directly.
  - Legacy token QR payloads remain resolvable.
  - QR visual uses app primary/secondary gradient modules, high error correction, and a small low-opacity `m` center mark sized to avoid blocking scanability.

Platform boundary:

- Android can launch Mobio from a closed-but-not-force-stopped state through OS NFC dispatch. It cannot keep an app-owned reader loop alive when the process is dead; the correct closed-app mechanism is manifest NFC dispatch.
- Android `dumpsys nfc` on the Pixel 4a reports `mIsAlwaysOnSupported=false`, so hardware-level always-on NFC is not available on this test device.
- iOS cannot run a continuous closed-app NFC reader loop. iOS can handle supported system NFC/background tag handoff patterns, but general continuous reading requires the app foreground session.

Final APK:

- Path: `build/app/outputs/flutter-apk/app-release.apk`
- SHA-256: `a19c1ea8673eb2c3d187bb89063c12dbc8f914e4dd1e28d4d36df7bc926ef4b5`
- Installed on Pixel 4a `13111JEC215558`: `Success`

Final validation:

- Focused tests passed: `test/features/biopay/biopay_device_nfc_service_test.dart`, `test/features/biopay/biopay_nfc_card_payload_test.dart`, `test/features/biopay/biopay_payment_surfaces_test.dart`, `test/release/scope_boundary_test.dart`.
- Analyzer passed on touched BioPay, NFC, QR, face, Driver Plus, and contract-test files.
- Pixel 4a package registration confirms `NDEF_DISCOVERED`, `TECH_DISCOVERED`, `BioPayHostApduService`, and `android.permission.BIND_NFC_SERVICE`.
- Pixel 4a NFC service confirms HCE AID `F04D4F42494F00` registered for `rw.mobi.app`.

## Reported Failures

- Activate NFC receive payment shows `Enter a valid RWF amount`.
- Scan-to-pay face flow opens as a selfie instead of scanning the payer face.
- No enrolled BioPay face matched error has no enrollment fallback CTA.
- Face enrollment capture/finish button is below the first viewport because the top information card consumes too much space.
- Face enrollment finish button becomes inactive after the three checks.
- Write NFC card still fails with `NFC write failed`.
- Mobio Plus shows `Pay with Tokens` even when token balance is lower than the plan price.

## Immediate Fixes Applied

### Activate NFC receive payment

Files:

- `lib/features/biopay/biopay_nfc_screen.dart`

Changes:

- Defaulted the receive amount to `RWF 1,500` so the NFC activation flow starts from a valid amount instead of an empty input.
- Kept amount validation explicit, but stopped mapping non-amount NFC/RPC/tag failures to the amount error.
- Added specific labels for receiver required, NFC disabled, NFC unsupported, tag not writable, tag too small, and request creation failures.
- Reduced receive-payment NFC payload to a compact HTTPS payment-token app link plus Android Application Record where capacity allows.
- Added a visible `Write NFC Card` action from the NFC screen.

### Write NFC card

Files:

- `lib/features/biopay/biopay_nfc_card_payload.dart`
- `lib/features/biopay/biopay_nfc_service.dart`

Changes:

- Replaced the oversized fixed NDEF payload strategy with capacity-aware payload selection.
- Full write candidate: HTTPS app link + custom MIME JSON + Android Application Record.
- Small/unknown capacity candidate: HTTPS app link + Android Application Record.
- Tiny capacity fallback: HTTPS app link only.
- Verification now accepts the semantic receiver value parsed from the URI/app link, not only from duplicated text/MIME JSON.
- Added retry when reading NDEF records immediately after write, because some tags/devices do not expose the fresh message instantly.

### Face scan / scan-to-pay

Files:

- `lib/features/biopay/biopay_face_scan_screen.dart`

Changes:

- Changed face matching to prefer the rear camera so the operator can scan the payer face instead of taking a selfie.
- Added `Enroll BioPay face` CTA when the match result is not enrolled/matched.
- The fallback CTA routes to `/biopay/enroll`.

### Face enrollment UX and completion

Files:

- `lib/features/biopay/biopay_face_enroll_screen.dart`

Changes:

- Removed the top enrollment status card from the first viewport.
- Moved the primary enrollment action directly under the header so `Start Enrollment`, `Capture center`, `Capture turn`, and `Finish enrollment` remain visible without scrolling.
- After enrollment succeeds, the primary button now becomes `Done` and returns from the flow instead of becoming inactive.

### Mobio Plus token payment visibility

Files:

- `lib/features/profile/driver_plus_screen.dart`

Changes:

- `Pay with Tokens` now renders only when `walletBalanceTokens >= tokenCost`.
- If the user has insufficient tokens, only `Pay with MoMo` is displayed.
- Backend insufficient-token protection remains unchanged.

## NFC Research Findings

Sources reviewed:

- Android NFC basics: https://developer.android.com/develop/connectivity/nfc/nfc
- Android advanced NFC overview: https://developer.android.com/develop/connectivity/nfc/advanced-nfc
- Android `Ndef` API: https://developer.android.com/reference/android/nfc/tech/Ndef
- Android `NdefFormatable` API: https://developer.android.com/reference/android/nfc/tech/NdefFormatable
- `flutter_nfc_kit` package: https://pub.dev/packages/flutter_nfc_kit
- `FlutterNfcKit` API: https://pub.dev/documentation/flutter_nfc_kit/latest/flutter_nfc_kit/FlutterNfcKit-class.html

Critical NFC points for this app:

- NFC write must check device NFC availability before polling.
- Tag presence is short-lived; the user must keep the card still until write and verification finish.
- Android NDEF writing is constrained by tag writability and maximum NDEF size.
- Common small cards can fail when the app writes repeated data across multiple records.
- Formatting blank/non-NDEF tags is device/tag dependent. Android exposes `NdefFormatable`, but support is not guaranteed for every tag type.
- Locking a tag read-only is not universally supported and must remain optional.
- Immediate read-after-write can fail on some tag/device combinations; retrying readback is safer.
- A URI/app-link record is the most compact interoperable payload for this app because the backend token or receiver data can be resolved by the app after launch.
- Android app-link verification and `NDEF_DISCOVERED` filters are necessary for tap-to-open behavior but do not prove physical write success.
- `flutter_nfc_kit` is still appropriate for this stage because it exposes availability, polling, decoded NDEF read/write, tag metadata, and read-only operations. A custom native Android plugin should only be added if physical card tests show missing support for `NdefFormatable` formatting or low-level tag-specific write fallback.

## Package and Extension Decision

No new package should be added before the next physical card test.

Keep:

- `flutter_nfc_kit`
- `ndef`

Potential native extension only if needed:

- Add an Android-only platform channel for direct `Ndef`, `NdefFormatable`, `MifareUltralight`, and tag-tech diagnostics if real-card UAT still fails after the compact NDEF patch.
- The native extension should return structured failure reasons: tag lost, not NDEF, not formatable, not writable, read-only, insufficient capacity, write I/O failure, verification mismatch.

## Validation Completed

Commands:

```sh
/Volumes/PRO-G40/flutter_3_44/bin/dart format \
  lib/features/biopay/biopay_nfc_card_payload.dart \
  lib/features/biopay/biopay_nfc_service.dart \
  lib/features/biopay/biopay_nfc_screen.dart \
  lib/features/biopay/biopay_face_scan_screen.dart \
  lib/features/biopay/biopay_face_enroll_screen.dart \
  lib/features/profile/driver_plus_screen.dart \
  test/features/biopay/biopay_payment_surfaces_test.dart \
  test/features/biopay/biopay_nfc_card_payload_test.dart \
  test/release/scope_boundary_test.dart \
  test/release/wallet_driver_plus_contract_test.dart
```

```sh
/Volumes/PRO-G40/flutter_3_44/bin/flutter test --no-pub --concurrency=1 \
  test/features/biopay/biopay_nfc_card_payload_test.dart \
  test/features/biopay/biopay_payment_surfaces_test.dart \
  test/release/wallet_driver_plus_contract_test.dart \
  test/release/scope_boundary_test.dart
```

Result: Passed, 36 tests.

```sh
/Volumes/PRO-G40/flutter_3_44/bin/flutter analyze --no-pub \
  lib/features/biopay/biopay_nfc_card_payload.dart \
  lib/features/biopay/biopay_nfc_service.dart \
  lib/features/biopay/biopay_nfc_screen.dart \
  lib/features/biopay/biopay_face_scan_screen.dart \
  lib/features/biopay/biopay_face_enroll_screen.dart \
  lib/features/profile/driver_plus_screen.dart \
  test/features/biopay/biopay_payment_surfaces_test.dart \
  test/features/biopay/biopay_nfc_card_payload_test.dart \
  test/release/scope_boundary_test.dart \
  test/release/wallet_driver_plus_contract_test.dart
```

Result: No issues found.

Fresh patched APK build:

```sh
PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin ANDROID_RELEASE_SHRINK=false ./scripts/release/build_android_release.sh apk
```

Result: Passed.

APK:

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/apk/release/app-release.apk`
- SHA-256: `2005d7af4556d26adc369e7112cadd83586fcc1658d92cc01a0f04bb7b953121`

Device install status:

- Completed after the Pixel 4a reconnected.
- Device: `13111JEC215558`, Pixel 4a.
- Install command: `adb -s 13111JEC215558 install -r build/app/outputs/flutter-apk/app-release.apk`.
- Result: `Success`.
- Package/app-link/NFC evidence: `docs/release/evidence/patched-biopay-device-uat-2026-06-15/`.

Additional device proof:

- Android launched `rw.mobi.app` from an `android.nfc.action.NDEF_DISCOVERED` HTTPS payload:
  `https://mobio.ikanisa.com/biopay/nfc?type=momo_number&receiver=0788767846`.
- Mobio then opened the Android dialer with:
  `tel:*182*1*1*0788767846%23`.
- This proves NFC card read/app-link/dialer handoff works on the installed patched APK.

Smoke caveat:

- The release smoke script failed its foreground check twice because the device moved into the dialer during NFC/USSD handoff.
- After backing out of the dialer and moving the NFC card away from the antenna, direct app launch foreground proof passed:
  `mCurrentFocus=Window{... rw.mobi.app/rw.mobi.app.MainActivity}`.
- Direct UI capture is saved in `docs/release/evidence/patched-biopay-device-uat-2026-06-15/direct-ui/`.
- The device was on the WhatsApp login screen, so authenticated BioPay/Mobio Plus UI navigation could not be completed by ADB without a login/OTP session.

## Remaining UAT Plan

### Phase 1: Fresh APK

Build a new release APK from this patch and install it on the Pixel 4a.

### Phase 2: Non-mutating screen verification

Verify:

- NFC screen defaults to a valid amount.
- NFC screen shows `Write NFC Card`.
- Face scan uses rear camera.
- Face unmatched state shows `Enroll BioPay face`.
- Face enroll first viewport shows the capture button without scrolling.
- Face enroll success shows `Done`.
- Mobio Plus hides `Pay with Tokens` when balance is insufficient.

### Phase 3: Physical NFC write UAT

Use at least three card types:

- Known writable NTAG213/Ultralight-class tag.
- Larger NTAG215/216-class tag if available.
- Previously failed card.

For each card:

- Confirm NFC is enabled.
- Write MoMo number card.
- Read back and verify receiver.
- Write MoMo Pay code card.
- Read back and verify receiver.
- Tap card from outside the app and confirm app opens the correct route.
- If lock is supported, lock only a disposable test card and confirm the user understands it is irreversible.

### Phase 4: If NFC still fails

Add the Android native diagnostic platform channel and capture:

- `Tag.getTechList()`
- `Ndef.get(tag)` availability
- `Ndef.isWritable`
- `Ndef.getMaxSize`
- current `NdefMessage` record summary
- `NdefFormatable.get(tag)` availability
- exact exception class and message for write and readback

Only after this evidence should the project add custom tag-tech write fallback.

## Current Risk Register

- Physical NFC remains unproven until a real card is held on-device after this patch.
- Very small NFC tags may still be too small even for an app-link URI. The app now reports `NFC tag is too small` instead of a generic write failure when capacity is known.
- Blank non-NDEF cards may require Android native `NdefFormatable` support. `flutter_nfc_kit` may not expose every formatting path needed for every tag.
- Face recognition quality and enrollment acceptance still depend on the configured BioPay face provider and lighting/camera quality.
