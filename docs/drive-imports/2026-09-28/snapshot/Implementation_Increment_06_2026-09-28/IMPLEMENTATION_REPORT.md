# Mobio Increment06 — implementation delivery report

28 September 2026 · Full-stack chat delivery, recovery, pagination and account isolation

**Status: source candidate with the local verification below. Not deployed. New chat SQL and Dart behavior has not been executed or accepted.**

## Delivered scope

This increment contains **29 new or modified repository files**, a **163-file cumulative overlay**, forward SQL body10, updated Flutter service/screen/components, client/server test sources, a guarded patch/application path and an updated register preserving **all 95 original tasks**. The ten advanced IDs are **M004, M007, M054, M055, M061, M062, M077, M078, M079 and M090**.

Delivery folder: https://drive.google.com/drive/folders/1b6P3qCl5mhT_DDkcOIBVDURcN0JfqTYo

Original folder: https://drive.google.com/drive/folders/120JIOTyeNX6nHaHPDqS3UgbaTWyJAE57

The delivery classifications are **10 advanced in Increment06; 35 retaining earlier source work with acceptance open; 50 not advanced in this increment**. They are not completion percentages or a claim that all features in the open category are absent. No production acceptance is evidenced by these deliveries. Original Drive sources and prior increments are unchanged.

## Full-stack changes

### Stable chat request identity and recovery

The new client protocol saves a verified owner/conversation/message UUID and exact-body hash before sending. The database candidate binds that UUID immutably to its owner, conversation and content, serializes send/cancel operations, and stores the message plus operation receipt in one transaction. A repeat of the same committed ID returns the earlier receipt rather than inserting a second message. A different body or conversation cannot reuse that ID.

Lost send responses retain an unknown outcome and the same recovery pointer. The user can check status, retry the same text or explicitly cancel. Cancellation writes a tombstone when the send is unobserved, so a late request using that ID cannot send. When commit won the race, resolving/cancelling returns the known sent receipt and does not unsend the message.

An already-valid sent receipt remains a known sent result even if the later close acknowledgement or local pointer cleanup fails. The recovery record is retained and the composer is gated until resolution. The implementation does not relabel this as an unsent/failed message or silently dispatch a replacement.

Raw message text is not persisted to a local offline outbox; only recovery metadata is saved. A not-yet-observed pending request after restart requires identical text re-entry or explicit cancellation. Preferences are not encrypted credential storage, hashes are not anonymization, and arbitrary local data loss/new request creation is outside the same-ID retry guarantee. M010 and cross-store retention/deletion remain open.

### Bounded newest-first history and read authority

The new RPC returns newest-first pages bounded to 100 rows, with a stable timestamp/UUID cursor; the UI starts with 50 and displays messages chronologically. It preserves the original server timestamp for cursor/read parameters and validates ordering with BigInt microsecond precision rather than reconstructing SQL equality from a possibly lower-precision display time.

Membership and the existing driver/Plus privacy rules are checked by the RPC. Restricted content has body and metadata redacted. Direct client message access and conversation mutation grants are revoked to prevent bypassing those checks. Read markers use a verified returned message watermark, not the client's clock.

The legacy list RPC is retained with the corrected latest-window order. Existing conversation APIs, moderation and approved external handoff are preserved in source, subject to full-schema compatibility testing.

### Account-bound client lifecycle

Chat bootstrap, profile/trip loading, send/report/block/handoff callbacks, history and delayed read marks carry captured account/session checks. Account changes clear or mask the old view and its drafts/caches. Stream cleanup releases realtime channels, listeners and timers even when a paused consumer does not consume completion. Channels have distinct instance names; refreshes are coalesced and a bounded poll supplements reconnect/update refresh.

Backgrounding clears cached history and stops its stream. Head refreshes reset older pages to avoid showing stale/redacted content. That is a deliberate UX tradeoff requiring real-device/browser acceptance, not a claim of seamless long-history scrolling or measured performance. New recovery/maintenance copy remains English pending the promised-language and accessibility work.

### Operational send control and release transition

New chat sends default **OFF** in body10. The client displays unavailable/paused state without pretending to send. Controlled server/service-role enablement is separate from ordinary client access. Known delivery status/recovery remains available while new sends are paused. This advances only the chat portion of M062, not all operational switches.

**Critical cutover:** the old send RPC returns 410 and raw-table paths are restricted after migration. Older clients can no longer use those paths. A coordinated reviewed client/database/version transition is mandatory. The previously delivered wallet/admin transition conditions also remain in force. No database or live flag was changed here.

The proposed one-second new-send interval and 10,000 retained-operation cap per owner require workload and retention approval. No automatic journal purge was added. Retained operation hashes/tombstones must be included in M069–M070, with a safe reconciliation process before evidence is removed.

## Verification actually performed

| Lane | Passing count | What it establishes |
|---|---:|---|
| New source-applier tests | 11 | Actual local filesystem, path/symlink/drift and repeated-apply behavior |
| New database-runner input guards | 10 | Approved-format immutable image-name validation; no SQL execution |
| New static source contracts | 18 | Source assertions only; no runtime correctness claim |
| Rerun prior Python regressions | 177 | Existing mixed executable fixtures and source assertions |
| Rerun prior Node pure modules | 66 | Existing module logic |
| Rerun prior Node handler fixtures | 138 | Existing TS handler logic with explicit external substitutes |
| Rerun bounded inference HTTP | 16 | Real HTTP behavior with a fake model |
| Rerun NFC Kotlin policies | 20 | Compiled JVM policy; not physical NFC |
| Rerun collector Kotlin/leases | 38 | Compiled pure Kotlin and cross-process file leases; not WorkManager/device |
| **Total** | **494** | **39 new tooling/static checks + 455 rerun prior checks** |

**Zero new chat Dart or SQL behavioral checks were executed.** Do not use the total above as evidence that the new chat flow compiled, ran against PostgreSQL or passed end-to-end acceptance.

The exact delivered source applier was checked, applied and reapplied on a separate affected-source baseline: 29 files matched after application; the second apply changed zero. Independent `git apply --check` and application produced the same 29 file hashes. Action-pin validation, forward-body source hash planning, Python/shell/YAML/JSON checks and patch whitespace also passed. These checks do not establish a complete upstream checkout or applied database state.

Initial missing-dependency/manifest expectation failures were corrected and rerun; original and final logs are retained, with the final result identified in `VALIDATION_RESULTS.json`. Eight restored dependencies were unchanged and matched the supplied current-index blob hashes. The new direct crypto declaration uses the exact previously locked transitive version/hash; no package resolution or upgrade ran.

## Authored but unexecuted acceptance

The new SQL runner uses an isolated official PostgreSQL17 digest-pinned Docker container and synthetic prerequisite tables/functions. It includes duplicate/conflict/ownership/cancellation/read-boundary/pagination/Plus cases and concurrent sessions. Docker was unavailable, and its availability check returned non-pass. Even a future passing component run will not replace the original full schema, real Auth/PostgREST and effective-policy tests.

Dart delivery/history/service/realtime/widget/account-race suites are authored but unexecuted because Flutter/Dart is unavailable. Deno, actual external SDK compatibility, hosted required CI, signed Android/iOS artifacts, physical devices, real model/operator/provider acceptance and production deployment were not run.

The CI lane now requires the maintainer to supply a reviewed actual PostgreSQL17 official image digest via `MOBIO_CHAT_POSTGRES_IMAGE`; no digest was fabricated. Missing tooling/configuration remains a failed/unavailable gate, not a skipped success.

## Source, safety and remaining work

The source baseline reuses the supplied partial indexed recovery, the exact Increment05 overlay and selected original dependencies. A complete canonical upstream main commit has not been established. The earlier GitHub read returned not found and the large Git pack exceeded connector limits; this delivery does not bypass those limits or claim a complete reconstructed repository. Cumulative source is an overlay, not a standalone app.

Live folder permission metadata still grants `anyone` the `writer` role, with link discovery disabled. Permissions were not changed. M001–M002 remain immediate source-access and signing-material remediation; this delivery contains no private signing stores, live credentials or Git objects.

The updated workbook preserves all original IDs, priorities, role owners, dependencies and acceptance criteria and adds current evidence/remaining work. Secure refresh-session storage, notification outbox, complete deletion/retention, non-chat feature controls, full localization/accessibility, real database/device acceptance, model calibration, operator agreements and broader release operations are not marked complete.

Proceed with the integration runbook: reconcile a complete review checkout; rehearse all migrations and the new chat component; run actual client and role/transaction tests; approve the coordinated cutover and workload/retention rules; then explicitly enable only the accepted scope. No production launch, automatic continued background work or all-task closure is implied.
