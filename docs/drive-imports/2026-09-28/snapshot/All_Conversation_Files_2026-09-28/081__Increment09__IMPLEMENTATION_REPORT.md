# Mobio Increment09 — implementation delivery report

28 September 2026 · Authenticated deletion requests, supervised fulfilment evidence and retention visibility

**Status: source implementation with the local verification below. Not deployed. New SQL and Flutter behavior has not been executed. No account or provider data was erased.**

## Delivery and remaining task register

This increment contains **26 new or modified repository files** and a **225-file cumulative overlay** retaining prior work. It adds Flutter request/status/cancellation, a caller-scoped Edge gateway, forward SQL body12, private request/action/evidence tables, an administrative health card, an evidence-manifest verifier, test sources, CI integration, a guarded source applier and a Git patch.

Delivery folder: https://drive.google.com/drive/folders/1SM66T5NPwOUCwRdId3SbQULe7wWP_Huk

Original Mobio folder: https://drive.google.com/drive/folders/120JIOTyeNX6nHaHPDqS3UgbaTWyJAE57

Nine tasks advance: **M004, M054, M055, M069, M070, M077, M079, M084 and M090**. The current classifications are **9 advanced in Increment09, 42 with earlier source work awaiting acceptance, and 44 not advanced in this increment**. All95 original task IDs, priorities, owners, dependencies and original acceptance criteria are preserved. No production acceptance is evidenced by this package. These counts are not percentages of application functionality.

The source is an integration overlay, not a complete standalone app repository or signed artifact. Original Drive files and previous increments were not overwritten. The previous eleven SQL bodies and package dependency versions remain unchanged.

## What was implemented

### Authenticated user request path

The existing profile action opens an external deletion/contact page. The new verified-user path presents an account-bound request screen with current intake policy, notice-version acknowledgement, request receipt/history and cancellation where still allowed. The original contact page remains available, including for anonymous/unverified users and when in-app intake is disabled or unavailable.

The Flutter service captures the original account/session and bearer before network work, rejects another owner's response and discards stale asynchronous results. The screen clears or masks state on lifecycle/account changes. A lost response is an unknown outcome, not proof of failure or completed deletion; the server's owner-bound active-case constraint prevents a second active request after restart. Raw private error payloads are not displayed.

The Edge gateway accepts only fixed policy/list/status/request/cancel actions. It forwards the exact caller JWT to one fixed PostgREST RPC, uses no service-role authority, rejects caller-supplied subjects/URLs/SQL, bounds request and response bodies and deadlines, prevents redirected credential-bearing requests and applies exact browser-origin allowlisting. JWT shape validation in the gateway is not signature verification; PostgREST and the live verified-account helper remain the authorization boundary.

### Private case and supervised fulfilment lifecycle

SQL body12 defines RLS-enabled private tables with explicit table and RPC grants. Request admission serializes by owner, enforces one active case, binds immutable request ID/notice identity and requires a fresh actual Auth session. Same-ID retries remain observable after cancellation or policy disablement. Cancellation is allowed only before processing starts; blocking an already-started case does not restore cancellation rights.

Service-only fulfilment records start/block/evidence/complete actions with immutable action UUIDs, input binding and compare-and-swap revisions. Evidence corrections append later revisions without deleting earlier attestations. Processing binds to a reviewed inventory and plan hash. Completion requires ten current evidence categories, a completion-manifest hash and direct checks that the Auth user and sessions are absent.

**This is not an automatic erasure implementation.** There are no cross-provider deletion adapters or automatic purge jobs in this increment. Evidence recording does not delete SQL business records, files, vectors, processors or backups. M069's original cross-store completion/non-manual-only requirement remains open, alongside complete inventory, durable erasure retries, verified provider probes and completion notification after Auth removal.

### Retention and honest completion status

The evidence categories cover sessions, Auth, profile/activity, financial records, delivery journals, storage, face vectors, processors, backups and the new privacy case records. They are a checklist for a genuine complete inventory—not proof that the partial source reconstruction has found every live data store.

Auth/session outcomes must be deleted. Retained categories require a finite future review/expiry date and a basis reference. The workflow itself retains identifiable case/action/evidence metadata, so **privacy case records require an explicit retained exception**. Closure is therefore recorded with retention rather than falsely claiming that all personal metadata is gone. No arbitrary production retention period or statutory deadline was invented.

The administrative health RPC/card exposes aggregate request states, oldest pending age and due retention reviews, not subject identifiers. It explicitly says that provider erasure is not automatic. Retention expiry still needs an accountable review/purge process; the counter does not perform that work.

### Local evidence verification

The read-only Python verifier checks bounded JSON, exact identity/category bindings, timestamps, local evidence-file hashes and matching retention decisions. It rejects duplicate keys, excessive nesting, nonfinite values, path traversal, symlinks, missing/oversized files and incomplete coverage. It creates a new restricted output rather than overwriting evidence.

Its success means local structure and file integrity were verified. It does **not** independently confirm an operator's deletion assertion, call a provider, change a database case or establish legal compliance. The completion RPC does not automatically fetch or validate that manifest; a reviewed operator/controller must bind the locally verified evidence to the service-only action. Real evidence belongs in a restricted evidence system, not the publicly editable source folder.

## Verification actually completed

**483 local checks passed: 131 new executable/fixture checks plus 352 selected prior regression checks.** Unlike previous delivery totals, this count does not rerun every unrelated earlier lane. It is not an end-to-end test count.

| Lane | Passed | Boundary |
|---|---:|---|
| New privacy gateway | 70 | Actual TypeScript logic with explicit controlled PostgREST responses; not real Auth/database |
| New local evidence verifier | 40 | Real Python and local files using synthetic evidence; no provider erasure |
| New database-runner guards | 10 | Image-name validation and literal quoting; not SQL execution |
| New guarded source applier | 11 | Real filesystem, baseline drift, path/symlink and repeat application |
| Selected prior Python regressions | 282 | Mixed executable fixtures and source assertions; not all prior lanes |
| Prior push worker/provider tests | 70 | Actual TS/WebCrypto/HTTP logic with explicit Google/database fixtures |
| **Total** | **483** | **Local evidence only** |

Strict TypeScript checking for the new core/shared HTTP dependency passed without fabricated SDK declarations. Python/shell/JSON/TOML/YAML checks, Actions source pins and all twelve forward-body hashes/planning passed. The previous eleven SQL bodies are byte-identical to Increment08.

The exact guarded applier was tested against a separate affected-source baseline: **26 files matched**, and a second application changed **zero**. Independent `git apply --check` and application produced the same26 hashes and modes. This proves package integration against that reconstructed affected-source baseline, not a complete upstream build.

Initial import/test-fixture and two inherited manifest-position expectation failures were corrected and rerun. The manifest checks now retain the earlier body at its original position and include the new twelfth body. Evidence-parser nesting was made explicitly bounded rather than relying on an environment-dependent Python recursion limit. Final test logs are identified in `VALIDATION_RESULTS.json`; intermediate failures are not counted as passes.

## Not executed and not claimed

The PostgreSQL component runner is authored with an empty, network-disabled, official digest-pinned container and explicit synthetic Auth prerequisites. Docker/psql were unavailable; its availability check returned non-pass. **Zero new SQL behavior/concurrency tests ran.** Even a future component pass must be followed by full-schema clean/forward migration and real Auth/PostgREST/grant testing.

Thirteen new Flutter domain tests are authored but unexecuted. Flutter/Dart compilation, service/widget/native-device acceptance, deployed Deno behavior, hosted CI, signed Android/iOS artifacts, real provider erasure and production deployment did not run. No new legal approval, full provider inventory, external deletion receipt or retention policy is represented as genuine evidence.

Earlier source-referenced Mobio Supabase permission denial remains respected; no alternative credential route was used. The available source remains the supplied partial current-index recovery plus exact Increment08 overlay. A complete current upstream main revision has not been established.

## Integration and remaining work

**Intake and processing default OFF.** Enable only after accepting the real schema/auth/client path, the corresponding deletion notice, support ownership, approved inventory/plan and retention handling. The proposed fresh-session age300seconds and three-new-requests/day are engineering defaults for review, not legal deadlines. New copy remains English pending the promised-language/accessibility work.

The client, Edge function and SQL must be integrated together. The old external page is retained as a visible alternative, not claimed as newly implemented automatic web erasure. Once Auth is actually deleted, that user's authenticated status route is unavailable; a verified completion-notice/support channel remains required. Do not expose an unauthenticated lookup by subject ID as a workaround.

Read `INTEGRATION_RUNBOOK.md` before applying source or preparing migrations. It includes the fixed RPC contracts, evidence categories, approval and retention boundaries, runtime acceptance scenarios and rollback considerations. The prior native-session, admin/wallet/chat/SMS/push release-transition requirements remain.

The source folder's permission metadata was rechecked: **anyone with the link still has writer access**. Permissions and signing credentials were not changed. M001/M002 remain immediate owner/security work. No database, scheduler, provider account, financial record or live feature flag was modified.

The approved face-to-USSD scope is unchanged: no liveness, PIN capture, automatic debit or new settlement/routing engine was introduced. Full cross-store erasure/retention, all remaining operational controls, localization/accessibility, release acceptance and the other backlog requirements are not silently marked complete.
