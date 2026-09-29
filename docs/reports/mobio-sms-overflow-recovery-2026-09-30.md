# Institutional SMS overflow recovery — 30 September 2026

This addresses the source-level SR-01 saturation omission in the
[readiness register](mobio-production-readiness-remaining-tasks-2026-09-29.md).
The Mo Mobio collector is a separate, currently unaccepted Android utility;
this change does not enable collection or automatic financial allocation.

## Changes and reason

| Files | Reason |
| --- | --- |
| `apps/momobio_sms_bridge/app/src/main/assets/receipt_queue_v2.sql` | Add an additive SQLite overflow tier for 10,000 raw receipts / 16 MiB and a no-body refusal ledger. The v1 receipts and metadata tables remain intact. |
| `DurableSmsQueue.kt`, `ReceiptQueueSql.kt` | At active capacity, commit an eligible raw receipt to overflow; deduplicate across both tiers; promote oldest overflow rows atomically when room becomes available, at most 50 per transaction; include overflow in pending/health and retry decisions. Record a hash, time and reason if neither raw tier can take a receipt. No unresolved row is evicted. SQLiteOpenHelper upgrades v1 to v2 additively. |
| `SmsReceiver.kt`, `MainActivity.kt`, `BridgeForegroundService.kt` | Surface deferred receipts, 80%-of-either-tier capacity warnings, and unreconciled refusal counts to the operator. On a queue exception, attempt to start the visible recovery service. No raw SMS body is logged. |
| `apps/momobio_sms_bridge/app/build.gradle.kts` | Resolve the Java URI class explicitly so the offline QA Gradle build can configure. This was an existing build-script error found during validation. |
| `apps/momobio_sms_bridge/app/src/androidTest/java/com/momobio/app/DurableQueueDeviceTest.kt` | Add a package-isolated Android scenario that saturates the active queue, checks overflow persistence across reopen, then checks promotion after acknowledgment. It does not use a real SMS or operational collector. |
| `scripts/tests/test_collector_queue_contracts.py`, `scripts/qa/validate_momobio_sms_bridge.mjs` | Exercise the actual v1/v2 SQLite assets, old-row preservation, active and overflow limits, persisted overflow and refusal metadata, and transactional promotion; update the source validator from its obsolete direct-ingest markers to the current signed durable-intake contract. The validator is source-level only. |
| `apps/momobio_sms_bridge/README.md`, this report | Explain capacity, upgrade and reconciliation behavior without promising unattended or lossless collection. |

## Verification and limits

- Portable SQLite suite: **25 passed** with real SQLite constraints and transactions, including rollback of an interrupted promotion. It is not Android SQLiteOpenHelper, broadcast delivery or device proof.
- Offline Gradle QA Kotlin and Android-test compilation passed after correcting the URI reference. The QA JVM unit run passed **38 tests** across codec, legacy preference queue, transport and receipt decoding. The new overflow device test compiled but has not executed.
- The current-state source validator passed after its obsolete direct-ingest assumptions were replaced with scoped durable-intake checks. Repository structure, secret-pattern and whitespace checks passed. Dart analysis exited 0 with 92 information-level findings. The Android release script stopped before compilation because the four required public build values are absent locally.
- Full `flutter test --no-pub --reporter compact` on pinned Flutter 3.44.3 finished with exit 1: **969 passed, 152 reference-golden failures**. The result matches the prior full run; no Flutter app source changed in this SMS mitigation. [Golden failure inventory](mobio-golden-failures-2026-09-30.tsv) records the exact failing baselines. M076 remains open; no baseline was approved.
- No Android device is connected at this workstation. The saturation instrumented test has not run; signed update, process death, disk-full, interrupted broadcast and operator reconciliation remain unaccepted.
- A refusal ledger preserves only a hash and timestamps when both raw tiers fill. The original SMS must be retrieved from an authorized independent source; the ledger cannot reconstruct the body. Disk exhaustion can prevent even ledger persistence. Receiver logging and best-effort service start are not a guaranteed alarm.
- M028/M030/M034, SR-01 and G04 remain **open** until a reviewed capacity/retention design, saturated-device test, fleet alert exercise, original-message recovery and source-to-ledger reconciliation pass on the intended signed collector and backend configuration. Automatic allocation stays OFF.
