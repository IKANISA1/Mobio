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
  honor `FLUTTER_BIN`, parse `.env` without exporting it into Gradle, use
  temporary `--dart-define-from-file` JSON, validate release outputs, and
  disable the Gradle daemon by default for Android release builds.
- Added `--no-wasm-dry-run` for default JS PWA builds while preserving an
  explicit `WEB_WASM=true` path for real WASM/SKWASM validation.
- Added `scripts/perf/profile_startup_trace.sh` to run repeatable profile-mode
  startup traces with a temporary dart-define file.
- Ran Flutter 3.44's iOS migration path; it added SwiftPM plugin integration
  and UIScene lifecycle wiring, but device deployment remains blocked by local
  signing.

## Evidence

- Target SDK: Flutter `3.44.0`, Dart `3.12.0`, DevTools `2.57.0`.
- Commits created:
  - `c0561ab chore: add Flutter Dart agent workflow`
  - `4b1b92c chore: harden Flutter release scripts`
  - `a995473 fix: support Flutter 3.44 package compatibility`
  - `17034a3 docs: record Flutter Dart validation`
  - `chore: capture Flutter 3.44 release evidence` (this commit)
- Staged-index dependency check:
  `flutter pub get --enforce-lockfile` passed in a temporary checkout of the
  committed compatibility changes.
- `bash -n scripts/release/build_android_release.sh scripts/web/prepare_pwa_bundles.sh scripts/ci/verify_flutter.sh`: passed.
- `/Volumes/PRO-G40/flutter_3_44/bin/dart analyze`: passed with no issues.
- Targeted tests:
  `/Volumes/PRO-G40/flutter_3_44/bin/flutter test --reporter expanded test/features/profile/widgets/profile_notification_consent_section_test.dart test/core/router/app_router_test.dart`: passed.
- Full tests:
  `/Volumes/PRO-G40/flutter_3_44/bin/flutter test --reporter expanded`: `154` tests passed.
- Dart MCP `/Volumes/PRO-G40/MOBI/mobi_app` analysis: passed with no errors.
- Dart MCP `flutter pub outdated`: `flutter_typeahead` no longer appears as
  constrained behind `6.0.0`; the current dirty worktree still has direct and
  transitive packages newer than the locked versions, but no safe full
  resolution was available from `pub outdated`.
- Android APK release:
  `FLUTTER_BIN=/Volumes/PRO-G40/flutter_3_44/bin/flutter ./scripts/release/build_android_release.sh apk`
  passed in `867.5s`.
- Fresh APK artifact:
  `build/app/outputs/flutter-apk/app-release.apk`, `69,871,205` bytes,
  timestamp `2026-05-24 10:05`.
- Android AAB release:
  `GRADLE_OPTS='-Dorg.gradle.daemon=false' FLUTTER_BIN=/Volumes/PRO-G40/flutter_3_44/bin/flutter ./scripts/release/build_android_release.sh appbundle`
  passed in `571.6s`.
- Fresh AAB artifact:
  `build/app/outputs/bundle/release/app-release.aab`, `68,900,221` bytes,
  timestamp `2026-05-24 10:28`.
- JS PWA:
  `FLUTTER_BIN=/Volumes/PRO-G40/flutter_3_44/bin/flutter ./scripts/web/prepare_pwa_bundles.sh build/pwa-js`
  passed in `109.1s`; `build/pwa-js` is `95M`, with `47M` each for `client`
  and `admin`.
- WASM/SKWASM PWA:
  `WEB_WASM=true FLUTTER_BIN=/Volumes/PRO-G40/flutter_3_44/bin/flutter ./scripts/web/prepare_pwa_bundles.sh build/pwa-wasm`
  passed in `271.2s`; `build/pwa-wasm` is `102M`, with `51M` each for
  `client` and `admin`.
- Web size snapshot after WASM build:
  `build/web/main.dart.js` is `4,430,867` bytes, `main.dart.wasm` is
  `3,993,720` bytes, and `build/web` is `51M`.
- Chrome profile startup attempt:
  `flutter run -d chrome --profile --trace-startup --trace-to-file=build/perf/chrome-startup-20260524.binpb`
  built `build/web` in `72.1s` but failed to connect to Chrome's debug port, so
  no valid trace file was produced.
- macOS profile startup attempt failed because this repo has no macOS desktop
  project configured.
- iOS profile startup attempt reached Flutter's SwiftPM/UIScene migration and
  then failed because no valid development signing certificate/provisioning
  profile was available for the connected wireless iPhone.

## Current Blockers

- `flutter doctor -v` still warns that shell `flutter`/`dart` point to an older SDK on `PATH`. Scripts now prefer the 3.44 SDK, but developer shells should put `/Volumes/PRO-G40/flutter_3_44/bin` first.
- iOS device profiling/archive validation is blocked locally by missing Apple
  development signing. Flutter 3.44 also warns `permission_handler_apple` does
  not support Swift Package Manager, so iOS plugins still need a CocoaPods
  fallback path until that plugin migrates.
- macOS profiling is unavailable because the repo has no macOS desktop target.
- Chrome profile tracing is blocked on this workstation by a Chrome debug-port
  connection failure after the profile web build completes.
- Android release builds still warn that the app and several plugins apply the
  Kotlin Gradle Plugin. Flutter 3.44 allows this with migrator flags, but future
  Flutter versions will require Built-in Kotlin-compatible plugin/project
  updates.
- Flutter `--dart-define` values are still visible to local compiler/Gradle
  subprocesses because Flutter forwards them as build parameters. These values
  must remain public client configuration only; no service-role keys or private
  secrets belong in Dart defines.
- Startup/profile traces remain missing because no simulator/device profile run
  completed successfully in this pass.
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
DEVICE=chrome ./scripts/perf/profile_startup_trace.sh
```

Before any production readiness claim, run a profile-mode device session and
capture startup, navigation, scrolling, memory, and network traces in DevTools.
