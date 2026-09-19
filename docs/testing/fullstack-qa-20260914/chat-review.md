# Chat send review — local checkpoint

14 September 2026. Two draft-loss paths were reproduced and repaired locally. The full pinned Flutter suite now passes **621 tests**, including ten new behavioral regressions. This is not native, deployed chat, database, realtime, or independent acceptance.

## Reproduction and repair

**FQA-012 — a rejected send looked successful.** A second nonempty message submitted within one second returned a successful Future without calling the server. The screen clears its draft after success. The static cooldown also affected other ChatService instances. The corrected HTTP fixture reproduced both observations in `chat-send-reproduction-2.log`. The first fixture attempt omitted the response request object and failed inside the fixture; `chat-send-reproduction.log` is retained but is not product-defect proof.

ChatService now rejects the cooldown with a typed, user-readable validation error, scopes its timing to the service instance, and prevents an older failed request from resetting a newer request's cooldown. The one-second interval is preserved. A supplied clock makes timing regressions deterministic; production still uses DateTime.now.

**FQA-013 — an acknowledgement erased a newer draft.** In the actual TripChatScreen widget, type a first message, submit it, type a second message while the first acknowledgement is pending, then acknowledge the first. The old screen cleared the newer text. `chat-screen-reproduction.log` preserves the failing assertion. The same screen fixture showed duplicate callbacks before a rebuild could submit twice to the service; this is a screen-level observation, not proof of duplicate server delivery because the real service also enforces its cooldown.

The screen now guards an in-flight send immediately and clears only the unchanged submitted text in the same conversation while still mounted. Failure retains the draft and exposes retry. Its existing local-preview decision is provided through Riverpod with the same SupabaseConfig default, allowing the real asynchronous screen path to be tested without fake runtime build configuration.

## Validation

- Five tests use the actual Supabase SDK with an HTTP MockClient: truthful cooldown rejection and later send, retry after server rejection, separate instances, late failure ordering, and empty/trimmed input.
- Five tests use the actual TripChatScreen with controlled service Futures: new-draft preservation, acknowledgement timing, rejection and retry, duplicate callbacks, and leaving the screen while a send is pending.
- The focused chat and existing moderation-contract batch passed 17 tests: `chat-remediation-1.log`.
- The full serial suite passed 621 tests in 4m41s: `flutter-chat-batch-serial.log`. The earlier concurrent rerun exhausted disk while copying a compiler artifact and was interrupted; `flutter-chat-batch.log` is not a full-suite pass.
- Dart analysis, structure validation and secret scanning passed. `http` 1.6.0 was already in the locked dependency graph; it is now declared as a direct development dependency for MockClient. Offline resolution changed only that lockfile classification, with no version or integrity-hash changes.
- Android, iOS and PWA release scripts were retried after the dependency declaration. All stopped before compilation because approved runtime values remain absent. No messages, OTPs or push notifications were sent.

Raw paths above are under `build/qa/fullstack-qa-20260914/`. The final source binding is `source-binding-after-chat.json`, fingerprint `d62de4749b76358b482326329f36560367088fbb44dd78565d5772265c5eb635` over 1,935 source files. Source changes in this batch are limited to three chat files, two test files and the two pubspec files.

## Remaining chat work

Execute designated two-user and denied-user database/RPC tests, block/report trigger and grant review, driver-Plus privacy cases, realtime subscription/reconnection and error presentation, read-state persistence, session expiry/revocation, native keyboard/reader behavior and multi-device delivery. A timed-out request may have been accepted by a real server; the local retry tests do not establish server idempotency or delivery guarantees. Existing chat visual goldens passed, but full source fidelity and independent/owner review remain unverified.
