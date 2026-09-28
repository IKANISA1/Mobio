# Mobio folder investigation and implementation — Increment04

28 September 2026 · Source implementation and local verification · **Not deployed / not production accepted**

## Delivery result

Reviewed the Mobio folder's original 95-task backlog, production report, latest complete Increment03 cumulative overlay and selected underlying source dependencies. Implemented 25 new or modified repository files addressing the durable-SMS processing gap and related safeguards. This is a targeted follow-on investigation, not a fresh exhaustive scan of every file or an attestation of the live app.

The package contains the exact delta, a 104-file cumulative overlay preserving previous hardening, a hash-guarded source applier, operational and PostgreSQL component test runners, local evidence, and the full 95-task register in Excel and JSON. Original Drive source files and older increments have not been overwritten.

## Important current finding

**The target Mobio folder still grants `anyone` the `writer` role, with link discovery disabled.** This was verified from live Drive permission metadata in this session, not merely repeated from the earlier audit. Anyone possessing the link can edit its contents. Permissions have not been changed. Restrict the folder to approved users and investigate the signing material identified in the September27 audit; replace exposed active credentials through the authorized release process. No private signing files were needed or included in this delivery.

Target: https://drive.google.com/drive/folders/120JIOTyeNX6nHaHPDqS3UgbaTWyJAE57
Delivery: https://drive.google.com/drive/folders/14lsaqxYMJutws1GNQQYHZka0ZOZgjXNf

## Gap identified and changes implemented

The prior complete package explicitly left M032 open: eligible SMS parsing was still sequential and synchronous before durable receipt acknowledgement. Increment04 changes the source flow to **signed receipt → validated atomic admission → HTTP acknowledgement → separately claimed processing → lease-fenced SQL completion**. An acknowledgement is not a successful payment.

| Area | New implementation | Acceptance still needed |
|---|---|---|
| Signed admission | One batch RPC; all envelopes validated; complete response checked before acknowledgement | Actual collector/PostgREST, outages, dropped responses and device retries |
| Duplicate safety | Immutable per-collector hash/payload binding; same-key different-content rejection | PostgreSQL transactional and cross-session tests |
| Private queue | Service-only tables/RPCs, capacity limits, default-off policy and retained review state | Real grants/RLS under the complete schema and approved retention |
| Worker | Separate server token; one claimed job; no caller-selected identity; Edge/collector policy intersection | Deployed Deno, actual provider and environment validation |
| Completion | Current lease fenced before unchanged strict allocator; queue and allocator work in one SQL transaction | Real financial allocator, concurrency and commit/failure injection |
| Reliability and cost | Finite attempts, exponential backoff, expired-claim recovery, concurrency and fixed-hour attempt budgets | Load, latency, contention, provider costs and incident drills |
| Operations | Signed health counts/heartbeat; bounded curl trigger; optional explicit systemd scheduling | Approved server/secret configuration, scheduling and monitored staging rollout |
| Delivery/QA | New fixtures in existing CI; guarded patch/applier; per-file hashes; complete task register | Actual hosted CI, full repository integration and protected branch gates |

This work advances M029, M032, M034, M077, M078, M079, M090 and M091. It does not close their real-environment acceptance criteria. The existing face-to-USSD scope remains unchanged: no liveness, new face UI, biometric payer authentication, silent debit, PIN handling or new MoMo API has been introduced.

## What was verified locally

| Verification lane | Result |
|---|---:|
| New actual Node admission/worker code with real RSA and explicit database/parser fixtures | 86 passed |
| Existing Edge pure-module regressions rerun | 66 passed |
| Python operational/database-target guards and source-contract assertions | 20 passed |
| Actual temporary-file delta-applier regressions | 8 passed |
| Total counted local tests/source checks | **180 passed** |
| TypeScript strict compile with explicitly substituted external declarations | Passed |
| GitHub Actions pin validation, TOML parsing and shell syntax | Passed |
| Exact delivered patch/applier checked against the reconstructed baseline | Passed; all 25 file hashes matched |
| PostgreSQL17 queue component and eight-session concurrency runner | **Not executed: psql unavailable (exit2)** |
| Complete schema, actual Auth/PostgREST, real SDK/Deno/provider, signed devices and deployment | **Not run** |

The twenty Python checks include nine source assertions; they are not database-behavior tests. The TypeScript declarations substitute external runtime/client types. The supplied PostgreSQL runner uses synthetic prerequisite tables and an explicitly labeled financial-allocator double: even when it runs successfully, full-schema financial acceptance remains separate. Historical test totals in earlier packages were not added to the 180 current-run checks.

## Remaining work, in execution order

**Contain access and signing risk first (M001–M002).** Restrict anyone-with-link write access, audit changes, inventory exposed signing material, and complete authorized key replacement and release-lineage validation. These are not fixed by adding application code.

**Integrate and rehearse backend authority (M003–M005, M015–M020, M078–M080).** Reconcile the overlay with the actual upstream checkout, prepare genuine forward migration files with the existing CLI helper, test both clean and forward upgrades, and run the real Auth/role/ownership matrix. Prove passenger booking authority, receipt/invoice replay safety, inventory and concurrent subscription behavior in the real schema.

**Complete receipt operations (M023–M034, M070, M091).** Validate real approved operator SMS samples, deploy admission/worker with allocation OFF, test retry/offline/power-loss and lost-response paths, then validate explicit scheduler and cost/queue limits. Implement approved retention and audited manual review/replay; do not silently purge or automatically credit review records. Reconcile against operator evidence before enabling automatic activation.

**Complete face and native release acceptance (M035–M050).** Validate the selected face provider/model, accuracy/capacity/deletion, real NFC/USSD device behavior, Android/iOS build and store requirements, permission/runtime boundaries and private collector distribution. No new face product features are proposed here.

**Close broader product, privacy and release operations (M051–M095).** The full register retains regional rollout, performance, critical translations/accessibility, lifecycle cleanup, policy/processor approvals, deletion/retention, CI/dependency evidence, backups/recovery, incident response, staged rollout, support and cost tasks. Specific acceptance criteria and dependencies are preserved for all95 rows rather than replaced with a generic checklist.

Current delivery classification: **8 updated now; 29 retain earlier source work awaiting acceptance; 58 have no completion evidence in these delivery increments.** This is not a claim that58 application features do not exist. No production acceptance is evidenced by the reviewed delivery packages; external organizational approvals were not exhaustively audited.

## Using the code

Use a clean review branch with the complete Mobio source. The archives here are overlays, not a standalone Flutter app or a signed binary. First reconcile the prior complete Increment03 overlay. Then inspect `DELTA_MANIFEST.json` and run:

```sh
python3 apply_increment04.py --bundle /path/to/Mobio_Increment04_2026-09-28 --repo /path/to/mobio-checkout
python3 apply_increment04.py --bundle /path/to/Mobio_Increment04_2026-09-28 --repo /path/to/mobio-checkout --apply
```

The first command only checks. The second refuses unexpected baseline bytes, unrelated new-path content and symlinks; replacements are atomic per file, not a cross-file filesystem transaction. The delta patch is also provided. Do not blindly overwrite a newer checkout with the cumulative overlay. No applier operation links a project, changes a database, deploys a function or calls a payment/provider endpoint.

Read `INTEGRATION_RUNBOOK.md` for ordered migration/function deployment, default-off controls, actual runtime tests and optional scheduling. All live deployment and production enablement remains subject to those gates.

## Source provenance

The complete prior package is https://drive.google.com/file/d/19b78ZKRec3FG_N1fGbDFpu2SwpYUUHWu/view . It supersedes the separate older Increment03 collector generator for this review. The full original backlog is https://drive.google.com/file/d/15X3_uSbHztLL57IL_d3Xo9hc9zInJuyN/view and the original audit report is https://drive.google.com/file/d/1QGQeKDZ_139Nw1DzXiEhfbggCVB301tz/view . Exact dependency IDs and input archive hashes are in `sources.json`.
