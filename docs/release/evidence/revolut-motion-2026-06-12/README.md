# Revolut Motion Proof Attempt

Date: 2026-06-12
Scope: native motion/transition proof for the Revolut design comparison report.

## Result

Motion video proof is not captured yet. This remains a blocker for any
`100/100` Revolut parity claim.

Physical Android release smoke is now captured separately in:

`docs/release/evidence/android-smoke-2026-06-12/smoke-20260612T142526Z.log`

## Attempts

### iOS Simulator

Attempted to build the visual proof app for iOS simulator with:

```bash
flutter build ios --simulator --debug \
  -t tool/revolut_visual_proof_app.dart \
  --dart-define=MOBI_VISUAL_PROOF=true \
  --dart-define=MOBI_ALLOW_LOCAL_PREVIEW=true \
  --dart-define=MOBI_VISUAL_PROOF_AUTOPLAY=true
```

Result: failed in Xcode target integrity checks.

Failure class:

- Firebase Swift Package products require iOS 15.0 or higher.
- Xcode reported one generated target as still supporting iOS 13.0.
- The checked source project and generated `Runner.app` metadata show iOS 15.5,
  so this appears to be generated SwiftPM/package integration state rather than
  an obvious source `Podfile` or `project.pbxproj` setting.

Follow-up:

- Refresh or repair the iOS SwiftPM/package build state, then rebuild the
  simulator proof target.

### Existing iOS Simulator App

Attempted to install and record an existing
`build/ios/iphonesimulator/Runner.app`.

Result: blocked.

- The app metadata exists and reports bundle id `rw.mobi.app` and minimum iOS
  `15.5`.
- `simctl` became unresponsive during install/launch/record attempts.
- No usable MP4 was produced.

Follow-up:

- Restart CoreSimulator or use a freshly booted simulator, then retry
  `simctl io recordVideo`.

### Android Physical Device

Connected device:

- Pixel 4a
- Android 13 / API 33
- Physical size: `1080x2340`
- Density: `440`

Attempted to build and install the debug visual proof target:

```bash
flutter build apk --debug \
  -t tool/revolut_visual_proof_app.dart \
  --dart-define=MOBI_VISUAL_PROOF=true \
  --dart-define=MOBI_ALLOW_LOCAL_PREVIEW=true \
  --dart-define=MOBI_VISUAL_PROOF_AUTOPLAY=true
```

Result:

- Debug APK build passed.
- Install failed because the connected phone already had `rw.mobi.app`
  versionCode `13`, while the first debug proof APK was versionCode `12`.

Retried with:

```bash
flutter build apk --debug --build-number=14 \
  -t tool/revolut_visual_proof_app.dart \
  --dart-define=MOBI_VISUAL_PROOF=true \
  --dart-define=MOBI_ALLOW_LOCAL_PREVIEW=true \
  --dart-define=MOBI_VISUAL_PROOF_AUTOPLAY=true
```

Result:

- Debug APK build passed.
- Install failed with `INSTALL_FAILED_UPDATE_INCOMPATIBLE` because the existing
  installed `rw.mobi.app` signature does not match the debug proof APK.

Follow-up:

- Use a clean Android emulator, or get explicit approval to uninstall/replace
  the existing `rw.mobi.app` on the connected physical device.

### Live Release App Recording

After physical release smoke passed, attempted to record the already-installed
release app with `adb shell screenrecord`.

Result:

- Release app install and launch passed in the smoke script.
- `screenrecord` attempts did not complete because the Pixel repeatedly dropped
  from ADB during recording.
- No usable MP4 was produced.

Follow-up:

- Retry with a stable USB connection, a clean emulator, or a simulator whose
  recording stack is responsive.

## Important Boundary

No Android app bundle was rebuilt during these attempts. The Android work above
used debug APK builds only.
