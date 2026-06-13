# MOBI Current APK Device UAT Manifest

Date: 2026-06-13
Device: Pixel 4a `13111JEC215558`, Android 13
Package: `rw.mobi.app`
APK SHA-256: `061da26a0bd9887c429b613586043b0762a905445ea305fc9eda9b68c2d975c3`
Evidence directory: `docs/release/evidence/device-uat-2026-06-13-current`

## Result

Current APK passenger BioPay/profile device UAT is **PASS with admin-console exception**.

The installed app was exercised on the physical Pixel 4a with screenshot, UI hierarchy, window, package, and step logcat captures for each screen. The app stayed foregrounded during captures and the harness rejects lockscreen/System UI coverage.

Admin BioPay console device UAT is **BLOCKED** until an allowlisted admin WhatsApp OTP session is provided or the owner explicitly approves sending/using an admin OTP. The device reached the admin auth gate successfully, but the app correctly requires an allowlisted WhatsApp number and verification code before showing admin operations.

## Captured Screens

| Area | Status | Evidence prefix | Key assertions |
| --- | --- | --- | --- |
| BioPay home | PASS | `biopay-home-final` | Shows BioPay, Face, NFC, Get QR, Scan, USSD secure handoff, and no unsupported Activity screen. |
| QR receive | PASS | `biopay-qr-final` | Shows QR receive flow with Number/Code tabs, receiver number, amount field, and Generate QR Code. |
| QR scanner | PASS | `biopay-scan-final` | Shows BioPay scan surface with camera scanner and Torch control. |
| NFC receive | PASS | `biopay-nfc-final` | Shows NFC receive flow with receiver number, amount field, Ready status, and Activate NFC. |
| Face scan standby | PASS | `biopay-face-scan-standby-final` | Shows AWS Rekognition face match flow, amount field, and Start Face Scan. |
| Face scan active | PASS | `biopay-face-scan-active-final` | Shows active face-match state with face guide and Match face control. |
| Profile top | PASS | `profile-final`, `profile-resumed-final` | Shows profile ID, Edit Profile, BioPay Face setup entry, theme, support/share/privacy entries, and passenger bottom nav. |
| Profile lower | PASS | `profile-lower-final` | Shows terms, delete account, and hidden admin gateway control; no visible Admin/Ops entry in passenger mode. |
| Edit profile | PASS | `edit-profile-final` | Shows WhatsApp/MoMo fields and notification consent controls. |
| Face enrollment standby | PASS | `biopay-face-enroll-final` | Shows AWS Rekognition enrollment, liveness-session copy, center/turn/hold steps, and Start Enrollment. |
| Face enrollment active | PASS | `biopay-face-enroll-active-final` | Shows active enrollment camera guide and AWS provider metadata. |
| Admin auth gate | PASS | `admin-auth-final` | Hidden profile gateway opens Admin access, allowlisted WhatsApp input, restricted access copy, and Send code CTA. |
| Admin BioPay console | BLOCKED | Not captured | Requires successful allowlisted admin OTP session. No bypass was attempted. |

Each prefix has these files where applicable:

- `<prefix>.png`
- `<prefix>.xml`
- `<prefix>-summary.txt`
- `<prefix>-window.txt`
- `<prefix>-logcat.txt`
- `<prefix>-package.txt`
- `<prefix>-device-model.txt`
- `<prefix>-android-version.txt`

## Admin Console Blocker

The app has no Android deep-link intent filter for direct route injection, and the current passenger session does not expose admin tabs. The profile screen includes a low-opacity lock gateway that opens `/admin-auth`; this was captured as `admin-auth-final`.

The next admin-console UAT step requires one of:

- an approved allowlisted admin WhatsApp number and OTP entered on the device, or
- an already-authenticated admin session on the device.

No service-role key, database mutation, allowlist mutation, or OTP send was used in this UAT pass.
