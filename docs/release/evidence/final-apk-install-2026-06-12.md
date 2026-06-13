# Final APK Install Evidence

Date: 2026-06-12
Device: Pixel 4a (`13111JEC215558`)
Package: `rw.mobi.app`

## Build

Command:

```bash
JAVA_HOME=/usr/local/Cellar/openjdk@17/17.0.18/libexec/openjdk.jdk/Contents/Home \
ANDROID_RELEASE_SHRINK=false \
ANDROID_BUILD_NUMBER=15 \
./scripts/release/build_android_release.sh apk
```

Result:

- Built signed release APK.
- Path: `build/app/outputs/flutter-apk/app-release.apk`
- Size: `74.9MB`
- SHA-256:
  `c6f41b5da80181b5a3b5ff6e02e93d3bc5a85cb1c5232cb2524b6c44b70a3570`
- Java 17 was required. Direct Gradle invocation under Java `25.0.1` failed
  with Kotlin `JavaVersion.parse` error; the release wrapper now auto-selects
  Java 17 or fails early when Java is unsupported.

No app bundle was rebuilt.

## Install

Command:

```bash
adb -s 13111JEC215558 install -r build/app/outputs/flutter-apk/app-release.apk
adb -s 13111JEC215558 shell monkey -p rw.mobi.app -c android.intent.category.LAUNCHER 1
```

Result:

- Install: `Success`.
- Installed version: `versionCode=15`, `versionName=1.0.0`.
- Package metadata after install:
  - `lastUpdateTime=2026-06-12 18:20:04`
  - `firstInstallTime=2026-06-12 16:37:56`
- Launch intent was delivered to `rw.mobi.app/.MainActivity`.
- Android window state showed `rw.mobi.app/.MainActivity` as the focused app,
  but the device remained on the PIN lock screen (`mDreamingLockscreen=true`).

## Follow-up APK - Connectivity Banner Fix

Command:

```bash
JAVA_HOME=/usr/local/Cellar/openjdk@17/17.0.18/libexec/openjdk.jdk/Contents/Home \
ANDROID_RELEASE_SHRINK=false \
ANDROID_BUILD_NUMBER=16 \
./scripts/release/build_android_release.sh apk
```

Result:

- Built signed release APK.
- Path: `build/app/outputs/flutter-apk/app-release.apk`
- Size: `74.9MB`
- SHA-256:
  `7d0d5eebb48c3379cf1de4f1479b5dabd8e77e88785fe9015b737366eefea064`
- No app bundle was rebuilt.

Install:

```bash
adb -s 13111JEC215558 install -r build/app/outputs/flutter-apk/app-release.apk
```

Result:

- Install: `Success`.
- Installed version: `versionCode=16`, `versionName=1.0.0`.
- Package metadata after install:
  - `lastUpdateTime=2026-06-12 18:40:43`
  - `firstInstallTime=2026-06-12 16:37:56`
