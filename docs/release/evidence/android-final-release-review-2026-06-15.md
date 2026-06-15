# Android final release review - 2026-06-15

## Scope

This report covers the Android release state after the Codex visual-review fixes
for BioPay, NFC, QR, Wallet/Profile, notifications, and Mobio member ID
validation.

## Implemented review items

| Requirement | Current evidence | Status |
| --- | --- | --- |
| Device NFC listening screen uses a proper NFC icon and removes the reference chip label | `lib/features/biopay/biopay_nfc_screen.dart` uses `LucideIcons.nfc`; release contract rejects `Icons.nfc_rounded`. | Completed |
| Face scan first viewport is optimized by removing the redundant amount header/label section | `lib/features/biopay/biopay_face_scan_screen.dart` passes `showLabel: false` to `BioPayReceiveAmountField`. | Completed |
| Generated BioPay QR uses official Mobio transparent logo, not fabricated text | `lib/features/biopay/biopay_flow_shared.dart` renders `icon/mobi_logo_transparent.png` inside the QR overlay. | Completed |
| Generated BioPay QR uses official app color tokens | QR styling uses `AppColors.primaryDim` and `AppColors.primary`. | Completed |
| BioPay home header hierarchy separates primary and secondary text | `Pay & Get Paid` and `Instant & Secure` are separate text widgets with distinct styles. | Completed |
| Notification title underline removed | `MobiPageHeader` title style sets `decoration: TextDecoration.none`. | Completed |
| Notification rows route only to active app screens | `notification_service.dart` uses `_activeNotificationRoute` and `_isActiveNotificationPath`. | Completed |
| Wallet activity labels start with a capital letter | Wallet ledger rows use `_walletLedgerLabel(entry.reason)`. | Completed |
| Wallet invite panel includes a QR code so people can scan to get the app | `_InviteCard` renders `_InviteQrCode`, using `QrImageView` with the invite URL. | Completed |
| Six-digit Mobio member ID validation is semantic and shared | `lib/core/utils/mobio_member_id.dart` provides normalization, exact six-digit validation, user-facing error copy, and stable display fallback. Wallet transfer uses `LengthLimitingTextInputFormatter(mobioMemberIdLength)`, `normalizeMobioMemberId`, and `mobioMemberIdInputError`. | Completed |
| Physical NFC card write verification is more tolerant of slow or weak tags | `biopay_nfc_service.dart` retries readback six times with backoff across uncached, default, and cached NDEF reads before failing verification. | Completed |
| Android native package includes camera/NFC/QR dependencies and assets | `pubspec.yaml` declares `camera`, `mobile_scanner`, `flutter_nfc_kit`, `qr_flutter`, `lucide_icons`, and `icon/`; Android manifest includes camera/NFC/HCE declarations. Release APK contains `assets/flutter_assets/icon/mobi_logo_transparent.png` and `assets/flutter_assets/packages/lucide_icons/assets/lucide.ttf`. | Completed |

## Validation run

Commands completed successfully:

```bash
/Volumes/PRO-G40/flutter_3_44/bin/flutter analyze --no-pub \
  lib/core/utils/mobio_member_id.dart \
  lib/features/profile/profile_screen.dart \
  lib/features/profile/wallet_screen.dart \
  test/core/utils/mobio_member_id_test.dart \
  test/release/wallet_driver_plus_contract_test.dart
```

```bash
/Volumes/PRO-G40/flutter_3_44/bin/flutter test --no-pub --concurrency=1 \
  test/core/utils/mobio_member_id_test.dart \
  test/features/biopay/biopay_payment_surfaces_test.dart \
  test/release/scope_boundary_test.dart \
  test/release/wallet_driver_plus_contract_test.dart \
  test/release/notification_delivery_contract_test.dart
```

Result: 40 tests passed.

Additional NFC robustness validation completed after the NFC write verification
retry update:

```bash
/Volumes/PRO-G40/flutter_3_44/bin/flutter analyze --no-pub \
  lib/features/biopay/biopay_nfc_service.dart \
  test/release/scope_boundary_test.dart

/Volumes/PRO-G40/flutter_3_44/bin/flutter test --no-pub --concurrency=1 \
  test/features/biopay/biopay_nfc_card_payload_test.dart \
  test/features/biopay/biopay_payment_surfaces_test.dart \
  test/release/scope_boundary_test.dart
```

Result: 32 tests passed.

```bash
./scripts/qa/scan_secrets.sh
```

Result: `secret-pattern scan passed`.

## Android artifacts

Release artifacts were built through `./scripts/release/build_android_release.sh`
so the required public runtime defines were injected from `.env`.

Release shrinking was disabled with `ANDROID_RELEASE_SHRINK=false` because the
shrink-enabled build stalled during release packaging. The artifacts below are
signed release artifacts but larger than the shrink-enabled target.

| Artifact | Path | Size | SHA-256 |
| --- | --- | ---: | --- |
| Google Play AAB | `build/app/outputs/bundle/release/app-release.aab` | 84,954,029 bytes | `24e376e2f1dae4d67cdfcc17d76d81aea142b0b95481da1e2d6796fc6fab18d1` |
| Sideload/UAT APK | `build/app/outputs/flutter-apk/app-release.apk` | 97,735,009 bytes | `bf73c5bc23c147e46471e14b7206cce6420984cac6c55bd71e79f65cc74fc83d` |

APK signature verification was run as part of the Pixel 4a release smoke:

- APK Signature Scheme v2: verified.
- Signer DN: `CN=MOBI Rwanda, OU=Mobile, O=MOBI, L=Kigali, ST=Kigali, C=RW`.
- Signer certificate SHA-256:
  `da9e5eab50d08505bf0b787ceab5db5b40778ebe77629572168a7237d77981c0`.

APK asset verification confirmed the signed release contains:

- `assets/flutter_assets/icon/mobi_logo_transparent.png`
- `assets/flutter_assets/packages/lucide_icons/assets/lucide.ttf`

## Pixel 4a release smoke

Signed release smoke passed on the attached Pixel 4a (`13111JEC215558`) using
`build/app/outputs/flutter-apk/app-release.apk`.

Evidence:

- Main smoke screenshot:
  `docs/release/evidence/android-final-release-device-uat-2026-06-15/smoke-20260615T182716Z.png`
- Main smoke UI tree:
  `docs/release/evidence/android-final-release-device-uat-2026-06-15/smoke-20260615T182716Z.xml`
- Main smoke window snapshot:
  `docs/release/evidence/android-final-release-device-uat-2026-06-15/smoke-20260615T182716Z-window.txt`
- Foreground state capture:
  `docs/release/evidence/android-final-release-device-uat-2026-06-15/release-smoke-foreground-summary.txt`

Verified state:

- Installed package: `rw.mobi.app`, versionCode `14`, versionName `1.0.0`.
- Foreground activity:
  `rw.mobi.app/rw.mobi.app.MainActivity`.
- Home first viewport shows the top `Passenger` / `Driver` toggle instead of a
  search bar.
- The nearby-driver surface and driver-supply card render on device.
- No fatal app error, ANR, or Flutter error was found by the smoke helper.

## Release notes and blockers

- Google Play upload artifact: `build/app/outputs/bundle/release/app-release.aab`.
- Pixel 4a release smoke is complete for signed APK install, signature
  verification, launch, foreground stability, screenshot, UI tree, and first
  viewport capture.
- Full manual UAT is not complete: physical QR scanning, physical NFC card
  write/read, live face scan, wallet transfer validation on device, and
  notification-routing taps still need operator capture on the handset.
- Google Play upload was not performed because it requires explicit human
  approval and Play Console or service-account access.
- Flutter emitted a future compatibility warning for plugins that still apply
  the Kotlin Gradle Plugin: `app_settings`, `device_info_plus`,
  `firebase_analytics`, `firebase_remote_config`, `flutter_nfc_kit`,
  `mobile_scanner`, and `share_plus`. This warning did not block the current
  Android release build but should be tracked before a future Flutter upgrade.
- Existing tracked NFC evidence from earlier on 2026-06-15 confirms NFC
  feature availability, app-link/NDEF/custom-scheme routing, and manual NFC
  capture for a prior APK hash. The current APK additionally has code-level NFC
  readback retry coverage, but a fresh physical card write/read capture for
  hash `bf73c5bc23c147e46471e14b7206cce6420984cac6c55bd71e79f65cc74fc83d`
  remains open.

## Pixel 4a execution commands

The Pixel 4a smoke command already passed for this review:

```bash
ANDROID_SERIAL=13111JEC215558 \
ANDROID_RELEASE_APK=build/app/outputs/flutter-apk/app-release.apk \
ANDROID_SMOKE_EVIDENCE_DIR=docs/release/evidence/android-final-release-device-uat-2026-06-15 \
./scripts/release/smoke_android_release.sh
```

Use the existing state-capture helper for each remaining manual screen
checkpoint. Navigate the app on the Pixel, then run one command per checkpoint:

```bash
ANDROID_SERIAL=13111JEC215558 \
ANDROID_UAT_EVIDENCE_DIR=docs/release/evidence/android-final-release-device-uat-2026-06-15 \
ANDROID_UAT_STEP=home \
./scripts/qa/capture_android_uat_state.sh

ANDROID_SERIAL=13111JEC215558 \
ANDROID_UAT_EVIDENCE_DIR=docs/release/evidence/android-final-release-device-uat-2026-06-15 \
ANDROID_UAT_STEP=biopay-home \
./scripts/qa/capture_android_uat_state.sh

ANDROID_SERIAL=13111JEC215558 \
ANDROID_UAT_EVIDENCE_DIR=docs/release/evidence/android-final-release-device-uat-2026-06-15 \
ANDROID_UAT_STEP=biopay-face-scan \
./scripts/qa/capture_android_uat_state.sh

ANDROID_SERIAL=13111JEC215558 \
ANDROID_UAT_EVIDENCE_DIR=docs/release/evidence/android-final-release-device-uat-2026-06-15 \
ANDROID_UAT_STEP=biopay-nfc-listening \
./scripts/qa/capture_android_uat_state.sh

ANDROID_SERIAL=13111JEC215558 \
ANDROID_UAT_EVIDENCE_DIR=docs/release/evidence/android-final-release-device-uat-2026-06-15 \
ANDROID_UAT_STEP=biopay-qr \
./scripts/qa/capture_android_uat_state.sh

ANDROID_SERIAL=13111JEC215558 \
ANDROID_UAT_EVIDENCE_DIR=docs/release/evidence/android-final-release-device-uat-2026-06-15 \
ANDROID_UAT_STEP=wallet-invite-qr \
./scripts/qa/capture_android_uat_state.sh

ANDROID_SERIAL=13111JEC215558 \
ANDROID_UAT_EVIDENCE_DIR=docs/release/evidence/android-final-release-device-uat-2026-06-15 \
ANDROID_UAT_STEP=wallet-member-id-validation \
./scripts/qa/capture_android_uat_state.sh

ANDROID_SERIAL=13111JEC215558 \
ANDROID_UAT_EVIDENCE_DIR=docs/release/evidence/android-final-release-device-uat-2026-06-15 \
ANDROID_UAT_STEP=notifications-routing \
./scripts/qa/capture_android_uat_state.sh
```

Required manual assertions for the checkpoint captures:

- BioPay home shows `Pay & Get Paid` as primary text and `Instant & Secure` as
  secondary text.
- Face scan start button is visible in the first viewport after amount entry.
- Device NFC screen shows the clean animated listening state and proper NFC
  icon.
- BioPay QR is scannable and uses the Mobio transparent logo, not fabricated
  text.
- Wallet invite card shows the invite QR code and the share/copy actions.
- Wallet transfer rejects non-six-digit receiver IDs with clear Mobio ID copy.
- Notification rows navigate only to active screens.
