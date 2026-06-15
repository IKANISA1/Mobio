# Android Release Smoke Evidence

Date: 2026-06-15

Package: `rw.mobi.app`

Device: Pixel 4a `13111JEC215558`

Version code: `14`

Version name: `1.0.0`

Command:

```bash
ANDROID_SERIAL=13111JEC215558 ./scripts/release/smoke_android_release.sh
```

Result:

- Release APK installed successfully.
- App launched and stayed in foreground.
- No ANR, fatal exception, or FlutterError was detected by the smoke script.

Artifacts:

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `build/app/outputs/flutter-apk/app-release.apk` | `97,372,637 bytes` | `578dcfb44d60e3077718e2662c16e45d943088248505cb7fb5e1bbb8ca41a9b4` |

Smoke evidence:

- Log: `build/reports/android-smoke/smoke-20260615T064608Z.log`
- Screenshot: `build/reports/android-smoke/smoke-20260615T064608Z.png`
- UI tree: `build/reports/android-smoke/smoke-20260615T064608Z.xml`
- Window snapshot: `build/reports/android-smoke/smoke-20260615T064608Z-window.txt`

Installed package proof excerpt:

```text
versionCode=14 minSdk=24 targetSdk=35
versionName=1.0.0
apkSigningVersion=2
current_focus=Window{... rw.mobi.app/rw.mobi.app.MainActivity}
```
