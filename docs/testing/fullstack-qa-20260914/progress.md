# Mobio full-system QA — execution checkpoint

15 September 2026, Africa/Kigali. **The plan is saved and its execution goal is active. The overall review remains incomplete and NO-GO.** This checkpoint records local repairs and bounded verification, not final per-surface or release acceptance.

## Current verified work

| Check | Result | Evidence under build/qa/fullstack-qa-20260914/ |
| --- | --- | --- |
| Production Dart chat recovery | Six actual-service checks passed; before repair, initial-join and reconnect catch-up failed | chat-service-live-red.json; chat-service-live-green.json |
| Permanent chat SDK regressions | Five scenarios pass: join, reconnect, coalescing, cancellation and failed-read recovery | test/features/chat/data/chat_realtime_recovery_test.dart; chat-recovery-final-flutter-test.log |
| Focused chat regression | 16 passed | chat-realtime-recovery-green.log |
| Full Flutter regression / Dart | **648 passed**, no analysis issues; pinned Flutter 3.44.3 / Dart 3.12.2 | chat-recovery-final-flutter-test.log; chat-recovery-final-dart-analyze.log |
| Structure, secrets and whitespace | Passed | chat-recovery-final-validation-runs.json |
| Prior driver/notification authority | 23 checks qualified after cleanup-contract retest; eight reproduced driver exposures denied | realtime-authority-final-regression.json; realtime-unsubscribe-regression.json |
| Prior verified logout | 13 checks qualified after explicit401 REST retest; revoked websocket loses access while peer remains active | realtime-chat-logout-regression.json; realtime-revoked-rest-regression.json |
| Prior database rehearsal | 103 migrations, ten SQL suites and eight rate-limit cases passed; 25 driver-discovery assertions | realtime-cli-rehearsal.json; driver-discovery-authority-sql-result-v2.json |
| Prior Deno regression | 109 passed, zero failed, one ignored; 16 entrypoints checked | realtime-deno-test.log; realtime-deno-check.log |

Backend/rehearsal/dependency inputs are unchanged in this batch, as recorded in `chat-recovery-unchanged-inputs.json`. Prior checks retain their original dates and source bindings. Earlier evidence also covers selected OTP/Admin/Storage authority, website browser and collector behavior.

## Findings and unresolved work

- **FQA-035, P1, open service dependency:** concurrent private uploads in tested Storage 1.68.10 can both report success while one replaces the other's bytes and ownership. The designated service version and an atomic service-level repair remain required.
- **FQA-037, P1, fixed locally:** protected driver discovery now requires a live verified identity; public/anonymous/unverified and revoked access is denied in SQL, HTTP and websocket regressions. Deployed acceptance is unverified.
- **FQA-038, P2, fixed locally:** chat missed persisted history during the first subscription and reconnect. The production Dart service now reconciles history on each successful join and preserves coalescing/cancellation. Actual service and permanent SDK regressions pass.

See [chat-recovery-review.md](chat-recovery-review.md), [realtime-review.md](realtime-review.md) and [storage-review.md](storage-review.md) for original failures, repairs and limits. The original Realtime cold-start notification miss remains unqualified. Chat catch-up does not establish general event replay, notification recovery, ordering, background lifecycle or hosted parity.

The latest cleanup removed the one new synthetic conversation and nine messages, then stopped its temporary gateway. Eleven earlier users/profiles, ten live sessions, three conversations and four messages remain. There are no live subscriptions or notification/HTTP/OTP/FCM queues. No message was sent to a person or provider. Five owned isolated services remain available for further QA.

## Per-surface limits

| Surface | Available evidence | Still required |
| --- | --- | --- |
| Android/iOS consumer app | Flutter behavior/golden fixtures, actual Dart chat service recovery and release contracts | Configured artifacts and passenger/driver journeys, native links/permissions, hardware, keyboard/reader, performance and recovery |
| Consumer web / Admin | Router/worker/widget flows, Admin state fixtures/captures and selected backend authority | Configured browser journeys, history/reload, reader/zoom, full Admin/role matrix and persisted workflows |
| Installed consumer/Admin PWA | Packaging, manifest and source checks | Actual installed modes, updates/caches, offline and notifications |
| Public website | Five-page local Chromium/WebKit and Lighthouse checks | Complete source comparison, combined/deployed binding, reader/zoom/field performance; deletion-page CLS follow-up |
| Kotlin collector | 35 JVM cases, six Android checks across three runs and 14 traces | Receiver/worker/service recovery, concurrent upload, server matching, device/power/permission and provider cases |
| Backend | 103-migration replay; selected actual Auth/REST/Storage/Realtime and SQL authority | Storage concurrency repair, designated service versions, notification/cold-start/lifecycle/order, remaining actor/argument paths, OTP sending/recovery, Edge parity, jobs and app integration |
| Delivery / acceptance | Local checks and isolated test artifacts | Configured builds, hosted CI, deployment, signing/store/provider/device and independent/owner acceptance |

The Android release script still stops before compilation because SUPABASE_URL, SUPABASE_ANON_KEY, PRIVACY_POLICY_URL and ACCOUNT_DELETION_URL are absent from the approved app-build configuration. iOS also requires its Firebase app value. The pending request for an approved QA configuration path or designated project remains unanswered. Generated credentials for isolated services do not by themselves qualify a complete app environment.

## Source and evidence status

HEAD remains d94c4edb11a7496753a28f906b2f397fe06d6b12. Current source has **1,965 files**, fingerprint `2b6dbce43afd00bee575fa5df163c98f098367ca278be6c4265a7f8c6d8884cb`, recorded in source-binding-after-chat-recovery.json. This batch changes only the chat service and its new permanent recovery test. All **2,057 previously sealed raw artifacts** and **33 previous report/register copies** are preserved. Recovered edits remain intact. No commit, push, production migration, deployment, external message or store upload occurred.

The register contains **654 rows: 612 bounded passes, seven failing Storage race executions and 35 unverified groups**, plus **38 findings** and **262 evidence entries**. Rows overlap across batches, repetitions and suites; these are not a complete state/role denominator or a whole-system quality percentage.

All 52 applicable product procedures, 100 design rules and ten MOBILE-DESIGN-100 criteria remain overall unverified. Eight skill-maintenance procedures are outside product QA. The goal continues with remaining service/app journeys, collector operations, configured runtimes and design/device acceptance.
