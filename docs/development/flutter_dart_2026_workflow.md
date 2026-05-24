# Flutter and Dart 2026 Workflow

Use Flutter 3.44.x with Dart 3.12.x for this repo.

## Local Toolchain

```bash
export FLUTTER_BIN=/Volumes/PRO-G40/flutter_3_44/bin/flutter
export DART_BIN=/Volumes/PRO-G40/flutter_3_44/bin/dart

$FLUTTER_BIN --version
$DART_BIN --version
```

The default shell `flutter` may point at an older SDK on this workstation. Repo
scripts prefer the 3.44 SDK when it exists and also honor `FLUTTER_BIN`.

## Agent Tooling

```bash
codex mcp add dart -- dart mcp-server --force-roots-fallback
npx skills add flutter/skills --skill '*' --agent universal
npx skills add dart-lang/skills --skill '*' --agent universal
```

Installed skills are under `.agents/skills`. Review a skill before using it to
change dependencies, run external network calls, or make platform changes.

## Daily Checks

```bash
$FLUTTER_BIN pub get
$FLUTTER_BIN gen-l10n
/Volumes/PRO-G40/flutter_3_44/bin/dart analyze
$FLUTTER_BIN test --reporter expanded
```

Run generated-code refresh only when the matching source models changed:

```bash
$FLUTTER_BIN pub run build_runner build --delete-conflicting-outputs
```

## Release Builds

Android release builds must go through the guarded script so public runtime
values are compiled into the app:

```bash
./scripts/release/build_android_release.sh appbundle
./scripts/release/build_android_release.sh apk
```

The Android release script parses `.env` without exporting it and disables the
Gradle daemon by default for release builds. Flutter still forwards
`--dart-define` values to its compiler/Gradle subprocesses, so only public
client values belong in Dart defines.

PWA bundles also parse `.env` and can test the Flutter 3.44 WASM/SKWASM path
without making it the default production renderer:

```bash
./scripts/web/prepare_pwa_bundles.sh build/pwa-js
WEB_WASM=true ./scripts/web/prepare_pwa_bundles.sh build/pwa-wasm
```

## Profiling

Use DevTools after starting the app in profile mode:

```bash
DEVICE=chrome ./scripts/perf/profile_startup_trace.sh
DEVICE=00008101-001A01A61A22001E TRACE_OUTPUT=build/perf/ios-startup.binpb \
  ./scripts/perf/profile_startup_trace.sh
```

For a local web bundle that does not depend on Flutter's Chrome launcher,
capture DevTools Protocol metrics and a trace from an existing build:

```bash
./scripts/perf/capture_web_startup_metrics.py --web-dir build/pwa-js/client
```

Capture CPU, memory, network, frame rendering, and app-size diffs before
claiming startup, scrolling, animation, or bundle-size improvements.
