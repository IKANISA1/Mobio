# Final APK Install Evidence - 2026-06-13

## Build

- Command: `ANDROID_RELEASE_SHRINK=false ANDROID_TARGET_PLATFORMS=android-arm64 FLUTTER_BIN=/Volumes/PRO-G40/flutter_3_44/bin/flutter scripts/release/build_android_release.sh apk`
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- Size: `51,590,094` bytes
- SHA-256: `87954ecddbfa55dd429e18cb673106e998466ef5deec53221c5e58b72d9162bd`
- Build output: `Built build/app/outputs/flutter-apk/app-release.apk (51.6MB)`

Notes:

- The first universal release APK build failed in `:app:minifyReleaseWithR8` after a parallel debug/release build process interfered with generated intermediates.
- The installed APK is release-signed, ARM64-targeted for Pixel 4a, and built with release shrink/resource shrinking disabled through the repo-supported `mobi.release.shrink=false` flag.

## Device

- Device: Pixel 4a
- Serial: `13111JEC215558`
- Android: `13`
- ABI: `arm64-v8a`

## Install

- Command: `adb -s 13111JEC215558 install -r build/app/outputs/flutter-apk/app-release.apk`
- Result: `Success`
- Installed package: `rw.mobi.app`
- Installed APK path: `/data/app/~~A_PkSqyHp756BXN3j3CdfA==/rw.mobi.app-zwBK3DbvTSm-lH7_Wddd3A==/base.apk`
- Version code: `12`
- Version name: `1.0.0`
- Target SDK: `35`
- Signing version reported by Android package manager: `apkSigningVersion=2`

## Launch Smoke

- Launcher activity resolved: `rw.mobi.app/.MainActivity`
- Launch command: `adb -s 13111JEC215558 shell monkey -p rw.mobi.app -c android.intent.category.LAUNCHER 1`
- Launch result: `Events injected: 1`
- Running PID after launch: `28064`
- Recent logcat fatal crash scan: no `FATAL EXCEPTION` / `AndroidRuntime` lines found in the checked window.

## Still Not Covered

- Positive WhatsApp OTP send/verify UAT on device.
- BioPay QR/NFC/face positive payment-flow UAT.
- Full route/profile/trips manual UAT checklist.
