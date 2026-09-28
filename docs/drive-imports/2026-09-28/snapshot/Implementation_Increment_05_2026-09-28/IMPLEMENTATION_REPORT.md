# Mobio Increment05 — full-stack implementation started

28 September 2026 · First implementation wave against the 95-task register

**Status: source implemented and locally verified in the stated lanes; not deployed, not a complete production release, and not closure of all 95 tasks.**

## Delivery

Increment05 contains **41 new or modified repository files**, a **138-file cumulative overlay** retaining the prior hardening, two new forward SQL bodies, a guarded source applier, a Git patch, client/backend test sources, a read-only reconciliation utility and a refreshed register covering every original task. It advances **13 tasks**: M003, M007, M009, M021, M023, M053, M054, M055, M077, M078, M079, M090 and M091.

The current register contains **13 advanced in Increment05, 30 retaining earlier source work with acceptance open, and 52 not advanced in this increment**. These are delivery classifications, not percentages of application functionality. All 95 original tasks retain their acceptance criteria, owner roles, dependencies and outstanding work. No production acceptance is evidenced by this delivery; that is not an assertion that external organizational approvals do not exist.

Destination: https://drive.google.com/drive/folders/17sn4bVbylDAKjk0K8NfAIKQmWoSMHdnG

Original Mobio folder: https://drive.google.com/drive/folders/120JIOTyeNX6nHaHPDqS3UgbaTWyJAE57

Original Drive source files and earlier delivery increments have not been overwritten. This package is an overlay for review integration, not a standalone Flutter repository or a signed installation artifact.

## What the first wave implements

### Server-owned administrative sessions

SQL body08 adds private, owner/session-bound admin leases. Registration checks a consumed admin-purpose OTP, the corresponding new Auth session, authoritative verified phone identity and the active administrative allowlist before the endpoint returns session credentials. Existing administrative identity resolution is tightened to check the lease, expiry and revocation in addition to its live identity checks. Status reads do not extend idle time, and expired leases cannot be revived through touch.

The Edge OTP path uses canonical verified identity instead of an unbounded directory scan or editable contact-alias selection. Flutter now requires successful session restoration and server lease confirmation. A surviving older session is not accepted as a successful login. Routing no longer treats role metadata alone as sufficient to bypass the timeout, while already-open admin views are masked on expiry or backgrounding. Foreground interaction can request lease touch; background timers cannot keep a session alive indefinitely.

The 15-minute idle, eight-hour absolute and five-minute recent-authentication settings are engineering proposals requiring owner approval. A recent-authentication helper is supplied, but the complete high-impact-operation permission audit and wiring of that helper into every relevant RPC are still outstanding. This is not a claim of fully completed delegated administrative least privilege.

### Account exit and asynchronous ownership

The client has a persisted fail-closed exit marker, bounded native/local cleanup, local sign-out and owner/session generation checks. Sign-out no longer performs anonymous network authentication or treats a remaining SDK session as successful exit. Only a fresh explicitly verified login clears the exit marker.

Profile and wallet loads discard responses belonging to an old account/session. Wallet entry, confirmation and receipt views are masked when ownership changes. The generation model covers A-to-B-to-A changes and distinguishes a token refresh within the same session from a different session. Remaining shell, chat and booking callbacks still need a complete account-switch audit.

The exit marker is **not encrypted credential storage**. Native OS-protected refresh-session persistence, M010, remains open.

### Wallet request journal and uncertain-outcome recovery

SQL body09 adds private owner-bound prepare, execute, status and close operations. An immutable request and operation UUID are retained server-side, with one unresolved operation slot per account. The execute path calls the existing token-transfer/redemption functions and records their receipt in the same SQL transaction. It checks the actual ledger receipt against owner, recipient, amount and request binding. Cancellation serializes with execution and cannot undo a committed transfer.

Flutter has typed request/receipt models, an account-bound minimal local operation pointer and server-side recovery of unresolved operations. A timeout is represented as an unknown outcome, not proof of failure or payment success. Preparing and retrying the same request reuses its identity; a different unresolved request is blocked. Receipt acknowledgement and closing are explicit.

Legacy ownerless local pending-transfer/redemption records are detected and block new operations for reviewed resolution. They are not silently assigned to the current account, purged, logged or replayed. The utility does not introduce a new settlement engine, automatic MoMo debit or refund mechanism.

**Critical cutover:** body09 revokes direct authenticated execution of the legacy wallet mutation RPCs so they cannot bypass the journal. Older clients will be blocked after that migration. A coordinated reviewed database/client release, maintenance or version gating, and reconciliation of in-flight legacy operations are required. Nothing has been applied to a live database. Retention and account-deletion handling for the new journal also require completion under M069–M070.

### Startup resilience

The application mounts a launch state promptly, bounds mandatory configuration and SDK initialization, and defers optional Firebase, push and attribution work from the minimum launch path. Required configuration and the local exit marker still fail closed. The code avoids concurrent reinitialization after timeout; late optional completion cannot mount a protected view. Error reporting uses sanitized events rather than raw sensitive payloads.

A deadline stops waiting; it is not cancellation of the underlying provider operation. The actual SDK startup path, release compilation and device timing still need runtime verification. No measured startup improvement is claimed.

### Read-only financial reconciliation

`scripts/operations/reconcile_receipts.py` compares normalized operator, ingestion and credit exports using exact operator, merchant and transaction-reference identity. It flags amount/currency inconsistencies, duplicate references, conflicting invoice allocations, review/pending states and missing counterparts. It does not match loosely on amount/time, activate invoices, change the ledger, connect to a provider or treat an uploaded CSV as independently authenticated settlement evidence.

The command validates required fields, positive integer minor-unit amounts, timezone-bearing timestamps and bounded input size. It creates a new restricted output directory with machine-readable results and input hashes. Real export adapters, authentic operator evidence, a consistent reporting cutoff, daily scheduling and assigned exception ownership remain to be implemented and accepted.

## Verification actually completed

**455 local checks/scenarios/source assertions passed across individually completed lanes.** This includes **102 new checks** (87 executable or fixture checks and 15 static source assertions), plus **353 rerun regression checks**. It is not a count of end-to-end tests.

| Lane | Passed | Boundary |
|---|---:|---|
| New admin lease and OTP handler fixtures | 45 | Actual TypeScript logic with explicit Auth/database/SDK substitutes |
| New receipt reconciliation | 24 | Real Python and temporary files; synthetic normalized exports |
| New guarded source applier | 11 | Real filesystem, drift, path and symlink checks |
| New database-target guards | 7 | DSN validation only, not SQL execution |
| New source contracts | 15 | Static text assertions, not Flutter/database behavior |
| Existing Python regression checks | 120 | Mixed executable fixtures and source assertions |
| Existing Edge/login/intake fixtures | 159 | Explicit substitutes at external client boundaries |
| Bounded inference HTTP | 16 | Real HTTP behavior with a fake model |
| NFC Kotlin policy | 20 | Compiled JVM policy, not Android hardware |
| Collector Kotlin policies and leases | 38 | Compiled pure Kotlin and cross-process file leases, not WorkManager/device acceptance |
| **Total** | **455** | **Local evidence only** |

Strict TypeScript checks with declared external runtime/SDK substitutes, action-pin validation, shell/Python syntax and SQL manifest planning/hashes also passed. No actual Deno/Supabase SDK compatibility claim is made.

The guarded applier was tested against a separate reconstructed baseline: all 41 file hashes matched, and a second apply made no changes. An independent `git apply --check` and application produced the same 41 expected file hashes. Source replacements are atomic per file, not one all-files filesystem transaction.

Two aggregate shell invocations reached this environment's command timeout during Kotlin compilation. The affected components were completed separately; the aggregate invocation itself is not labelled PASS. Historical and intermediate logs are retained, while `VALIDATION_RESULTS.json` describes the final individual results and boundaries.

**Not executed:** PostgreSQL 17/full-schema financial transactions and catalogue probes (psql unavailable); Dart/Flutter compilation and new client tests; native Deno tests; actual Auth/PostgREST and provider integration; hosted required CI; signed Android/iOS builds; physical-device SMS/NFC/USSD; the real face model; or production deployment. Authored tests and unavailable lanes are not counted as successful execution.

## Source and access boundaries

The configured GitHub repository read returned not found. The available Drive Git pack yielded 358 files matching the supplied current index; 1,718 other indexed files were not recovered by that route. The larger pack exceeded the connector download limit. Selected original Drive dependencies were fetched separately and reconciled with the cumulative Increment04 overlay. A complete current upstream checkout and main commit were not established.

Exact source IDs, baseline archive hash and provenance are in `SOURCES.json`; before/after file hashes are in `DELTA_MANIFEST.json`. Do not overwrite a newer checkout blindly or assume the partial reconstruction is a complete build tree.

Live metadata still shows the Mobio root grants `anyone` the `writer` role, with link discovery disabled. Permissions were not changed. M001–M002 remain immediate owner/security work: restrict access, review activity and exposed signing material, and complete appropriately scoped credential remediation and signed-update validation. No private signing stores, credentials or Git object database are included in this delivery.

## Integration and remaining implementation

Use an isolated review branch containing the complete Mobio source and reconciled prior changes. Read the integration runbook and inspect both SQL bodies before database work. The source applier checks first by default:

```sh
python3 apply_increment05.py --bundle /path/to/Mobio_Increment05_2026-09-28 --repo /path/to/mobio-review
python3 apply_increment05.py --bundle /path/to/Mobio_Increment05_2026-09-28 --repo /path/to/mobio-review --apply
```

These commands change reviewed local source only; they do not deploy functions, migrate a database, change account permissions or contact a financial provider. The existing migration preparation workflow creates actual timestamped migration files once the complete local schema and approved Supabase CLI are available. Bodies08–09 are forward SQL candidates, not a fabricated applied migration history.

The refreshed workbook has Overview, All 95 tasks, Acceptance and provenance, Verification, Workstreams and Sources tabs. Its ten workstreams retain all 95 IDs exactly once. Each task records its current evidence and remaining implementation/acceptance rather than being marked done because a helper or document was added.

Next critical execution is full-schema clean/forward database rehearsal and real role/transaction testing (M078–M079), coupled client/backend integration, and signed-device end-to-end acceptance. Further implementation remains for secure credential storage, complete account-wide async coverage, notification outbox, chat reconciliation/pagination, retention/deletion workflows, full feature switches, localization/accessibility, recovery/monitoring and the other explicitly open register entries. Model calibration, actual operator configuration, legal/privacy decisions, credentials and signed release ownership need genuine evidence, not generated substitutes.

The approved face-to-USSD scope is unchanged: no liveness workflow, payer biometrics, PIN capture, automatic debit, MoMo API or route-computation feature has been added. Existing manual/QR flows and the previously delivered SMS controls are preserved. **The full implementation programme has started; this increment is its first reviewed source wave, not completion of every release gate.**
