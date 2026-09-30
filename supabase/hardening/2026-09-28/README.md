# Forward database hardening — integration required

These twelve versioned SQL **bodies** have matching candidate migrations in this review branch. A clean disposable PostgreSQL 17 replay has passed locally; no hosted database application or representative forward-upgrade acceptance is claimed. Review the [manifest](manifest.json) and [execution report](../../../docs/reports/mobio-production-readiness-execution-2026-09-30.md) for exact source and test scope.

## Prepare on a clean review branch

1. Apply the supplied source patch to the matching baseline (or reconcile differing files first).
2. Install the supported Supabase CLI and inspect `supabase migration new --help`.
3. Run `python3 scripts/ci/prepare_hardening_migrations.py` for the read-only plan.
4. After reviewing bodies and their checksums, run `python3 scripts/ci/prepare_hardening_migrations.py --write`. It invokes only `supabase migration new`, fills new empty files and preserves existing migration files. It does **not** link, push, reset or execute SQL.
5. Run the same script with `--check`, then review and commit the generated migrations together with the Edge changes. The main CI backend lane and go/no-go helper deliberately block while these files are missing.
6. Rehearse the complete migration chain and a sanitized forward-upgrade copy in isolation. Run `post_install_assertions.sql` there. Validate actual PostgREST roles, Auth and transactional behavior; catalog assertions alone are not acceptance.

Do not invent timestamp filenames, modify a migration already applied to a persistent environment, or deploy the new OTP handler before its verified-phone lookup RPC exists. An interrupted preparer leaves created files visible; inspect them rather than deleting history or forcing overwrite. A stale `.mobio-hardening-prepare.lock` requires manual inspection.

## Behavior and compatibility

**01 / Booking write authority.** Clients lose all direct booking mutation privileges, including column-level grants. Existing SELECT policies remain. Agency and consumer screens must use the existing authorized server operations; any direct-write agency path will be blocked. No new refund, cancellation or inventory sweeper is supplied here.

**02 / Verified phone authority.** The authoritative lookup is `auth.users.phone` with a confirmed, nonanonymous, available account. Editable profile aliases no longer select login or phone-discovery recipients. Confirmed digits-only and leading-plus Auth representations are recognized without guessing a country. Duplicate/unconfirmed legacy records fail closed and need an approved recovery process. Identity fields cannot be modified through ordinary client requests or client-invoked profile RPCs. A verified phone-change workflow is not implemented by this patch; current attempts to mutate those fields will be rejected. Existing session issuance and real Auth collision behavior require rehearsal.

**03 / Subscription receipts.** Automatic allocation is off by default in both Edge configuration and the new per-collector policy table. Enabling requires an approved collector, nonempty exact merchant and sender lists, an explicit acceptance-record reference, and the supported evidence policy. No example merchant or live acceptance record is seeded. The only proposed automatic template is the English MTN-style received-payment fixture with one explicit amount/currency, invoice reference, provider transaction reference and merchant code. It is NOT a certified operator format. Other languages/formats, ambiguous/nonpayment messages and absent fields are retained as unmatched for review; they cannot activate an entitlement. Confirm actual operator messages before enabling. Different invoices serialize by profile/vehicle entitlement; duplicate invoices remain idempotent. Real two-session READ COMMITTED, serialization failure/retry and duplicate-receipt tests remain required.


**04 / Canonical member IDs.** The candidate now locks the profile table and stops with `MEMBER_ID_REMEDIATION_REQUIRED` if any existing nonnull ID is malformed or duplicated. It does not silently reassign a historical public identifier. Run the restricted [read-only preflight](member_id_preflight.sql), review affected account UUIDs and financial/external references, approve and execute a separately controlled account-level correction, then retry body 04. Null IDs receive new server-managed six-digit values. The allocation trigger and unique constraint protect subsequent writes; ordinary clients cannot choose or mutate the identifier. Wallet recipient lookup uses exact canonical equality rather than stripping characters and selecting an arbitrary first match.

**05 / Transport hold and receipt integrity.** Equivalent active seat-hold retries are idempotent instead of consuming inventory twice. Expired holds restore inventory durably. Confirmation binds a provider/reference pair to exactly one booking before inventory is confirmed, and cross-booking receipt reuse is rejected. A service-only expiry sweeper entry point is provided but is not scheduled automatically.

**06 / Bounded driver discovery.** Nearby discovery requires a verified application user, excludes stale location heartbeats, limits results to ten kilometres and fifty rows, and removes global direct online-location reads for ordinary authenticated users. Direct table reads are reduced to the caller's own row or platform-admin access; the bounded RPC is the discovery interface.

## Required adversarial rehearsal

Use only synthetic users, collectors, invoices and amounts in an isolated environment. Record exact schema and application revisions.

- Passenger direct REST attempts to set paid/confirmed, seats, price, route, expiry and ownership are denied; legitimate hold/confirmation/cancellation still works through authorized operations.
- Updating profile verified aliases, identity timestamps or IDs is denied for real authenticated clients and client-invoked RPCs; editable nonauthority profile fields still work.
- Alias spoofing, banned/anonymous/unconfirmed and duplicate Auth phone records cannot select or reassign another identity. Existing-user login must not call phone reassignment. Verify actual new-user races and recovery behavior.
- `anon` and `authenticated` cannot execute internal lookup/allocation functions or read policy records.
- Negative classification, malformed amounts, absent provider/invoice IDs, wrong merchant/currency, unsupported sender/template, expired/revoked collector and missing acceptance record produce no credit.
- Replaying one provider reference on the same invoice is idempotent; another invoice cannot consume it. Two concurrent renewals retain both paid durations; record transaction isolation and retry outcomes.
- Fail between receipt write, invoice update and activation; verify atomic rollback. Confirm out-of-order offline receipts and lost acknowledgements do not cause silent false success.

**07 / Durable SMS admission and worker.** The signed endpoint commits a complete batch through `rpc_admit_momobio_sms_batch` before returning receipt acknowledgements. It does not invoke a model or allocate money. The private intake table provides deduplication, capacity backpressure, leases, retry state and review. A separately authenticated worker claims one job, intersects Edge and per-collector allowlists, and calls the original strict allocator only inside lease-fenced SQL completion. Processing is OFF by default; policy and actual operation require acceptance. See `docs/production-readiness/INCREMENT04_SMS_INTAKE.md` for staged integration and remaining gates.

Known residual limits: the clean full-schema replay is local evidence only. Representative forward-upgrade data, real Auth, collector-to-worker financial allocation and Android-device acceptance still require their separate checks. Retention and audited review/replay need operator-approved workflows; this increment never automatically purges pending/review payloads or automatically retries manual-review records. The institutional collection and data-handling approvals remain external prerequisites.
