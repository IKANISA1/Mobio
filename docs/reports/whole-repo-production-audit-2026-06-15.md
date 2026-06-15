# Whole-Repo Production Audit - 2026-06-15

## Scope

Reviewed the Mobio repo as a whole: main Flutter app, BioPay as a Mobio feature, wallet/tokens/subscriptions, admin panel routes, Mo Mobio SMS utility app, Supabase migrations/functions, release gates, Android signing/Play evidence, Google Maps/FCM evidence, and current physical-device smoke evidence.

## Fixes Completed In This Pass

- BioPay QR mobile save/share is implemented on Android and iOS through native channels and `share_plus`.
- Android QR save writes PNG files to `Pictures/Mobio` through `MediaStore` on Android Q+.
- iOS QR save uses the Photos add permission and `UIImageWriteToSavedPhotosAlbum`.
- Release version was bumped to `1.0.0+14` so the current QR-fixed artifact can be uploaded above the older version-code 13 Play draft.
- The production gate now rejects Play Console upload evidence that does not match the current `pubspec.yaml` version code.

## Current Evidence

- Full Flutter/analyze/golden suite passed in the Android production gate: `377` tests, including Revolut preview goldens.
- Linked Supabase gate passed: public schema lint reported no schema errors and backend security assertions returned `backend security assertions passed`.
- Mobio integrated feature readiness passed across shell/privacy, wallet/tokens/subscriptions, scheduling/public transport, admin/reports/notifications, and BioPay.
- Live BioPay AWS/Supabase health checks passed and refreshed `docs/release/evidence/biopay-live-readiness-2026-06-15.md`.
- Mo Mobio SMS local scope validation passed with `node scripts/validate-momobio-sms-bridge.mjs`.
- Mo Mobio SMS native app compiled with `android/gradlew -p apps/momobio_sms_bridge :app:compileDebugKotlin`.
- Live `momobio-sms-ingest` probe returned HTTP `400` from the deployed function for an invalid empty SMS, proving the function is present rather than missing with `404`.
- Android v14 release APK physical smoke passed on Pixel 4a: `docs/release/evidence/android-release-smoke-2026-06-15-v14.md`.
- Google Play internal draft upload for v14 succeeded: `docs/release/evidence/play-console-upload-2026-06-15-v14.md`.

## Findings

### Closed

- Previous blocker: mobile QR export was code-owned missing production scope. Fixed and validated on Flutter, Android Kotlin, and iOS simulator compile before this audit phase.
- Previous blocker: Revolut golden diffs. Full suite now passes with no golden diffs.
- Previous evidence gap: Play upload evidence was stale for the current QR-fixed repo. Fixed by bumping to versionCode 14 and uploading a new internal draft.

### Remaining Risks

- Shrunk Android AAB build did not complete locally after 411.7 seconds and was interrupted. The v14 Play upload used a signed no-shrink release AAB. This is not a functional blocker for internal draft validation, but shrink/R8 performance should be investigated before relying on minified production artifacts.
- Flutter warns that several plugins still apply Kotlin Gradle Plugin directly. Current builds pass, but future Flutter versions may fail until those plugins migrate to the built-in Kotlin model.
- iOS all-target production gate was not run in this pass. Android release gate is current; iOS production still requires its own App Store/TestFlight signing, Firebase/APNs, Crashlytics symbol, and device evidence if iOS is included in the release target.
- `fastlane android upload_aab` assumes `mapping.txt` exists. For no-shrink builds it fails before upload. The successful v14 upload used `fastlane supply` directly without mapping.

## Current Verdict

Android production gate is green for versionCode `14` with current Play internal draft upload and physical-device smoke. No code-owned Android blocker remains from QR, wallet, tokens, subscriptions, admin, Mo Mobio SMS scope, or linked Supabase gates based on the commands run in this pass.

iOS should remain separately gated until real iOS release signing and provider evidence are attached.
