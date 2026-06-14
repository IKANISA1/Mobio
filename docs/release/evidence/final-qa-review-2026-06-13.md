# Final QA Review - 2026-06-13

## Scope

Final native Flutter production-readiness QA for MOBI Android after the UI review updates, BioPay face enrollment/face scan readiness work, AWS Rekognition wiring, and release APK rebuild.

Skills/workflows used:

- firmos-flutter release workflow
- golden visual regression workflow
- integration/e2e release smoke workflow
- targeted release security checks

## Implementation Review

Implemented and verified:

- BioPay face enrollment route and entry points remain native Flutter surfaces.
- BioPay face scan route remains native Flutter and calls the Supabase `biopay-face-provider` edge boundary.
- Live face provider health proves `FACE_PROVIDER=aws_rekognition` and production-ready provider configuration.
- BioPay payment remains USSD dialer handoff only; no in-app settlement flow was introduced.
- Android native permission surface includes camera and NFC and excludes SMS read/receive permissions.
- iOS native permission/entitlement surface includes camera and NFC declarations.
- Physical-device smoke proof was refreshed on Pixel 4a.
- Production APK was rebuilt after the final code/test corrections.

Corrective QA changes made during this pass:

- Removed a dead `_providerStatus` field from `lib/features/biopay/biopay_screen.dart`.
- Updated stale BioPay release contract assertions for the current amount-field UI and face-enrollment copy.
- Added an intentional deprecation ignore for the legacy admin-finance redirect assertion.
- Stabilized visual golden tests by evicting the logo asset/image cache between cases.
- Refreshed affected visual goldens for the updated UI state.

## Validation Evidence

- `dart analyze`: PASS, no issues found.
- `git diff --check`: PASS.
- Full Flutter suite: PASS, `flutter test --no-pub --concurrency=1`, 336 tests passed.
- Strict BioPay live readiness: PASS, 55 checks, 0 failures, 0 warnings.
- Deno edge compile/tests for `biopay-face-provider`: PASS.
- Live AWS/Supabase face provider health: PASS, HTTP 200, AWS Rekognition provider.
- Pixel 4a install/smoke: PASS.

## APK

- Path: `build/app/outputs/flutter-apk/app-release.apk`
- Size: 87,819,892 bytes
- Built: 2026-06-13 19:51:40 Africa/Kigali
- SHA-256: `950e6f878ab416f98eb02e5292194b170802169072d909430e9c1f1ef8b1cabd`
- Signature: APK Signature Scheme v2 verified, signer `CN=MOBI Rwanda, OU=Mobile, O=MOBI, L=Kigali, ST=Kigali, C=RW`

## Security Checks

The final APK was scanned with `strings` for local secret values and secret labels.

- AWS access key value: not found
- AWS secret key value: not found
- Supabase service-role key value: not found
- Supabase access token value: not found
- Literal AWS/Supabase service-token labels: not found

Expected public configuration remains embedded where required for the client app, including the Supabase URL and anon key.

## Device Evidence

- Device: Pixel 4a, serial `13111JEC215558`
- Android: 13, API 33
- Package: `rw.mobi.app`
- Installed version: `1.0.0`, versionCode `12`
- Evidence directory: `docs/release/evidence/android-smoke-2026-06-13-final-qa/`
- Smoke log: `docs/release/evidence/android-smoke-2026-06-13-final-qa/smoke-20260613T175236Z.log`
- Screenshot: `docs/release/evidence/android-smoke-2026-06-13-final-qa/smoke-20260613T175236Z.png`

## Live BioPay Evidence

- Evidence file: `docs/release/evidence/biopay-live-readiness-2026-06-13-final-qa.md`
- Checks run: 55
- Failures: 0
- Warnings: 0
- AWS live proof: PASS
- Supabase edge proof: PASS
- Android camera/NFC/USSD proof: PASS

## Remaining UAT Boundary

Ready for final on-device UAT. The remaining checks require a human tester on the physical device:

- Complete WhatsApp OTP login with a real allowed number.
- Complete face enrollment with the tester's consent and live camera positioning.
- Run a real face scan/match attempt against that enrolled profile.
- Confirm a real USSD payment outside the app before marking a BioPay request externally confirmed.

## Result

GO for final device UAT with the APK above.
