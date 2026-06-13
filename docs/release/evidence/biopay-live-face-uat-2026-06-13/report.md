# BioPay Live Face Enrollment And Scan UAT

Date: 2026-06-13
Device: Pixel 4a `13111JEC215558`
Package: `rw.mobi.app`
Status: Blocked at authenticated passenger session

## Result

Live AWS/Supabase provider proof is ready, and the physical device has the
native capability and installed permissions needed for BioPay face enrollment and
face scan. The actual real-user enrollment -> AWS face ID -> scan match -> USSD
request flow was not completed because the installed app is currently logged out
and stopped at the WhatsApp login screen.

## Completed

- Live BioPay face provider health returned:
  - `provider`: `aws_rekognition`
  - `production_ready`: `true`
  - `provider_collection_id`: `mobio-biopay-prod`
- Focused BioPay code readiness gate passed static, Deno, and Flutter checks.
- Serialized device proof confirmed:
  - Pixel 4a is authorized over ADB.
  - Device exposes camera and front camera features.
  - Device exposes NFC features.
  - Installed package requests `android.permission.CAMERA`.
  - Installed package requests `android.permission.NFC`.
  - Installed package does not request SMS read/receive in the relevant package
    permission surface.
  - Current focused app window is `rw.mobi.app/rw.mobi.app.MainActivity`.
- Current screen capture shows the app at WhatsApp login.

## Not Completed

- Passenger WhatsApp login.
- Real face enrollment capture.
- AWS `IndexFaces` proof for a real enrolled user.
- Database proof that `biopay_profiles.provider_subject_id` and
  `provider_collection_id` were populated for the enrolled user.
- Real face scan/match.
- Face-channel USSD request creation.
- Dialer handoff and `user_marked_paid` status progression.
- Admin BioPay external confirmation UAT.

## Blocker

The current app state requires a real WhatsApp OTP before BioPay can be reached.
The login Edge Function hashes a randomly generated OTP before storing it; the
stored placeholder code value is not a valid bypass. No service-role key is
available locally to create or inspect login state, and no OTP bypass was used.

## Evidence Files

- `manual/live-face-health.json`
- `manual/serialized-device-proof.md`
- `manual/02-screen-pull.png`
- `precheck-live-readiness.md`
- `precheck-live-readiness-after-adb-restart.md`

## Required Next Input

To finish this UAT on the same device, provide one of:

- an approved passenger WhatsApp number and the received 6-digit OTP, or
- an already-authenticated passenger session on the Pixel 4a, or
- an approved temporary test-auth mechanism for this UAT build.

After login, the remaining test sequence is:

1. Open Profile -> BioPay Face setup.
2. Start enrollment and capture a live face.
3. Verify AWS enrollment response and `biopay_profiles` provider metadata.
4. Open BioPay -> Face Scan.
5. Capture the same face and verify AWS match.
6. Verify the created `face` channel USSD request.
7. Tap `Dial USSD`, then `I finished USSD`.
8. Complete admin confirmation after approved admin OTP login.
