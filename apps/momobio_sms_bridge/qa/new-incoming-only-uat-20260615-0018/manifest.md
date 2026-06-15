# Mo Mobio New-Incoming-Only UAT

- Device: Pixel 4a, Android 13, serial 13111JEC215558.
- Package: `com.momobio.app`.
- APK: `app/build/outputs/apk/release/mo-mobio-sms-bridge-internal-release.apk`.
- Install path: release APK signed with Android debug certificate and installed with `adb install -r`.
- Fresh-start proof: app data was cleared with `pm clear` before launch.
- Permission proof: `package.txt` shows `RECEIVE_SMS` and `POST_NOTIFICATIONS`; it does not contain `READ_SMS`.
- Source proof: app source contains no `READ_SMS`, `readAllSms`, or `content://sms/inbox`.
- UI proof: `uiautomator.xml` shows `Running`, `No new SMS`, and `Queued: 0`.
- Backfill proof: after fresh launch on a phone with an existing SMS inbox, the app did not show `Uploaded ...`, did not queue pre-install messages, and did not enter `Upload error`.
- Backend proof: linked Supabase query returned `post_install_receipts = 0` for `created_at >= 2026-06-14 22:18:00+00`, confirming no old inbox messages were uploaded after the fresh install.
- Incoming-SMS injection note: this physical Pixel 4a does not expose a safe `cmd phone` inbound SMS injection command; the production receiver remains protected by Android's system SMS broadcast instead of adding a test-only public receiver.
- Always-on proof: `services.txt` shows `BridgeForegroundService`, `isForeground=true`, `foregroundId=31045`, and `startRequested=true`.
- Recovery proof: `jobscheduler.txt` shows WorkManager jobs for `com.momobio.app` with connectivity constraints.
- Notification proof: `notification.txt` shows the active foreground notification text `No new SMS; queued 0`.
