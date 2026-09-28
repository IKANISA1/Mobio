# Mobio Increment05 — integration and acceptance

28 September 2026. Source implementation wave, NOT a deployed or accepted release.
Preserve the current Flutter/Riverpod/GoRouter architecture and the approved amount-free face-to-USSD scope.
No new liveness, payer biometrics, automatic debit, PIN capture, MoMo API or route-computation feature is introduced.

## Concrete implementation

- Admin: canonical verified Auth lookup instead of enumerating the directory or consulting another profile's editable phone alias. A consumed admin OTP and new real Auth session must register a private server lease before credentials leave the endpoint. The resolver used by existing administrative authority checks now also enforces that lease, idle/absolute expiry and revocation. The actual Flutter OTP service requires successful session restoration and server lease confirmation; a prior surviving session cannot count as success. Routing cannot grant access from role metadata alone. Already-open admin views are masked on expiry/backgrounding; only foreground interaction requests touch.
- Account lifecycle: a persisted fail-closed exit marker, owner/session generation checks, bounded cleanup, local sign-out and no anonymous network authentication during exit. Profile/wallet reads and confirmation views discard another session's late data. The exit marker is NOT encrypted credential storage: M010 remains open.
- Wallet: private owner-bound prepare/execute/status/close journal, one server-retained unresolved operation, immutable request binding, unique operation UUID, actual existing token-transfer/redemption calls and their receipt in one SQL transaction. Direct authenticated legacy mutation execution is revoked to avoid bypassing the journal. The Flutter service persists a minimal owner/op pointer before execution, reconciles via server status and requires explicit receipt acknowledgement. Version-one ownerless local pending keys block new requests for supervised reconciliation; no raw key/note is logged or guessed to belong to the active account.
- Startup: mount the launch screen immediately, bound mandatory local authority/SDK initialization, fail closed if mandatory initialization cannot finish, defer optional Firebase/push/attribution work until the main app mounts, keep sanitized crash events and the release error view. Timeout bounds waiting; it is not cancellation or measured startup performance.
- Reconciliation: read-only normalized operator/receipt/credit CSV comparison with exact operator+merchant+reference identity, amount/currency/invoice checks, duplicate review, pending states, input checksums and new restricted report directories. It makes no financial mutation and does not independently authenticate a supplied operator export.

## Integration contract / prerequisites

The package is an overlay, not a standalone source checkout or binary. The Drive Git index recovered 358 files, but 1,718 other indexed files were not recovered from the available small pack. Selected additional actual Drive files supplied missing changed-path dependencies. A larger pack exceeded the connector size limit; GitHub's configured IKANISA1/Mobio URL returned not found. No verified upstream HEAD, current branch protections, complete Flutter dependency graph or fresh full-repository build is claimed.

Use the actual complete upstream checkout on an isolated review branch. Reconcile the complete Increment04 overlay first. Review `DELTA_MANIFEST.json`. Default `apply_increment05.py --repo ... --bundle ...` checks all before/after hashes without writing. Add `--apply` only after review. The applier refuses drift, unrelated existing new files, symlinks, path traversal and Git metadata edits. It stages replacements and rechecks before writing; replacement is atomic PER FILE, not an all-files filesystem transaction. Do not run concurrent editors/writers during application. Checksums prove matching bytes, not package authenticity.

## Database and coordinated client cutover

1. Preserve a verified recovery point and rehearse against a disposable full-schema PostgreSQL17 database. Use synthetic users and protected sanitized copies, not production wallets. Original September verified-identity functions and bodies01–07 are prerequisites.
2. Run the existing `python3 scripts/ci/prepare_hardening_migrations.py` plan. On a configured supported Supabase CLI, its `--write` option calls `supabase migration new` and fills the reviewed bodies. No timestamped migration history has been fabricated or applied in this delivery. Do not directly rerun CREATE bodies on an already migrated database.
3. Execute all genuine generated migrations in order on both clean and forward-upgrade staging databases. Run the existing assertions, then `increment05_catalog_assertions.sql`. Catalogue probes validate grants and structure; they do NOT prove authorization or money behavior by themselves.
4. Before enabling the new wallet UI, reconcile old-client in-flight/uncertain wallet operations and ownerless v1 pending keys against the existing ledger. Client checks cannot recover legacy keys lost before upgrade. Do not erase these keys as a workaround. A controlled migration/support decision is still required.
5. Coordinate migration09, supported app versions and operational maintenance. Old clients calling `rpc_transfer_tokens` or `rpc_redeem_wallet_tokens` directly fail closed after09. Do not leave those direct grants enabled just for compatibility. Stage the journal-compatible client and test the minimum-version/maintenance rollout policy before any live cutover.
6. Coordinate body08, new `verify-otp`, current verified-phone resolver and Flutter admin session service. Existing admin sessions without a lease must reauthenticate. A registry failure may consume the OTP without returning credentials; request a new OTP, never fall back to old sessions.
7. Defaults (15-minute idle, 8-hour absolute, 5-minute recent-auth window) are engineering proposals requiring owner approval. `require_recent_admin_session()` is supplied, but its mapping into EVERY high-impact privileged routine has NOT been completed. Delegated admin permissions and the complete transitive RLS/RPC audit remain open.
8. Never drop the journal or restore broad old grants as an unreviewed rollback. Keep history, disable affected actions, and use a tested compatible client or forward repair. Pending/cancelled/acknowledged record retention and account-deletion exceptions require M069/M070 design.

## Required real acceptance matrix — not executed here

### Admin and account
- Service-only lease creation; deny anon/ordinary callers even with guessed owner/session/OTP IDs.
- Real Auth session, consumed correct-purpose OTP, authoritative phone and current allowlist must agree. Concurrent OTP claims register at most one intended lease; registry outage returns no credentials.
- Revocation, Auth-session deletion, banning, deactivation, provider change, idle/absolute expiry and request replay deny protected DB and Edge actions. Test actual every shipped administrative RPC, not only a helper.
- Status polling does not extend idle. Touch cannot revive expired/revoked state. Browser reload, blur/resume, token refresh, A→B→A and server/client clock changes behave correctly.
- Failed SDK restore cannot accept a prior user. Offline logout, disk write/read failure, late login/SDK completion, process termination and restart leave no usable prior-account access or exposed view.
- Complete native secure storage migration, least privilege and recent-auth enforcement remain separate.

### Wallet (real original financial functions; no financial double)
- Owner A cannot prepare/execute/status/close B's operation. Direct legacy mutations are denied to clients.
- Two concurrent identical preparations return one unresolved operation; conflicting requests cannot create a second slot. Test different browser tabs, app restarts and lost local storage.
- Response loss before/after preparation, execution commit and acknowledgement preserves discoverable status. Retrying a committed UUID returns its existing receipt and creates no new debit/credit.
- Cancel vs execute and simultaneous execute interleavings conserve the original ledger. A cancellation after commit is rejected; a refund is not simulated by closing a journal entry.
- Changed receiving identity, amount/currency/precision boundaries, legacy key preplay and wrong receipt binding fail before transaction completion.
- Failed local pointer persistence never triggers execution. Committed receipt plus failed local cleanup is not reported as a failed transfer. Old v1 unresolved requests need explicit reconciliation.
- Modal input, recipient confirmation, receipt and pending-view content disappear after account change. New English error/recovery copy still needs promised-language review and accessibility/golden acceptance.

### Startup
- Release/profile runs on low-cost devices: airplane mode, DNS stall, captive portal, optional provider outage, slow local preferences, restored sessions and revoked sessions. Record first usable frame, error budgets and memory; timeout constants are not performance evidence.
- A timed-out singleton is not initialized twice; its late completion cannot mount a protected app. Verify theme and push ownership, error view, analytics consent and privacy-safe crash reporting on actual SDKs.

## Commands

```sh
# Source-only preparation plan; does not invoke production
python3 scripts/ci/prepare_hardening_migrations.py
# Portable tests (requires the listed tools; missing required tooling is not PASS)
bash scripts/ci/run_hardening_tests.sh
# Native client/SDK lanes on the actual pinned toolchain
flutter analyze
flutter test test/increment05/session_and_wallet_test.dart
# Run the repository's full Flutter tests and native Deno workflow, not only the new file.
# Read-only local database catalogue probe after real migrations (explicit test DB only)
python3 scripts/qa/check_increment05_catalog.py --dsn postgresql://127.0.0.1:54322/mobio_test_increment05
```

The Deno admin-session test was updated from paged directory/email-alias expectations to canonical owner/lease contracts. It uses the real Deno SDK with explicitly mocked HTTP; its test source is delivered but not executed in this environment. New Node tests use explicit external SDK module/client substitutes. SQL bodies and Dart changes have not been executed by PostgreSQL or compiled by Flutter/Dart here.

## Receipt export contract

Use three UTF-8 CSV files with EXACT headers. Amounts are positive integer minor units; adapters must establish the correct currency exponent. No FX conversion or invented provider format is performed.

```
operator.csv: operator,merchant,transaction_ref,amount_minor,currency,occurred_at
receipts.csv: receipt_id,operator,merchant,transaction_ref,amount_minor,currency,state,invoice_id
credits.csv: credit_id,invoice_id,operator,merchant,transaction_ref,amount_minor,currency
```

Map real source statuses explicitly to admitted/processing/review/rejected/credited. Export an agreed in-scope merchant/period and consistent as-of snapshot for ALL files. Approve that operator data is genuine and complete independently. Duplicate record IDs or malformed rows reject the input; duplicate references produce review exceptions. No amount-only/time-window fallback is allowed.

```sh
python3 scripts/operations/reconcile_receipts.py \
  --operator /secure/operator.csv --receipts /secure/receipts.csv \
  --credits /secure/credits.csv --as-of 2026-09-28T09:00:00Z \
  --output /secure/new-reconciliation-review
```

Exit0 means comparison completed without flagged exceptions, not payment authenticity or release approval. Exit1 means review exceptions. Exit2 means invalid/unavailable input; no financial action is ever performed. Protect generated JSON references. Actual extraction/adapters, scheduling, dashboards, exception ownership and operator-record acceptance remain open under M023.
