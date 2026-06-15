# Mo Mobio SMS Utility Audit - 2026-06-15

## Scope

Mo Mobio SMS is a private in-house Android utility installed on one office phone. Its job is to collect new MoMo driver subscription payment SMS and upload raw SMS to the linked Mobio Supabase project. It is not a Play Store/public app and it does not need a public SMS bridge secret.

## Current Source Boundary

| Area | Files | Current assessment |
| --- | --- | --- |
| Manifest permissions | `apps/momobio_sms_bridge/app/src/main/AndroidManifest.xml` | Requests `RECEIVE_SMS`, not `READ_SMS`. Requests foreground service, boot recovery, network, notification, and battery optimization permissions appropriate to an internal always-on utility. |
| Incoming receiver | `apps/momobio_sms_bridge/app/src/main/java/com/momobio/app/SmsReceiver.kt` | Receives system SMS broadcast and queues raw SMS. |
| Foreground service | `BridgeForegroundService.kt` | Runs always-on foreground service and uploads queued SMS. No inbox backfill call remains. |
| Recovery worker | `BridgeSyncWorker.kt` | Retries queued uploads without inbox backfill. |
| UI/manual sync | `MainActivity.kt` | Shows queue/status and starts service. SMS access requires `RECEIVE_SMS` only. |
| SMS model | `MomoSms.kt` | Hashes sender/body/timestamp. Removed `readAllSms` and `content://sms/inbox` use. |
| Backend upload | `UploadClient.kt` and `momobio-sms-ingest` function | Direct anon-key upload to Supabase function. Parsing and subscription matching are backend-owned. |

## Evidence

- Validator passed: `node scripts/validate-momobio-sms-bridge.mjs`.
- Android compile passed after setting SDK env explicitly:
  `JAVA_HOME=/usr/local/Cellar/openjdk@17/17.0.18/libexec/openjdk.jdk/Contents/Home ANDROID_HOME=/Volumes/PRO-G40/AppData/android/sdk ANDROID_SDK_ROOT=/Volumes/PRO-G40/AppData/android/sdk android/gradlew -p apps/momobio_sms_bridge --no-daemon --no-watch-fs -Dorg.gradle.workers.max=1 :app:compileDebugKotlin`.
- New physical evidence folder: `apps/momobio_sms_bridge/qa/new-incoming-only-uat-20260615-0018/`.
- New evidence states:
  - package requests `RECEIVE_SMS` and `POST_NOTIFICATIONS`;
  - package does not request `READ_SMS`;
  - foreground service is running with notification id `31045`;
  - WorkManager recovery jobs exist with connectivity constraints;
  - after fresh launch on a phone with existing inbox messages, no pre-install inbox messages were uploaded.

## Superseded Evidence

The older folders `apps/momobio_sms_bridge/qa/always-on-uat-20260615-0007/` and `apps/momobio_sms_bridge/qa/device-uat-focused-complete-20260614-234653/` still contain historical `READ_SMS` evidence. They are retained as history only and do not describe the current utility app scope after the new-incoming-only change.

## Findings

| ID | Severity | Finding | Status | Next action |
| --- | --- | --- | --- | --- |
| SMS-001 | Fixed | Utility previously had inbox backfill and `READ_SMS` permission. Current source removes both and listens only to new incoming SMS. | Fixed in current diff | Commit after full audit batch or with this phase's validated changes. |
| SMS-002 | Low | Incoming SMS injection could not be proven through a safe device command on the physical Pixel 4a. | Needs owner/device evidence if required | Use a real MoMo SMS event on the office phone or carrier/test-SIM proof; do not add a public test receiver. |
| SMS-003 | Fixed | Public-app assumptions in earlier findings were wrong for this utility. | Fixed in current scope | Keep documentation explicit that this is an in-house office-phone utility. |

## Verdict

Mo Mobio SMS is currently aligned with the user's stated internal utility scope. No code-owned blocker remains in the inspected diff after validator, Flutter-side contract tests, and sidecar Kotlin compile. Live real-SMS receipt proof remains an owner/device operational evidence item if required before office deployment.

