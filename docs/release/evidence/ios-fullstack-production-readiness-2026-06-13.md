# iOS Fullstack Production Readiness Evidence

Date: 2026-06-13
Scope: Flutter repo, Supabase backend gates, iOS simulator build path, release/PWA checks.
Result: NO-GO for iOS production release.

## Environment

- Flutter: 3.44.0 stable, Dart 3.12.0.
- Xcode: 26.2, build 17C52.
- CocoaPods: 1.16.2.
- iOS simulator target selected through XcodeBuildMCP: iPhone 17, iOS 26.3.
- Required public runtime build keys were present in `.env`: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `PRIVACY_POLICY_URL`, `ACCOUNT_DELETION_URL`.

## Passed Gates

- `scripts/qa/scan_secrets.sh`: passed.
- `scripts/ci/verify_backend.sh`: passed local secret scan, Deno checks, and Edge Function/shared tests.
- `supabase db push --linked --dry-run --yes`: passed with live linked project access; remote database is up to date.
- `REQUIRE_LINKED_SUPABASE=true ./scripts/ci/verify_backend.sh`: passed linked schema lint, storage/realtime audit, and backend security assertions.
- `/Volumes/PRO-G40/flutter_3_44/bin/flutter test`: passed all 257 tests, including widget and golden coverage.
- `/Volumes/PRO-G40/flutter_3_44/bin/flutter analyze`: passed with no Dart issues after the current working-tree scanner test-helper fix.
- `xcodebuild -resolvePackageDependencies -workspace ios/Runner.xcworkspace -scheme Runner`: passed after clearing stale Runner DerivedData.
- `pod install` in `ios/`: completed, installing 46 pods.

## Blocked Or Failed Gates

- Flutter default iOS simulator build with Swift Package Manager: failed. The generated `FlutterGeneratedPluginSwiftPackage` declares iOS 13.0 while Firebase Swift package products require iOS 15.0.
- CocoaPods fallback iOS simulator build: progressed through `pod install` and Xcode compilation but ended with signal-style exit 143 before producing a usable `Runner.app`; the partial app bundle was empty except for `Frameworks/`.
- iOS simulator app launch/UI validation through XcodeBuildMCP: blocked because no complete simulator app bundle was produced.
- `scripts/web/verify_pwa_bundles.sh`: failed because `build/pwa/site` is missing.

## Production Findings

1. P0: iOS is not production-buildable on the default Flutter/Xcode path.
   - Direct cause: generated SwiftPM package platform mismatch (`.iOS("13.0")`) against Firebase products requiring iOS 15.0.
   - The repo Podfile and Runner project target iOS 15.5, so the mismatch is in the generated Flutter SwiftPM package path.

2. P0: iOS runtime UAT is blocked.
   - No complete `Runner.app` was available to install, launch, inspect, screenshot, or profile.

3. P1: credential-use evidence needs explicit retention/use approval.
   - Linked live gates passed using transient environment variables only. Rotation is not tracked as a release blocker by owner direction; release evidence should instead confirm credentials are supplied through approved non-logged local or CI secret paths.

4. P1: iOS dependency mode is not stable.
   - Flutter warns that `permission_handler_apple` does not support iOS Swift Package Manager and says this will become an error in a future Flutter version.
   - CocoaPods fallback works for dependency installation but did not finish app packaging in this run.

5. P1: iOS Firebase release configuration needs explicit review.
   - No `ios/Runner/GoogleService-Info.plist` was found, while Firebase Analytics, Auth, Crashlytics, Messaging, and Remote Config are active dependencies.
   - The app has Dart-side Firebase options, but push/APNs and platform-native Firebase behavior still need device-level validation.

6. P1: release artifact reproducibility is incomplete.
   - PWA verifier failed due missing `build/pwa/site`.
   - There were concurrent Android release build processes during this audit, so release builds should be serialized.

## Notes

- Flutter SPM config was temporarily disabled to test CocoaPods fallback and restored to its prior unset state.
- Public build defines were supplied from `.env`; the final fallback attempt used a temporary `--dart-define-from-file` to avoid exposing values in process arguments.
- The working tree was dirty during the final audit due validation/build workflows and pre-existing release updates; review before committing.
