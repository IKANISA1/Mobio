# Mobio Increment07 — implementation delivery report

28 September 2026 · Notification outbox, bounded worker, session-bound client handling and administrative health

**Status: source implemented with the local evidence below; not deployed. The new SQL and Flutter/Deno entrypoints have not been executed or accepted. This delivery does not close all 95 tasks.**

## Delivery and backlog

This increment contains **32 new or modified repository files** and a **188-file cumulative overlay** retaining previous implementation. It includes forward SQL body11, native Flutter notification/health integration, the TypeScript worker and provider adapter, a read-only catalog probe, an isolated SQL/concurrency test runner, client test sources, operational templates, a guarded source applier, Git patch and an updated all-95 task register.

Destination: https://drive.google.com/drive/folders/1UilSPU-LXRZ9iyRGbA1pYIpk0_r9pcOW

Original Mobio folder: https://drive.google.com/drive/folders/120JIOTyeNX6nHaHPDqS3UgbaTWyJAE57

Eleven tasks advanced: **M004, M008, M055, M062, M077, M078, M079, M084, M090, M091 and M092**. The register classifies **11 advanced in Increment07, 36 with prior source work and acceptance open, and 48 not advanced in this increment**. All 95 original IDs, priorities, role owners, dependencies and acceptance criteria remain preserved. These categories are not functionality-completion percentages. No production acceptance is evidenced by the delivered packages; this does not assert that external organizational approvals are absent.

Original Drive source files and earlier increments are unchanged. The cumulative source is an integration overlay, not a complete standalone application or signed installable release.

## Implemented changes

### Durable notification admission and service-only queue

The old notification trigger attempted immediate HTTP dispatch. Body11 replaces that trigger function with transactionally admitted events/jobs. It retains a reason when a notification is not queued: unrequested channel, unknown type, invalid channel structure, missing promotional consent, no eligible device or capacity refusal. The in-app notification remains the source of user-facing content. Unexpected enqueue errors are no longer swallowed.

The candidate uses private RLS-enabled queue tables, explicit RPC grants and removal of accumulated client table/column privileges. Targets are frozen to a notification, owner, token row and opaque binding. Claim/authorize/finish operations provide expiring leases, bounded retry, TTL, a durable hourly authorization budget, stale-worker fencing and idempotent acknowledgements. A retry acknowledgement whose first response was lost does not require another provider send.

The actual consent schema was checked: consent is keyed by profile/type/channel rather than an assumed `id` column. Promotional checks use the existing granted consent and organization, and literal `promo` still requires consent even if its catalog flag drifts. Actual full-schema transactional and permission behavior remains unexecuted.

### Bounded TypeScript worker and Google adapter

A dedicated Bearer secret is checked before privileged dependency initialization or network access. The request accepts only a bounded batch limit; callers cannot supply arbitrary payloads, recipient IDs or URLs. The REST adapter has fixed RPC names, response limits, deadlines and no redirected credential-bearing calls.

Google OAuth uses real WebCrypto RSA assertions, fixed endpoints, bounded responses, a single in-flight issuance and expiring cache. FCM results are classified separately: accepted, retryable, exact unregistered token or permanent failure. A generic HTTP 404/400 is not sufficient to revoke a device token. The worker calls the provider once per authorized lease, and only retries the acknowledgement in the same invocation. Subsequent sends depend on durable queue state.

The new core runs in Node with native Web APIs and strict TypeScript checking; it does not rely on fabricated external SDK declarations. Live Google and database behavior is represented by explicit controlled fixtures, not live provider calls.

### Session-bound Flutter registration and notification handling

The client now uses server registration/revocation RPCs tied to the exact verified Auth session. Repeated same-session registration preserves the active binding; a reassigned/reactivated token gets a new binding. An older failed delivery or logout cannot intentionally target that newer binding. The client captures account/session and service lifecycle around asynchronous registration, serializes registration/revocation and invalidates delayed work on disposal.

Foreground display and tap navigation require the current binding, expected protocol, notification UUID and fixed inbox route. Actual content is resolved through the authenticated inbox. Generic OS-visible copy contains no private message body, sender, financial information or arbitrary metadata. Stable IDs/tags and a bounded process-local dedupe cache mitigate duplicate presentation.

Native/storage cleanup failures do not skip attempting owner-bound remote revocation. Offline sign-out does not prove remote revocation succeeded; generic OS alerts already in flight may still arrive. The opaque stored binding is not encrypted credential storage, so **M010 remains open**. Flutter compilation, plugin compatibility, permission behavior, account switching and native lifecycle acceptance have not run.

### Administrative health and operational control

A dedicated active-admin/service-only health RPC and Flutter card distinguish queued/leased work, provider-accepted requests, expired/suppressed/dead work, admission omissions, backlog age and worker polling. **Provider acceptance does not establish device delivery, display or reading.** Retained totals and last-24-hour omission counts are explicitly identified.

The send switch defaults off and service-side changes require a recorded change reference. No live switch changed. A single-batch operational trigger passes its secret through curl stdin, not argv, and outputs only validated aggregate counters. Service/timer templates are supplied but were not installed, enabled or scheduled. This advances notification controls, not all feature switches or all observability requirements.

## Verification actually completed

**601 local checks/scenarios/source assertions passed: 107 new and 494 rerun regressions.** The new checks comprise **97 executable/fixture checks and 10 static assertions**. This is not an end-to-end test count.

| Lane | Passing count | Boundary |
|---|---:|---|
| New notification worker/provider/HTTP/crypto | 70 | Actual TS logic, native loopback HTTP and real ephemeral RSA; explicit Google/database fixtures |
| New operational trigger/image-input guards | 16 | Python, request configuration and input validation; no live provider or SQL |
| New guarded source applier | 11 | Real filesystem, drift, symlink/path and repeated-application checks |
| New static integration contracts | 10 | Source assertions, not Dart/SQL runtime |
| Prior Python regressions | 216 | Mixed executable fixtures and source assertions |
| Prior Node pure modules | 66 | Existing module logic |
| Prior Node handler fixtures | 138 | Existing handlers with explicit Auth/database/SDK substitutes |
| Prior inference HTTP | 16 | Actual HTTP with fake model |
| Prior NFC policy | 20 | Compiled JVM policy, not Android hardware |
| Prior collector policy/OS leases | 38 | Compiled Kotlin and cross-process leases, not WorkManager/device |
| **Total** | **601** | **Local evidence only** |

Strict new-core TypeScript, Python/shell/TOML/YAML syntax, the Actions pin checker and all eleven forward-body hashes/planning passed. The exact delivered applier checked and applied **32 files** against a separate affected-source baseline; all expected hashes matched and a second apply changed **zero**. Independent `git apply --check` and application produced the same 32 expected hashes. Source replacement is atomic per file, not all files together.

Initial dependency-load, body10-last assertion and harness-timeout failures were resolved and rerun. Six dependencies were restored unchanged from mounted Drive inputs after verifying their exact current-index Git blob hashes. Initial and final evidence are distinguished; only final passing lane counts are aggregated.

A bounded scan of the 188-file export found no matches for the checked live-key/private-key/file-extension patterns. This is not a full repository or history secret audit. The original secret-scanning script is absent from the partial reconstruction, so that full gate is not claimed as passed.

## Unexecuted work and access limits

The PostgreSQL17 component runner and catalog/concurrency cases are authored, but Docker/psql are unavailable locally; the availability check returned exit 2. The runner uses only a reviewed official digest-pinned image, an empty network-disabled container and explicit synthetic prerequisite schema. It accepts no external DSN or live database. A future component pass would still not establish complete migration history or real Auth/PostgREST behavior.

The connected Supabase account successfully listed its accessible projects, but the source-referenced Mobio project read returned **permission denied**. No alternative credentials were sought and no hosted database/functions/settings were modified.

Also not executed: Flutter/Dart compilation and client tests; native Deno entrypoints; actual Firebase/APNs delivery; signed Android/iOS builds; physical-device tests; hosted required CI; real inference model/operator acceptance; production deployment. Authored and unavailable tests are not counted as executed passes.

The source remains a partial indexed recovery plus exact Increment06 overlay and selected original dependencies. The prior GitHub read returned not found and the large Git pack exceeded the connector limit. A complete current upstream main revision has not been established; no limit/access bypass is claimed.

## Critical integration and residual boundaries

**Coordinate database, client and functions.** Body11 defaults dispatch off, removes direct client token writes and requires session-bound re-registration. The legacy `send-push` endpoint returns 410. Applying the database body alone would break older registration paths. Inventory old callers and retire deployed bypasses in a controlled release. The earlier admin/wallet/chat transition requirements remain.

Queue TTL/attempt/capacity/budget values are engineering defaults awaiting owner/workload acceptance. No measured throughput, cost improvement or delivery SLA is claimed. All newly retained binding/job/event/budget/change data must be incorporated in deletion, retention, restore and incident workflows under M069–M070. No automatic historical notification replay or retention purge was added.

FCM and PostgreSQL do not share one transaction. A crash after provider acceptance but before durable acknowledgement may cause a duplicate on lease recovery; stable tags and client dedupe are mitigations, not exactly-once delivery. An already-authorized in-flight push cannot be recalled after a later consent/session/switch change. Generic payloads and current-session client checks reduce information exposure without claiming perfect revocation timing.

Source-folder metadata was rechecked and still grants **anyone with the link writer access**. Permissions and signing credentials were not changed. M001/M002 remain immediate owner/security actions. The delivery contains no private signing stores, live credential files or Git object database.

Next gates remain complete clean/forward database rehearsal, real role/transaction testing, Flutter/native/provider acceptance and the coordinated cutover. Secure credential storage, full deletion/retention, remaining feature controls, localization/accessibility, monitoring/recovery and all other open backlog criteria are not silently marked complete. The approved face-to-USSD scope is unchanged; this work adds no liveness, PIN collection, automatic debit or new settlement engine.
