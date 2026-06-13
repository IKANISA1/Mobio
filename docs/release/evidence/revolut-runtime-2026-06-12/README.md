# Revolut Runtime Evidence

> Date: 2026-06-12
> Target: `tool/revolut_visual_proof_app.dart`
> Runtime: Flutter web profile build served from `build/revolut_visual_proof`
> Browser: local Google Chrome via Playwright

## Capture Matrix

Screens captured:

- `home_shell`
- `bookings_shell`
- `profile_shell`
- `home`
- `bookings`
- `schedule`
- `profile`
- `chat`
- `nearby`
- `admin`

Viewport sizes:

- `390x844` at device scale factor `3`, rendered as `1170x2532`
- `430x932` at device scale factor `3`, rendered as `1290x2796`

Total screenshots: `20`.

## Browser Result

Final capture logs:

- `browser-messages-390.json`: `[]`
- `browser-messages-430.json`: `[]`
- `browser-messages-chat-final.json`: `[]`

Known filtered capture noise:

- `favicon.ico` / `favicon.png` requests were fulfilled with `204` during
  capture.
- Chrome WebGL `ReadPixels` performance warnings were treated as screenshot
  readback noise and excluded from final logs.

## Source Fixes From Runtime QA

- Chat local preview no longer depends on debug-only mock trips, so profile web
  runtime does not crash.
- Vehicle chips/grids now use Lucide icons instead of tiny raster vehicle PNGs,
  matching the Revolut icon-first treatment and avoiding missing asset requests.

## Remaining Evidence Gap

This is browser-runtime proof, not native Android/iOS device proof. Native
device or emulator screenshots are still required before claiming final mobile
release parity.
