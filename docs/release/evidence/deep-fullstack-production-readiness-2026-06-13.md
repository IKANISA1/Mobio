# Mobio Deep Fullstack Production Readiness Test - 2026-06-13

Status: No-go for premium production release.

## Superseding Update - 2026-06-13 12:23 CAT

The APK/backend/BioPay blockers recorded later in this file were cleared in a
subsequent final pass:

- Linked Supabase backend gates passed against project `paysnhuxngsvzdpwlosv`.
- `supabase db push --linked --dry-run --yes` reported the remote database is
  up to date.
- BioPay live readiness passed with AWS, Supabase, and Android device proof
  required: 55 checks, 0 failures, 0 warnings.
- `flutter analyze` passed.
- Full `flutter test` passed all 257 tests.
- Final release APK was built at
  `build/app/outputs/flutter-apk/app-release.apk` with SHA-256
  `061da26a0bd9887c429b613586043b0762a905445ea305fc9eda9b68c2d975c3`.
- The final APK installed and passed physical Pixel 4a foreground smoke:
  `docs/release/evidence/android-smoke-2026-06-13-current/smoke-20260613T102258Z.log`.
- Role-aware APK readable-string scan found no service-role JWT, Supabase
  `sbp_` access token, Supabase DB password marker, or AWS key marker.

The remaining production blockers are now credential rotation/revocation for
secrets pasted into the session, final release credential/Play evidence, and
admin BioPay console UAT after an approved allowlisted admin OTP session.

## Superseding Device UAT Update - 2026-06-13 13:15 CAT

Current-APK passenger BioPay/profile device UAT is captured on Pixel 4a
`13111JEC215558`:

- Manifest:
  `docs/release/evidence/device-uat-2026-06-13-current/manifest.md`
- Captured flows: BioPay home, QR receive, QR scanner, NFC receive, face scan,
  face enrollment, profile, edit profile, and admin auth gate.
- The BioPay home capture confirms the unsupported Activity screen is absent and
  only Face, NFC, Get QR, and Scan actions are exposed.
- Face scan/enrollment captures show AWS Rekognition provider copy/metadata.

Admin BioPay operations remain blocked by live auth policy: the app reached the
admin auth gate, but the admin console requires an allowlisted WhatsApp OTP
session. No OTP send, allowlist mutation, or privileged bypass was performed.

This pass used the repo Flutter toolchain at `/Volumes/PRO-G40/flutter_3_44/bin/flutter`
with Dart 3.12.0 and the connected Pixel 4a `13111JEC215558`.

## Passed Gates

- `./scripts/qa/scan_secrets.sh`: passed.
- `./scripts/qa/check_secret_history.sh`: passed.
- `FLUTTER_BIN=/Volumes/PRO-G40/flutter_3_44/bin/flutter ./scripts/ci/verify_flutter.sh`: passed.
  - `flutter pub get`: passed.
  - `flutter gen-l10n`: passed.
  - `flutter analyze --no-fatal-infos --no-fatal-warnings`: completed with one info-level style finding in `test/helpers/mobile_scanner_test_channel.dart`.
  - `flutter test --coverage`: all tests passed, including preview/golden tests.
- Local backend function gate via `./scripts/ci/verify_backend.sh`: passed local secret scan, Deno checks, and Deno tests.
- Public Android release config check passed when sourcing `.env` with iOS and signing secret checks disabled.
- `ANDROID_SERIAL=13111JEC215558 REQUIRE_BIOPAY_LIVE=false ./scripts/qa/verify_biopay_live_readiness.sh`: passed static, focused Flutter, native permission, and Deno BioPay checks.
- Android release lint vital report: no issues found.
- Android manifest hardening observed:
  - `android:allowBackup="false"`.
  - cleartext traffic disabled through `network_security_config.xml`.
  - storage, ad ID, foreground-service, and record-audio permissions removed.
  - release signing is enforced by Gradle when `android/key.properties` is missing.

## Artifact Results

- A shrunk release AAB completed once:
  - Command: `FLUTTER_BIN=/Volumes/PRO-G40/flutter_3_44/bin/flutter MOBI_DISABLE_GRADLE_DAEMON=true ./scripts/release/build_android_release.sh appbundle`
  - Output shown by Flutter: `Built build/app/outputs/bundle/release/app-release.aab (79.8MB)`.
  - Captured hash before later APK attempts removed outputs: `87ccc988df742465a48e468fb233c0939d82f566c5db587b224848baa8c5e266`.
  - The file was not retained after later Gradle APK output churn, so this pass does not end with a durable AAB on disk.
- Fresh release APK generation did not complete reliably.
  - Default APK attempt failed in `:app:mergeReleaseResources` with missing generated `values*.xml` files under `build/app/intermediates/incremental/release/mergeReleaseResources/merged.dir/`.
  - Cleaned retries and no-shrink fallback attempts ended without producing `build/app/outputs/flutter-apk/app-release.apk`.
  - Subsequent output directories contained mapping, native symbols, SDK dependency metadata, and manifest logs, but no APK or AAB.

## Device Runtime State

- Connected device: Pixel 4a, Android 13.
- Installed package observed on device: `rw.mobi.app`, version code `12`, version name `1.0.0`, `primaryCpuAbi=arm64-v8a`, `apkSigningVersion=2`.
- The installed app timestamp was `2026-06-13 01:08:54`, so it predates this fresh build attempt.
- A running `rw.mobi.app` PID was observed and recent filtered logcat did not show a Mobio fatal exception.
- Because no fresh APK artifact was produced, this pass did not complete a fresh install/launch smoke test.

## No-Go Blockers

1. Linked Supabase live verification is not proved in this shell.
   - `supabase db push --linked --dry-run --yes` failed with login-role status 403 and requested `SUPABASE_DB_PASSWORD`.
   - `./scripts/ci/verify_backend.sh` skipped linked gates because `SUPABASE_ACCESS_TOKEN` and `SUPABASE_DB_PASSWORD` were not present in the shell.

2. Android APK release artifact generation is unstable.
   - The AAB path completed once, but APK generation repeatedly failed or ended without an APK.
   - Production readiness requires repeatable AAB/APK artifacts, retained outputs, and a clean install on a device.

3. Fresh physical-device install proof is missing.
   - The Pixel 4a has an older installed build, but this run could not install a newly generated APK.

4. BioPay live provider proof is incomplete.
   - Static and focused tests passed.
   - Live AWS provider proof, live Supabase edge proof, and live Android camera/NFC/USSD proof were warnings, not enforced passes.

5. Forward compatibility risk remains for Flutter Android builds.
   - Flutter warned that the app and several plugins still apply Kotlin Gradle Plugin in a way that will fail in a future Flutter version unless migrated to Built-in Kotlin compatible versions.

## Recommended Next Actions

1. Restore linked Supabase verification by supplying `SUPABASE_DB_PASSWORD` or an access path with sufficient privileges, then rerun `REQUIRE_LINKED_SUPABASE=true ./scripts/ci/verify_backend.sh`.
2. Stabilize Android release output generation in a clean build directory or CI runner, then rerun AAB and APK builds serially and retain artifacts.
3. After a fresh APK exists, run `ANDROID_SERIAL=13111JEC215558 ./scripts/release/smoke_android_release.sh`.
4. Run BioPay live checks with required live flags and evidence URLs/secrets in an approved environment.
5. Plan Kotlin Gradle Plugin migration before the current Flutter warning becomes a hard build failure.
