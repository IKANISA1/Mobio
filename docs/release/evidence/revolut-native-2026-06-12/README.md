# Revolut Native Visual Proof

Date: 2026-06-12

This folder contains native Android and iOS evidence for the Revolut-reference
MOBI visual pass. No AAB or release app bundle was rebuilt for this evidence.

## Devices

| Platform | Target | Build type | Screenshot size |
| --- | --- | --- | --- |
| Android | Pixel 4a, device id `13111JEC215558` | Flutter profile APK via `flutter run` | `1080x2340` |
| iOS | iPhone 17 Pro simulator, `EA9D612B-FD49-4092-92BC-543CE8106782` | Flutter simulator debug app | `1206x2622` |

## Screenshot Matrix

Each platform has 13 screenshots:

- `home_shell.png`
- `bookings_shell.png`
- `profile_shell.png`
- `home.png`
- `bookings.png`
- `schedule.png`
- `profile.png`
- `chat.png`
- `nearby.png`
- `admin.png`
- `home_scroll.png`
- `bookings_scroll.png`
- `profile_scroll.png`

The set covers shell transitions, pushed/detail style surfaces, scroll states,
status/navigation safe areas, and route-specific dense states.

## Capture Notes

- Android was captured from a link-controlled visual proof target so each
  screenshot name maps to the rendered screen without autoplay timing drift.
- iOS was captured from the simulator proof target, with focused compile-time
  recaptures for exact-name frames where autoplay timing was not sufficient.
- The Android accessibility floating button was temporarily hidden during the
  final capture and restored afterward. The final restore proof is in
  `android/accessibility_restore_link_controlled.log`.
- The proof target uses required public dart-defines from `.env` but runs in
  non-release local UI preview mode through `MOBI_VISUAL_PROOF=true`.

## Release Caveat

This clears the native screenshot blocker for design review evidence. It does
not by itself justify a 100/100 release claim: motion video, production route
data, and product-approved density decisions remain separate release-quality
gates.
