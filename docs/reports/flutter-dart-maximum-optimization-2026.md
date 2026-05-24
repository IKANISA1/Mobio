# Flutter/Dart Maximum Optimization 2026

Date: 2026-05-24

## Scope

This pass moves the Flutter workspace toward Flutter 3.44.x and Dart 3.12.x
without reintroducing out-of-scope ride-hailing, BioPay, ledger, or in-app
payment behavior. It is intentionally additive and does not claim production
go-live.

## Changes Made

- Configured the Dart MCP server command for Codex:
  `codex mcp add dart -- dart mcp-server --force-roots-fallback`.
- Installed official Dart and Flutter agent skills into `.agents/skills` and
  recorded the lock file.
- Added VS Code recommendations/settings for the Flutter 3.44 SDK, Dart MCP,
  format-on-save, analyzer fixes, and import organization.
- Added `docs/development/flutter_dart_2026_workflow.md` with exact local,
  build_runner, DevTools, Android release, and PWA commands.
- Raised the app SDK constraint to Dart `^3.12.0`.
- Upgraded `flutter_typeahead` from `5.2.0` to `6.0.0`, removing the transitive
  `flutter_keyboard_visibility_web` dependency that imported `dart:html` and
  blocked Flutter 3.44 WASM checks.
- Added a local `lucide_icons` compatibility override because the published
  package subclasses Flutter's now-final `IconData`.
- Fixed the notification consent section by replacing a decorated
  `SwitchListTile` wrapper with a `Material` surface, resolving the Flutter
  3.44 ListTile ink/background assertion.
- Hardened Flutter scripts so they prefer `/Volumes/PRO-G40/flutter_3_44`,
  honor `FLUTTER_BIN`, use temporary `--dart-define-from-file` JSON instead of
  exposing build defines in command lines, and validate release outputs.
- Added `--no-wasm-dry-run` for default JS PWA builds while preserving an
  explicit `WEB_WASM=true` path for real WASM/SKWASM validation.

## Evidence

- Target SDK: Flutter `3.44.0`, Dart `3.12.0`, DevTools `2.57.0`.
- Commits created:
  - `c0561ab chore: add Flutter Dart agent workflow`
  - `4b1b92c chore: harden Flutter release scripts`
  - `a995473 fix: support Flutter 3.44 package compatibility`
- Staged-index dependency check:
  `flutter pub get --enforce-lockfile` passed in a temporary checkout of the
  committed compatibility changes.
- `bash -n scripts/release/build_android_release.sh scripts/web/prepare_pwa_bundles.sh scripts/ci/verify_flutter.sh`: passed.
- `/Volumes/PRO-G40/flutter_3_44/bin/dart analyze`: passed with no issues.
- Targeted tests:
  `/Volumes/PRO-G40/flutter_3_44/bin/flutter test --reporter expanded test/features/profile/widgets/profile_notification_consent_section_test.dart test/core/router/app_router_test.dart`: passed.
- Full tests:
  `/Volumes/PRO-G40/flutter_3_44/bin/flutter test --reporter expanded`: `154` tests passed.
- `flutter pub outdated`: after this pass, `flutter_typeahead` no longer appears as constrained behind `6.0.0`; remaining constraint-level updates are still unvalidated.

## Current Blockers

- `flutter doctor -v` still warns that shell `flutter`/`dart` point to an older SDK on `PATH`. Scripts now prefer the 3.44 SDK, but developer shells should put `/Volumes/PRO-G40/flutter_3_44/bin` first.
- iOS/macOS archive validation is blocked locally because CocoaPods is not installed. Flutter 3.44 also warns `permission_handler_apple` does not support Swift Package Manager, so iOS plugins still need CocoaPods fallback.
- Android release appbundle validation did not produce a fresh artifact in this run. The attempted `bundleRelease` process stalled behind local Gradle state and was stopped; existing APK/AAB files under `build/` are stale from 2026-05-23 and are not evidence for this pass.
- Web/PWA release validation did not produce a fresh artifact in this run. The first Flutter 3.44 web build exposed and fixed the Lucide/typeahead blockers; later JS minification remained CPU-bound on this workstation and was stopped. Existing `build/web` content is not treated as fresh evidence.
- Full WASM/SKWASM validation remains pending until the default JS PWA build can complete or is run on a less contended build host.
- App-size and startup/profile traces remain missing for this pass because fresh release artifacts were not produced.
- Package major updates still need separate validation: `device_info_plus`,
  `geolocator`, `permission_handler`, and any Firebase platform-interface
  changes.

## Inventory Notes

- No `WebView`, `GoogleMap`, `AndroidView`, `UiKitView`, `FragmentShader`, or
  explicit Impeller code paths were found in the active Flutter source during
  this pass.
- Largest app assets observed:
  vehicle images in `assets/vehicles/*.png` are JPEG-encoded 1024x1024 files
  between roughly 447 KB and 546 KB each; local font assets are roughly
  67 KB to 96 KB each.
- Largest active Dart files remain admin/chat/bookings surfaces, led by
  `admin_broadcasts_screen.dart`, `chat_screen.dart`, and `admin_ui.dart`.

## Next Commands

```bash
export FLUTTER_BIN=/Volumes/PRO-G40/flutter_3_44/bin/flutter
export PATH=/Volumes/PRO-G40/flutter_3_44/bin:$PATH

$FLUTTER_BIN doctor -v
/Volumes/PRO-G40/flutter_3_44/bin/dart analyze
$FLUTTER_BIN test --reporter expanded

./scripts/release/build_android_release.sh appbundle
./scripts/release/build_android_release.sh apk
./scripts/web/prepare_pwa_bundles.sh build/pwa-js
WEB_WASM=true ./scripts/web/prepare_pwa_bundles.sh build/pwa-wasm
```

After fresh artifacts exist, capture app size with `du -h` and Flutter
DevTools/app-size analysis, then run profile-mode startup, navigation,
scrolling, memory, and network traces before any production readiness claim.
