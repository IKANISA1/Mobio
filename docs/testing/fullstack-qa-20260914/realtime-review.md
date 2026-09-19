# Realtime and driver discovery review

15 September 2026. **FQA-037 is fixed and regressed locally. Full-system QA remains incomplete and NO-GO.** The goal stays active. All file names below refer to `build/qa/fullstack-qa-20260914/` unless a source path is given.

Subsequent app-layer work reproduced and repaired the chat join/reconnect gap as FQA-038. See [chat-recovery-review.md](chat-recovery-review.md) for the current source and 648-test regression. The service observations and original source binding below remain a dated checkpoint.

## Service and test authority

The test uses the unmodified official Realtime **2.124.4** image, digest `sha256:446e4db4b088c3ed91465250c5f9d5712d37e284b08545d91f965e8d7396d8ba`, with actual GoTrue **2.195.0**, PostgREST **16.1** and PostgreSQL **17.6.1.158**. The frozen JavaScript SDK resolves to **2.105.4**. Services share the owned database's network-none namespace, publish no ports and cannot deliver to external providers. A temporary loopback transport forwards real websocket bytes, rewriting only the gateway path and local tenant Host header. It supplies no fabricated authentication or events. Auth-issued tokens stay in a separate mode-0600 private file.

`realtime-service-start.json`, `realtime-primary-sources.json`, `realtime_qa_tcp_gateway.py` and `realtime_qa_client.ts` bind the service and transport. Realtime creates 12 platform tables across its own schemas and two logical replication slots. Those are service state, separate from Mobio's migration history. The public relation count remains 304. This is isolated service qualification; hosted versions, network behavior and compiled Flutter clients are unverified.

## FQA-037: protected discovery bypass

Before repair, an anonymous Auth session and an unverified email Auth session could receive online driver coordinates through REST and Realtime. The public anon API key could invoke the discovery search RPC and obtain a synthetic driver's data. An unverified session continued receiving coordinates on an existing websocket after real Auth logout.

The SELECT policy allowed `is_online=true` without requiring a verified identity. The SECURITY DEFINER search and summary functions lacked an identity check and retained PUBLIC/anon execute access. This conflicts with the verified WhatsApp requirement in `CRITICAL_RULES.md`. The reproduction used only synthetic accounts and coordinates; no production exposure is established. No active caller of the legacy `subscribeToDriverUpdates` helper was found, but direct API exposure is independently reproduced.

`supabase/migrations/20260915003031_harden_driver_discovery_identity.sql` now requires a live `verified_app_user_id()` for the online/owner/Admin SELECT policy. Both RPCs require that identity or the trusted service role. PUBLIC/anon execute is revoked; authenticated and service-role grants remain. The function signatures, filters, existing discovery calculations and return shapes are preserved. No route computation, dispatch, payment or tracking feature is added.

The migration was created with `supabase migration new`. It was applied only to the owned database and qualified in a separate fresh CLI replay. No linked/production migration or deployment occurred.

## Verification and original results

| Evidence | Observed result | Scope and qualification |
| --- | --- | --- |
| `realtime-authority-regression.json` | 23 checks: 14 passed, eight driver authorization failures, one cleanup expectation mismatch | Original pre-repair result retained |
| `realtime-authority-final-regression.json` | 23 checks: 22 passed, one cleanup expectation mismatch | All eight reproduced driver exposures are denied after repair |
| `realtime-unsubscribe-regression.json` | Three passed | Two channels first receive the same authorized event; after removing one, only the retained channel receives the next event; the specific removed database row clears after 10.153 seconds |
| `realtime-chat-logout-regression.json` | 13 checks: 12 passed, one error-contract expectation mismatch | Actual chat create/send/list, participant isolation, private notifications and verified Auth logout |
| `realtime-revoked-rest-regression.json` | One corrected-contract retest passed | Revoked bearer returns explicit HTTP 401/PT401; the initial harness wrongly required empty HTTP 200 |
| `driver-discovery-authority-sql-v2.log` | 25 assertions passed, transaction rolled back | Permanent SQL roles/claims matrix covers verified viewer, own offline driver, active/deactivated Admin, anonymous, unverified, expired/revoked identity and trusted service role |
| `realtime-cli-rehearsal.json` | 103 migrations, ten SQL suites and eight OTP rate-limit cases passed | Pinned CLI 2.84.2, separate PostgreSQL 17.6.1.095; replay container removed by its cleanup trap |
| `realtime-discovery-routine-summary.json` | Two changed routines checked, no diagnostics | Static PL/pgSQL check against the actual effective catalog |
| `realtime-database-catalog-summary.json` | Catalog captured; Storage/Realtime SQL audit returned no findings | 90 public/Storage relations, 133 policies, 168 application functions, four buckets; presence alone is not runtime acceptance |
| `realtime-validation-runs.json` | 643 Flutter tests and 109 Deno tests passed; one Deno test ignored; Dart clean | 16 Edge entrypoints type checked; structure, secrets and whitespace passed; release script stopped on missing approved configuration |

The corrected unsubscribe test follows the pinned service's 15-second deletion-queue cadence. The original immediate and five-second row-count requirements were harness errors. Delivery cessation was separately tested with a positive control. No Realtime service code was changed. The cadence is visible in the [pinned SubscriptionManager source](https://raw.githubusercontent.com/supabase/realtime/v2.124.4/lib/extensions/postgres_cdc_rls/subscription_manager.ex); a local source copy and hash are recorded in the unsubscribe result.

The verified logout test first proves that the passenger receives private notifications and driver/chat updates. Actual Auth logout then deletes its session row. The already-connected websocket receives no later coordinates, notifications or chat updates; the driver's independent session still receives updates and sends a response. Search and summary return 401 for the revoked bearer. These checks are stronger than the earlier unverified-session logout case and retain their separate evidence.

`realtime-harness-qualification.json` preserves all original outcomes. Setup diagnostics also remain: an initial concatenated SQL candidate omitted statement terminators, and an initial SQL fixture used the wrong country dial-code format. Both failed inside rolled-back transactions before their corrected runs. They are not product findings or passing executions.

## Unclosed runtime work

The first cold subscriber reported SUBSCRIBED but its immediate notification did not arrive within 15 seconds. Initial health had reported `healthy=true` with database and replication connections false; subsequent health showed connections true. The later warm probe waited for the actual subscription row and delivered the exact event. **That warm pass does not resolve the initial cold-start miss.** Initial readiness, join gaps and recovery must still be qualified.

`ChatService.streamMessages` at the source fingerprint below fetched before subscribing and refreshed only on conversation UPDATE. The subsequent FQA-038 work reproduced and repaired its join/reconnect convergence; see the linked chat recovery review. Notification service lifecycle, rapid account changes, token replacement, disconnect/reconnect, ordering/duplicates, background/resume and performance remain unverified in compiled Flutter runtimes. The driver subscription helper has no active caller found; its existence does not authorize adding a tracking feature.

Storage finding **FQA-035 remains open**. Neither this discovery repair nor ordinary RLS/realtime passes resolve the separate privileged concurrent-upload race in tested Storage 1.68.10. See `storage-review.md`.

## Cleanup and source binding

`realtime-retained-environment.json` confirms removal of 25 notifications, one new conversation with its messages, one driver-location row and three temporary Auth accounts. Eleven earlier users/profiles remain with ten live sessions: the verified passenger session was intentionally revoked through Auth. The previous three conversations and four messages remain. Subscriptions, notifications, driver locations, Storage object rows, HTTP queue, OTP rows, FCM tokens and Admin audit rows are empty. Admin approval is restored, Storage's 62 platform migrations are unchanged and cron execution remains off. The temporary websocket gateway was stopped. Five owned services remain available for further isolated QA.

Current source has **1,964 files**, fingerprint `dec8969777c8cee28f691d3b2d9f0d23b0dc4780f225c131949fbf4feebf63b5`. The only changes in this batch are the new discovery migration, its permanent SQL regression and inclusion in `scripts/qa/test_biopay_full_schema.sh`. All 1,955 previously sealed raw artifacts and 32 prior report/register copies are preserved. `realtime-validation.json` records the final checkpoint validation and counts.

The register now has **643 rows: 601 bounded passes, seven retained failing Storage race executions and 35 unverified groups**, with **37 findings** and **250 evidence entries**. Repetitions and suite rows overlap; these counts are not a whole-system quality percentage. All 52 product procedures, 100 design rules and ten MOBILE-DESIGN-100 criteria remain overall unverified. Configured artifacts, actual installed PWA/native journeys, provider/device/hosted CI and independent/owner acceptance remain separate gates.
