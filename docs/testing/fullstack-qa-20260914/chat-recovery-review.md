# Chat history recovery review

15 September 2026. **FQA-038, P2, is repaired and verified locally. Full-system QA remains incomplete and NO-GO.** The execution goal stays active. Raw evidence is under `build/qa/fullstack-qa-20260914/`.

## Reproduced behavior

The production `ChatService.streamMessages` fetched history immediately, then subscribed to conversation changes. It refreshed only on UPDATE events. A message committed between that first read and subscription was absent from the stream. The same problem occurred when a message arrived during an outage: the SDK rejoined successfully, but the stream stayed stale until another message triggered an UPDATE. A failed initial history read likewise had no retry on joining.

The messages remained persisted and readable through the history RPC. This is a client refresh defect, not established server message loss. The controlled live reproduction used two existing synthetic verified identities—a driver and an allowlisted Admin acting as chat participants. It does not substitute for a complete passenger/driver UI journey.

## Repair

`lib/features/chat/data/chat_service.dart` now refreshes history whenever the pinned SDK reports `RealtimeSubscribeStatus.subscribed`, including rejoin after a disconnect. Existing concurrent-read coalescing remains, and cancellation prevents new refreshes, queued work and late results from reaching a disposed stream. No polling loop, dependency version, database contract or UI flow was added.

Five permanent tests in `test/features/chat/data/chat_realtime_recovery_test.dart` exercise the actual service and Dart SDK with mocked HTTP and a controlled loopback websocket protocol: initial join gap, reconnect gap, duplicate-event coalescing, cancellation during an in-flight read, and recovery after a failed initial read. Their synthetic protocol responses establish client behavior, not Auth or database authorization.

## Actual service proof

`chat_service_live_recovery_test.dart` executes the production Dart service and the pinned Supabase **2.10.2**, Realtime client **2.7.0** and GoTrue **2.18.0** packages against the owned GoTrue **2.195.0**, PostgREST **16.1** and Realtime **2.124.4** services. It restores actual Auth-issued sessions, creates no fake accepted identity, and performs real chat RPCs and websocket delivery. Only the local websocket transport is held or interrupted. Gateway controls neither fabricate subscription acknowledgements nor supply message results.

| Evidence | Actual result |
| --- | --- |
| `chat-realtime-recovery-red-v3.log` | Two existing safety behaviors pass; three history-recovery assertions fail before the repair |
| `chat-service-live-red.json` | Four of six cases pass; initial-join and reconnect catch-up fail while ordinary live delivery works |
| `chat-service-live-green.json` | The same six live cases all pass after repair |
| `chat-realtime-recovery-green.log` | Focused chat batch: 16 passed, including send/draft and existing contract checks |
| `chat-recovery-final-focused-results.json` | Five final-source tests individually passed with no skips; avoids inferring case-level results from compact full-suite output |
| `chat-recovery-final-dart-analyze.log` | No issues found |
| `chat-recovery-final-flutter-test.log` | Full suite: 648 passed, including all five permanent recovery tests |
| `chat-recovery-final-validation-runs.json` | Structure, secrets and whitespace passed; Android release script refused missing approved configuration before compilation |

The live harness uses positive delivery controls before and after disconnect. It also compares the final stream to the authoritative history RPC order and checks for duplicate IDs. The old and repaired runs use the same live test source, with separate source hashes and outputs in their `*-run.json` records. This is bounded recovery evidence; it does not establish general ordering, durable event replay or loss guarantees.

The first two mock-harness red runs also contained teardown writes to a closing test socket. Those outputs remain preserved; the clean third reproduction is the defect evidence. The first analysis run found an internal SDK getter and three style issues in the new permanent test. The final test observes acknowledgements through the public `onMessage` callback and passes analysis. `chat-recovery-harness-qualification.json` records these distinctions. No original failure log was overwritten.

## Cleanup and remaining scope

`chat-recovery-cleanup.json` confirms removal of the one new conversation and its nine messages: one automatic seed plus four synthetic sends in each live run. No Auth account was added or deleted. The previous eleven users/profiles, ten live sessions, three conversations and four messages remain. Subscriptions, notifications, HTTP requests, OTPs, FCM tokens and Storage object rows are empty; cron remains off. The temporary gateway completed four actual websocket connections and was stopped with none active or waiting. No message was sent to a person or external provider.

The original first-notification miss on a lazily started Realtime service remains unqualified. This chat history repair does not close notification catch-up, general cold-start readiness, token/account transitions, rapid lifecycle changes or background/resume behavior. Screen-level error presentation, read-state persistence, blocked users, driver-Plus rules, native keyboard/reader behavior, installed PWA modes, multi-device behavior and hosted service parity remain required. The separate Storage concurrency finding FQA-035 remains open.

## Evidence binding

The final source comprises **1,965 files**, fingerprint `2b6dbce43afd00bee575fa5df163c98f098367ca278be6c4265a7f8c6d8884cb`. Only the chat service and the new permanent recovery test differ from the preceding checkpoint. The 179 backend/rehearsal/dependency input files recorded in `chat-recovery-unchanged-inputs.json` are unchanged; the previous 109 Deno passes and 103-migration/ten-suite replay retain their original evidence and dates. They were not rerun or relabelled as new backend executions.

All 2,057 previously sealed raw artifacts and 33 previous report/register copies are preserved. `chat-recovery-validation.json` records the final validation and manifest counts. The register contains **654 rows: 612 bounded passes, seven retained failing Storage race executions and 35 unverified groups**, with **38 findings** and **262 evidence entries**. Overlapping suites and repetitions are not a whole-system completion percentage. All product/design acceptance criteria remain subject to the full plan.
