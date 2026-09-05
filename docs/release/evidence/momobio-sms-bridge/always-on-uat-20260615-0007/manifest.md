# Mo Mobio Always-On UAT

- Device: Pixel 4a, Android 13, serial 13111JEC215558.
- APK: app/build/outputs/apk/release/mo-mobio-sms-bridge-internal-release.apk.
- Install: `adb install -r` succeeded without clearing app data.
- Runtime: process remained running after launch and after Home/background.
- Foreground service: `com.momobio.app/.BridgeForegroundService`.
- Service proof: `services.txt` and `services-after-home.txt` show `isForeground=true`, `foregroundId=31045`, and `startRequested=true`.
- Native access proof: `package.txt` shows READ_SMS, RECEIVE_SMS, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, FOREGROUND_SERVICE, and FOREGROUND_SERVICE_SPECIAL_USE granted/declared.
- Battery proof: `deviceidle-whitelist.txt` contains `com.momobio.app`.
- WorkManager proof: `jobscheduler.txt` contains `com.momobio.app/androidx.work.impl.background.systemjob.SystemJobService` with CONNECTIVITY constraints.
- Notification proof: `notification.txt` contains channel `mo_mobio_sms_bridge_active` and text `No new SMS; queued 0`.
- UI proof: `uiautomator.xml` and `screenshot.png` captured the app showing Running / Queued state.
