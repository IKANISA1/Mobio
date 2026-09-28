# Increment07 integration — durable notification outbox

28 September 2026. Source candidate for a coordinated review release; no production changes have been made.

## Scope and prerequisites

Apply this increment to a complete, isolated review checkout after reconciling Increment06. The cumulative overlay is not a standalone app. Do not overwrite a newer checkout blindly. The guarded applier checks exact before/after content and rejects mismatches; replacements are atomic per file, not one cross-file filesystem transaction. Checksums detect drift, not authenticity.

The database body is `supabase/hardening/2026-09-28/11_notification_outbox.sql`. It requires the original notifications/catalog/consents/FCM tables, `mobio_private`, `verified_app_user_id()`, the session-bound `verified_admin_user_id()` from body08, and `_mobio_is_service_role()`. Rehearse the complete original migration chain plus all eleven forward bodies on clean and sanitized forward-upgrade databases. Do not use the synthetic test schema as a production bootstrap. Generate real timestamped migrations through the existing reviewed preparer/Supabase CLI; no applied migration history is included in this source package.

## Coordinated cutover — do not apply SQL alone

1. Freeze/reconcile the actual source revision and database history. Record a maintenance/version-gating decision and compatibility plan, including the earlier admin, wallet and chat transitions.
2. Keep notification dispatch disabled during rehearsal. Body11 defaults `push_policy.enabled` to false and replaces the existing AFTER INSERT trigger body; the trigger must already be attached as a row-level AFTER INSERT trigger or installation fails.
3. Body11 removes ordinary-client FCM table and accumulated column privileges. Older clients' direct token registration paths no longer work. Existing rows lack `session_id` and cannot receive new jobs until re-registration by an accepted client.
4. Deploy the `send-push` retirement endpoint and the new `push-outbox-worker` in the coordinated release. The old endpoint returns 410 and does no database or provider work. Do not leave a previously deployed unrestricted inline dispatcher active. Inventory and retire old trigger/caller aliases and scheduled invocations.
5. Release the corresponding Flutter changes. Existing login/logout callers retain `initialize`, `registerToken`, `unregisterToken` and navigator-key APIs. Device behavior must be verified before accepting the transition. No permission prompts are added to account-change auto-registration; only already-granted notification access is used.
6. Configure only server-side secrets. The worker needs the approved Supabase URL/server key, existing Firebase service-account configuration, and a dedicated high-entropy `MOBIO_PUSH_WORKER_SECRET`. Never put the server key, Firebase private key or worker secret in Flutter, Drive review exports, CI output or command-line arguments. Custom worker Bearer authentication runs before privileged dependencies/IO; its gateway JWT check is disabled for that reason only.
7. After SQL/client/provider acceptance, explicitly call `rpc_push_set_enabled` through authorized server operations with the approved change reference. No enablement call was executed in this delivery. A recurring server trigger may then be installed using the supplied templates; none was installed or scheduled here.

Maintain the inbox as the durable source of user-facing information. No backfill or automatic replay of historical notifications is performed. Establish an explicit policy for notifications created during maintenance: queued new events keep their bounded TTL, while events with no eligible registration remain recorded as `no_targets`, not silently replayed later.

## Server contract

- `rpc_push_register(token, platform, session_id)` accepts only a live verified app identity and its exact Auth session. Repeated registration for the same active owner/session is idempotent; token takeover or reactivation rotates the opaque binding. The response contains binding/token row UUIDs, owner and session—not the raw delivery token.
- `rpc_push_unregister(binding_id, session_id)` affects only the matching owning session. A delayed result for an older binding cannot revoke a newer owner/session's binding.
- Notification insertion and outbox admission share one database transaction. Sender-requested channels, catalog membership, promotional consent and bounded owner backlog are checked. Queue omission reasons are recorded without dropping the in-app notification. Unexpected enqueue errors are not swallowed.
- `rpc_push_claim(limit)` is service-only, bounds a batch to ten and aggregate leases to forty, uses `FOR UPDATE SKIP LOCKED`, and performs bounded expired-lease/TTL cleanup. A claim is not authorization to send.
- `rpc_push_authorize(job_id, lease_id)` rechecks the current switch, TTL, consent, session and token binding immediately before disclosure to FCM. One dispatch authorization per lease consumes the durable hourly budget. Paused/budget-denied authorization refunds the unconsumed attempt.
- `rpc_push_finish` records a provider outcome only for the current lease. Repeated matching acknowledgements are idempotent, including a committed retry whose response was lost. Recovery/expiry without an actual acknowledgement cannot be reported as provider acceptance. Only exact FCM `UNREGISTERED` results revoke the matching token binding.
- `rpc_push_health()` is an active-admin/service-only aggregate. `accepted` means FCM accepted the request, not that a handset received, displayed or read it. Counts are retained totals; omission reasons are reported for the last 24 hours. The admin card uses a separate RPC and remains under the existing admin session boundary.

All private queue tables use RLS with revoked direct client/service table access. Service RPCs are the explicit privileged interface. Original catalog/consent ownership and management controls must be verified against the complete deployed schema, not just fixture helpers.

## Retry, timing and privacy boundaries

The worker has a 20-second batch budget, at most three concurrent provider calls, bounded per-call timeouts, bounded request/response bytes and no followed redirects. Google OAuth assertions use WebCrypto RSA with the existing service-account method, fixed Google endpoints, one in-flight issuance and bounded token caching. A provider send is attempted once by the handler. Only database queue state permits a later send retry; retrying an acknowledgement never resends through the provider.

A timeout is an uncertain external outcome. FCM and PostgreSQL do not participate in one transaction. A process crash after FCM acceptance but before durable acknowledgement can produce a duplicate after lease recovery. Stable notification IDs, Android tags, APNs collapse IDs and bounded process-local client deduplication mitigate duplicates; they do not establish exactly-once external delivery. Do not advertise that guarantee. A nonconforming HTTP adapter may continue underneath a returned timeout; the production native Fetch transport is aborted, without assuming non-delivery.

Revocation is checked before authorization, but an already-authorized/in-flight push cannot be recalled. OS-visible payloads therefore use generic copy only. The client validates protocol, exact owner/session binding, notification UUID and the fixed `/notifications` route before foreground display or navigation. It fetches actual content through the current authorized inbox. Raw bodies, titles, arbitrary routes, financial details and caller-provided metadata never enter the new OS push payload.

The client stores an opaque binding, not a raw FCM token. That metadata is not anonymized or encrypted credential storage. M010 remains open. Registration/revocation are serialized within the client instance; account/session and service-lifecycle checks prevent stale completions from repopulating an active view. Native/SharedPreferences failures are reported without claiming server revocation; offline local sign-out can leave an unrevoked remote session until server expiry/revocation. Test A→B→A, token refresh, background/foreground, process death and permission revocation on physical devices. Generic OS payloads may still appear after sign-out; they contain no account-specific text.

The existing pinned client uses FCM registration tokens. No untested migration to different Firebase address identifiers, new SDK versions or browser push was introduced. Verify current Firebase/Flutter API compatibility on the full pinned app before release. Web push is not enabled by this work.

## Engineering defaults requiring workload/owner acceptance

| Control | Proposed default |
|---|---:|
| New push dispatch | Off |
| Notification TTL | 3,600 seconds |
| Maximum queue attempts | 6 |
| Active registrations per owner | 10 |
| Pending jobs per owner | 2,000 |
| Hourly authorized sends | 10,000 |
| Batch size / in-worker concurrency / global leased jobs | 10 / 3 / 40 |
| Lease duration | 90 seconds |
| Retry minimum / exponential cap | 60 / 3,600 seconds |
| Maximum accepted Retry-After | 86,400 seconds; expire if beyond remaining TTL |
| Registration freshness | 30 days |
| Client process-local deduplication | 256 notification IDs |

These are implementation defaults, not measured capacity, an SLA, an approved budget or a legal retention schedule. A cron/timer batch of ten per minute alone is not a ten-thousand-per-hour throughput claim. Select cadence, capacity and alerts from observed workloads. Queue/event/registration/budget/change records must be included in M069–M070, deletion/backup/retention and incident policies. Foreign keys support relevant owner/notification deletions, but no new cross-store deletion workflow or automatic evidence purge is claimed. Retained-total health aggregation needs full-volume performance testing.

## Verification commands

Run in the complete review checkout:

```sh
node --experimental-strip-types --test scripts/tests/push/*.test.mjs
python3 -m unittest discover -s scripts/tests -p test_push_operations.py -v
python3 -m unittest discover -s scripts/tests -p 'test_increment07*.py' -v
```

These pass locally in this delivery. The Node tests execute the delivered TypeScript worker/provider logic, native loopback HTTP, response limits, real ephemeral RSA signing/verification, error classification, auth rejection and acknowledgement retry. Database and Google responses are explicit fixtures; no live FCM send occurs.

```sh
python3 scripts/qa/test_push_postgres.py --check-tools
# Set a reviewed OFFICIAL postgres@sha256:<full real digest> in protected CI
# as MOBIO_PUSH_POSTGRES_IMAGE, then:
python3 scripts/qa/test_push_postgres.py
```

The SQL runner accepts no DSN/host database. It pulls the reviewed digest, starts a resource-limited, network-disabled container without host volumes, verifies PostgreSQL17 and an empty database, creates synthetic prerequisite tables/functions, runs body11/catalog assertions and tests ownership, duplicate admission, consent, revocation, lease recovery, retry acknowledgements, budget, TTL and concurrent claims. Cleanup removes that named container. It has **not run here** because Docker is absent. Even a later passing component run will not establish full-schema migration or actual Auth/PostgREST acceptance.

Also run, once tooling and a complete checkout are available:

```sh
deno check supabase/functions/push-outbox-worker/index.ts supabase/functions/send-push/index.ts
deno test supabase/functions/send-push/index_test.ts
flutter test test/increment07/push_binding_test.dart
# Run the existing complete Flutter/SDK/static/golden suites and release scripts.
```

Deno and Flutter tests are authored/configured but **not executed here**. Signed Android/iOS builds must use the existing release scripts and all required public dart-defines; do not use bare app build commands. Test actual Firebase/APNs, account switching, notification permission, generic background payloads, duplicate collapse, route gating, restart and clock/TTL behavior.

## Operations and rollback

`run_push_outbox_worker.py` performs one bounded request. It validates the exact hosted worker URL, dedicated secret and batch size; curl receives headers through stdin rather than argv. Its output is sanitized aggregate counters. Missing/non-200/inconsistent acknowledgement is non-pass. The service/timer templates require a reviewed `/opt/mobio` checkout, a `mobio` service account and protected `/etc/mobio/push-outbox.env`; no secrets or actual environment file are shipped. Do not enable these templates before the accepted cutover. Recycling/redeploying worker isolates is part of credential rotation because configured runtime/OAuth state is cached.

Pause new dispatch through the controlled service RPC, stop future timer invocations, and wait for in-flight/leased work to settle under the incident plan. Do not delete the queue or restore the old unrestricted dispatcher as an improvised rollback. Prefer a compatible forward repair; validate old-client registration and metadata behavior separately. The earlier wallet/admin/chat cutover restrictions remain.

## Unresolved release prerequisites

The connected Supabase account denied access to the source-referenced Mobio project; no hosted database, functions or settings were changed. Local PostgreSQL/Docker, Flutter and Deno execution remains unavailable. A complete canonical upstream source revision is still unestablished. Original repository secret-scanning tooling is absent from the partial checkout; a bounded export scan is not a full repository/history security audit. Source-folder anyone-with-link writer permission was rechecked and remains unchanged. M001/M002 still require appropriately authorized owner/security action.

This increment advances notification-specific implementation and tests. It does not close all 95 tasks, operating approvals, high-impact admin permissions, secure credential storage, full account deletion, model calibration, operator acceptance, localization/accessibility, hosted CI, signed-device tests or rollout approval.
