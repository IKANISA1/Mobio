# Android Release Smoke Evidence

Date: 2026-06-12

Package: `rw.mobi.app`

Version code: `13`

Version name: `1.0.0`

Device:

- Serial: `13111JEC215558`
- Manufacturer: `Google`
- Model: `Pixel 4a`
- Android: `13`
- SDK: `33`

Command:

```bash
./scripts/release/smoke_android_release.sh
```

Result:

- Signed release APK installed successfully.
- Launcher intent succeeded.
- App stayed running after launch.
- Evidence log: `build/reports/android-smoke/smoke-20260612T001353Z.log`

Artifact:

| Artifact | SHA-256 |
| --- | --- |
| `build/app/outputs/flutter-apk/app-release.apk` | `359779b2cccf4de620687358a8b16b2ab7db5fdee8fb204156c3f2f66356f62b` |

Notes:

- The APK verifies with Android APK Signature Scheme v2.
- The release manifest intentionally removes advertising identifier permissions through manifest merge rules; the launch log may include a Google Play Services Advertising ID warning, but the artifact matches the current privacy scope.
