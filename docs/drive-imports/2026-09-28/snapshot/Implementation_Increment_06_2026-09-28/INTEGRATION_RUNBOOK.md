# Increment06 — chat delivery and history integration

28 September 2026. Source candidate for review integration, not an applied migration or a production release.

## Scope and dependencies

This wave advances M004, M007, M054, M055, M061, M062, M077, M078, M079 and M090. The primary feature is M061: stable chat request identity, uncertain-send recovery and bounded cursor history. The administrative and wallet changes from Increment05 and all earlier hardening remain in the cumulative overlay. This package does not change the approved face-to-USSD scope, add liveness or payer authentication, collect a PIN, debit mobile money, implement a new settlement engine or enable route computation.

Use the complete Mobio checkout, not this overlay as a standalone application. The input is a partial reconstruction of the supplied indexed source plus the exact Increment05 overlay and selected original dependencies. A complete current upstream main commit was not established. Read `SOURCES.json` and reconcile any newer upstream changes before using this candidate.

Required database prerequisites include the current chat tables, trips, user blocks, Plus/reply eligibility helper, live verified-identity helper and the prior private schema. SQL body 10 is a forward source body; no deployed schema or migration history was changed. Existing policies, RPC grants, triggers, realtime publication and notification dispatch must be evaluated under the complete migration chain, not inferred from the synthetic component fixture.

## Review and apply source only

On an isolated clean review branch, with Increment05 and the original dependencies already reconciled:

```sh
python3 apply_increment06.py --bundle /path/to/Mobio_Increment06_2026-09-28 --repo /path/to/mobio-review
python3 apply_increment06.py --bundle /path/to/Mobio_Increment06_2026-09-28 --repo /path/to/mobio-review --apply
```

The default checks only. The second command verifies every before/after hash and refuses unknown content, unsafe paths and symlinks. File replacement is atomic per file, not a multi-file filesystem transaction. Checksums detect drift; they do not authenticate a publicly writable delivery. Review the package and keep a trusted source/hash record. The separate Git patch is an alternative after `git apply --check`; do not apply both blindly.

These commands do not link a Supabase project, execute SQL, send messages or deploy a function. Prepare actual timestamped migration files using the existing `scripts/ci/prepare_hardening_migrations.py` workflow and the approved Supabase CLI after checking that command's `--help`. The preparer invokes the actual CLI rather than pretending a source body is an applied migration. Rehearse the original schema and bodies 01–10 on clean and representative sanitized forward-upgrade databases.

## Mandatory coordinated cutover

**Initial chat sends are OFF.** Body 10 initializes `mobio_private.chat_delivery_policy.sends_enabled` to false. It replaces the old two-argument `rpc_send_chat_message` with `PT410 / CHAT_CLIENT_UPDATE_REQUIRED`, revokes direct client message reads/writes and direct conversation mutation grants, and exposes checked RPC paths instead. Consequently, applying it without the corresponding client/version transition blocks old clients' sends and may break old direct-table read/read-mark paths. There is no claim of transparent backwards-compatible rollout.

The legacy bounded list RPC remains available, now returning the latest window in chronological display order. The new client uses the page RPC and server read watermark. Existing conversation-list APIs and approved WhatsApp handoff are preserved. Test all older supported clients and publish a coordinated maintenance/version transition before deploying. Inspect and reconcile any already-uncertain legacy send before choosing to resend it; it has no trustworthy new-protocol request ID.

Keep the earlier Increment05 cutover constraints: body 09 blocks legacy direct wallet mutations, and body 08 requires fresh OTP/session-bound admin leases. Cumulative source includes those controls but does not establish that any body has been applied.

After authorized full-schema, role, transaction and release-candidate acceptance, the operator may explicitly set the chat send flag through `rpc_set_chat_sends_enabled(boolean)` using a controlled service-role/server context. The function is not callable by ordinary clients. No enablement was performed here. The global flag applies to new sends; known-operation retries can return their already-recorded outcome while sending is paused. Status checks and resolving receipts remain available.

## Request and recovery contract

Flutter trims the composed text once, bounds it to 2,000 Unicode scalar values and 8,000 UTF-8 bytes, creates a secure random UUID, and saves owner/conversation/request ID plus exact-body SHA-256 before dispatch. SQL hashes the exact supplied UTF-8 bytes without a second normalization. Reusing an owner's UUID for another conversation or body fails rather than mutating the earlier operation.

A per-owner database advisory lock serializes new sends and explicit close/cancellation. One unresolved operation slot exists per owner/conversation. The message insert, existing message-trigger effects and recorded operation receipt are in one SQL transaction. Retrying a committed ID returns its recorded outcome without inserting another message. A cancellation arriving before a send records a tombstone; a later attempt with that same ID cannot send. A cancellation arriving after commit acknowledges the known sent result; it does not unsend or erase a message.

A lost send response is **unknown**, not evidence of failure. It retains the same pointer and requires an explicit status check, same-text retry or fenced cancellation. No automatic background replay is added. A valid sent receipt is evidence of commit: failure of the subsequent close response or local pointer cleanup must not turn that known result into an unsent/failed label. The UI retains and resolves its recovery record before allowing a distinct next send. Unknown or invalid server shapes and local storage conflicts block progress rather than fabricate success.

If a process restarts, the pending pointer remains owner-scoped. A known server-side unacknowledged operation can be recovered even when the local pointer is absent. **Message bodies are not persisted as an offline outbox**: for a request not yet observed by the server, the user must re-enter the identical text for retry or cancel the pending request. There is no guarantee against duplicates after arbitrary local data loss or a new manually generated request ID. Same-isolate client coordination is not a general distributed compare-and-swap guarantee across browser tabs or devices; the server's unique unresolved slot and immutable request binding are the authoritative controls.

Local pointer metadata uses shared preferences and is not encrypted credential storage. SHA-256 linkage is not anonymization. M010 remains open. No credentials or message bodies should be logged. Retained request hashes, UUID linkages and cancellation tombstones require the M069–M070 deletion/retention design. Do not purge deduplication evidence opportunistically and thereby permit replay.

Initial one-second minimum new-send interval and 10,000 retained-operation cap per owner are engineering proposals, not legal/provider requirements or measured production limits. Owner-approved capacity, retention, support and recovery procedures are required before enabling sends. At the cap, new operations are rejected rather than silently dropping records; reconciliation/retention remediation is operational work, not implemented automatic purging.

## Read authority, pagination and lifecycle

The checked page RPC validates current membership and the existing driver/Plus rules. Where the existing rule requires redaction, both body and metadata are redacted; a page carries explicit `access_redacted` state. Raw client access to chat messages is revoked so this cannot be bypassed with a different select. Direct participant reassignment through conversation mutation grants is also removed. Confirm all effective table/column/function permissions and legitimate original RPCs in the complete schema.

History is selected newest-first with a stable `(created_at,id)` keyset. Pages are capped at 100; the new UI starts with 50 and renders each window chronologically. Original server timestamp strings are preserved for cursor/read-watermark parameters. BigInt microsecond ordering is used for validation on native and web so display DateTime precision does not truncate a SQL cursor. An actual returned row is the read watermark; the client cannot mark unknown later messages read by sending its current clock.

The stream refreshes on subscription/rejoin, conversation update and a bounded foreground poll. It coalesces refresh work and removes channels, timers and account listeners independently of whether a paused consumer consumes a done event. Chat screen, delivery controls and history captures include account/session ownership checks; delayed bootstrap/profile/trip/send/report/block/handoff and read callbacks cannot knowingly update or mark the next account's view. Existing separate conversations use distinct channel names.

Backgrounding hides cached history and stops its stream; resume fetches under current authority. A head refresh resets previously loaded older pages to avoid preserving stale/redacted content. This deliberately trades uninterrupted long-history scrolling for revalidated content; physical-device/browser UX acceptance and any later refined invalidation strategy remain open. Do not claim measured performance or perfect behavior without running the authored client tests.

## Actual test execution required

### Isolated PostgreSQL 17 component lane

```sh
export MOBIO_CHAT_POSTGRES_IMAGE='postgres@sha256:<reviewed-actual-64-hex-digest>'
python3 scripts/qa/test_chat_postgres.py
```

The placeholder above is not a supplied digest. The authorized maintainer must select and verify an official PostgreSQL 17 image digest and configure the same repository variable for CI. Mutable tags and nonofficial repositories are rejected. The runner creates a uniquely named disposable container, publishes no ports, sets `--network none`, uses temporary storage, checks PostgreSQL 17, and removes its own container. It does not accept a production DSN or connect to a linked database. Docker/image availability failures return non-pass.

The runner uses synthetic Auth, Plus and trigger prerequisites in `scripts/tests/sql/chat_fixture_bootstrap.sql`. It contains actual SQL checks for default-off behavior, privileges, duplicate requests, content conflicts, ownership denial, direct-write denial, cancellation races, deletion tombstones, 125-row tied-timestamp paging, read boundaries and Plus/block behavior, including separate concurrent sessions. **These checks were not executed here: Docker is unavailable.** Even a successful component run would not replace full-schema and actual Auth/PostgREST acceptance.

### Flutter / Dart / web lane

With the repository's pinned Flutter/Dart toolchain and complete dependencies, run analysis and the following suites, then the complete Flutter suite:

```sh
flutter analyze
flutter test test/increment06/chat_delivery_test.dart test/increment06/chat_history_page_test.dart
flutter test test/features/chat/data/chat_service_test.dart test/features/chat/data/chat_realtime_recovery_test.dart
flutter test test/features/chat/presentation/chat_screen_test.dart test/release/chat_fullstack_contract_test.dart
flutter test
```

These new/updated suites were authored but **not run** here; Flutter and Dart are unavailable. Tests use explicitly synthetic session/transport fixtures, not real Supabase login. The direct `crypto: 3.0.7` dependency was already present at that exact version and hash transitively in the supplied lockfile; its lock classification was promoted to direct-main. No dependency resolution, package upgrade or clean Flutter build was performed here.

For every native build/run use the repository release scripts or all mandatory public dart-defines: SUPABASE_URL, SUPABASE_ANON_KEY, PRIVACY_POLICY_URL and ACCOUNT_DELETION_URL. Never put service-role keys in a client. No signed artifacts are supplied.

### Full-schema and device acceptance

Run the actual verified/anonymous/foreign-owner/revoked/blocked/Plus-expired matrix via Auth, PostgREST and direct attempted bypasses. Exercise concurrent two-participant sends, owner tabs/devices, trigger failures, dropped commits/replies, cancellation and deletion interleavings. Confirm the exact deployed grants and matching schema/RPC signatures; test notification-trigger compatibility and no duplicate notification insertion on same-ID retry. Validate route changes, account A→B→A, token refresh, background/resume, reconnect, lower-cost handsets and web timestamp precision.

The new maintenance/recovery strings are English source copy. M058–M060 still require promised-language translation, fluent review and accessibility/device acceptance. No current compliance approval, model calibration, operator configuration, live key remediation, real production recovery test or all-95-task completion is asserted.

## Evidence and rollback

`VALIDATION_RESULTS.json` distinguishes 21 new executable tooling tests, 18 new static source assertions and 455 rerun prior checks. None of the new checks executes the chat Dart state machine or the new SQL. Initial failed attempts and their final corrected reruns are retained with explanation; missing source dependencies were restored unchanged and index-verified before the final Node run.

Rollback is a reviewed database/client compatibility plan, not blind restoration of permissive grants or removal of request tombstones. Disable new sends if acceptance fails, preserve receipt/recovery evidence, and use a reviewed forward repair. Do not re-enable the legacy unjournaled send merely to hide an integration failure.

Source-folder metadata was rechecked on 28 September 2026 and still permits anyone possessing its link to edit. No permissions were changed; M001–M002 remain immediate access/signing remediation. All produced source is uploaded separately from the original source tree, with no signing store, live secret or Git object database in the package.
