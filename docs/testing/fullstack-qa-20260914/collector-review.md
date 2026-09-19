# Mo Mobio collector — QA checkpoint

14 September 2026. Local collector regression now covers 35 JVM cases and six Android component checks across three lifecycle runs. Operational collection, worker/service scheduling, real receipt matching and physical-device acceptance remain open. No SMS broadcast, enrollment or provider request was performed.

## Reproduced defects and repairs

**FQA-019 — JSON persistence.** The previous regular-expression decoder changed literal escapes, accepted incomplete records and truncated fractional timestamps. Five of eight reproduction cases failed. The JSONObject implementation preserves text and checks required field types and integer timestamps. All eight JVM cases and the actual Android JSON check pass.

**FQA-020 — shared queue writes.** Separate queue instances lost pending receipts during concurrent read/modify/write operations. Acknowledgement history and pending removal were separate writes. The queue now locks the shared preference instance, commits both fields together and reports failed commits. The corrected five-case queue suite and native preference concurrency/continuity checks pass. The initial fixture's checked-exception error remains separately labelled in historical evidence.

The implementation relies on the collector's single-process manifest and Android's shared preference instance per file. It does not add cross-process storage. [SharedPreferences](https://developer.android.com/reference/android/content/SharedPreferences), [Editor](https://developer.android.com/reference/android/content/SharedPreferences.Editor).

**FQA-021 — upload exceptions.** Connection creation/configuration and signing occurred outside the upload try block. A local acknowledgement callback could also escape after the server accepted a batch. Four controlled cases reproduced those failures. Setup now runs inside the guarded block, and an opened connection is retained before configuration so finally can disconnect it. A failed local acknowledgement returns a safe failure containing the already accepted server hashes and prevents sending another batch. Sixteen upload tests now pass.

**FQA-022 — multipart receipts.** Mapping each delivered SMS part to its own queue record split amounts and references and produced fragment hashes. Four decoder cases failed before repair. The decoder now joins the ordered parts of the completed broadcast without separators and keeps the first sender/time. Six decoder cases pass. A native test builds synthetic GSM UCS2 PDUs and passes them directly through Android's actual getMessagesFromIntent API; it produces one exact Unicode receipt and hash. No broadcast is sent. Android's inbound handler assembles and orders multipart PDUs before delivery. [AOSP InboundSmsHandler](https://android.googlesource.com/platform/frameworks/opt/telephony/%2B/master/src/java/com/android/internal/telephony/InboundSmsHandler.java).

**FQA-023 — broadcast lifetime and retry callers.** Source inspection found that the receiver uploaded all batches inside goAsync after queueing. Broadcast work remains time-limited even when asynchronous. The receiver now persists and schedules the existing worker/service, then finishes its callback; it performs no direct upload. Worker setup/persistence exceptions return retry, and the foreground service uses a generic status with class-only logging. These caller changes compile, but actual broadcast completion, WorkManager retry and service lifecycle branches have not been executed. No ANR was reproduced. [BroadcastReceiver](https://developer.android.com/reference/android/content/BroadcastReceiver).

## Current local evidence

Paths below are relative to build/qa/fullstack-qa-20260914/.

| Check | Result | Evidence |
| --- | --- | --- |
| Upload reproduction | 29 tests, four failures | collector-upload-reproduction.log |
| Upload repair | 29 passed | collector-upload-remediation.log |
| Multipart reproduction | 35 tests, four failures | collector-multipart-reproduction.log |
| Current codec/queue/upload/decoder batch | 35 passed: 8 + 5 + 16 + 6 | collector-receive-remediation.log |
| Actual Gradle unit task | Same 35 unique cases passed | collector-transport-gradle-unit/*.xml |
| All Kotlin sources and test APKs | Compiled | collector-transport-gradle.log |
| Exact APK package/permission checks | Both passed | collector-transport-apks/verification.json |
| Native component checks | Six passed on first run, stopped-process restart and same-APK replacement | collector-transport-android-first.log; collector-transport-android-restart.log; collector-transport-android-replace.log |
| Installed APK hash readback | Matches qualified copies | collector-transport-android-continuity.json |
| Owned emulator cleanup | Removed after retaining evidence | collector-transport-emulator-cleanup.json |

JVM upload tests use a controlled HttpURLConnection and signer; they never open a socket or create a key. They check exact signed UTF-8 bytes, headers, timeouts, 50/50/21 batching, accepted and foreign hashes, partial responses, malformed/error bodies, transport failures and callback failures. They do not prove real HTTP/signature integration or Android filesystem failure behavior.

## Android qualification and limits

The QA package is com.momobio.app.qa, with no requested permissions, app components, initializer or backend configuration. Its instrumentation APK also requests no permissions and targets only this package. The test library contributes three helper activities to the test APK. Actual manifests were checked before installation.

The six tests cover isolation, Android JSON, Android multipart parsing, Keystore signature/body binding, concurrent preferences and durable queue/acknowledgement continuity. The same identity and pending queue survived a stopped process and replacement with the same APK without data clearing. This is not a different-version upgrade or a power-loss test. The emulator cannot establish physical secure hardware. [Instrumented tests](https://developer.android.com/training/testing/instrumented-tests), [build variants](https://developer.android.com/build/build-variants).

The initial emulator launch requested a larger default partition than free disk allowed. An explicit 2048 MB partition launch succeeded. Only the newly created Mobio collector emulator and its synthetic data were removed afterward; APKs, inputs and logs remain.

Remaining work includes actual receiver and worker/service recovery, callback disk failure, simultaneous uploads, revoked enrollment, server replay and receipt/subscription state, queue/history growth, disk-full and power loss, permissions, notifications, Doze, boot/update, signing and independent acceptance. The QA package cannot execute those operational components. See the 14 rows in collector-state-trace.csv.

The collector tests precede only the later SQL/replay-script repair. Exact pre-SQL source reconstruction and current source bindings are separate. The operational Flutter Android guard still stops because all four public runtime values are absent. Overall readiness remains NO-GO and the goal remains active.
