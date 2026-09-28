# Forward database hardening — integration required

These three versioned SQL **bodies** are complete candidate forward changes, not applied migrations. No historical migration was edited. The implementation environment had no usable Supabase CLI or PostgreSQL server; source review and application fixtures do not prove SQL execution.

## Prepare on a clean review branch

1. Apply the supplied source patch to the matching baseline (or reconcile differing files first).
2. Install the supported Supabase CLI and inspect `supabase migration new --help`.
3. Run `python3 scripts/ci/prepare_hardening_migrations.py` for the read-only plan.
4. After reviewing bodies and their checksums, run `python3 scripts/ci/prepare_hardening_migrations.py --write`. It invokes only `supabase migration new`, fills new empty files and preserves existing migration files. It does **not** link, push, reset or execute SQL.
5. Run the same script with `--check`, then review and commit the generated migrations together with the Edge changes. The main CI backend lane and go/no-go helper deliberately block while these files are missing.
6. Rehearse the complete migration chain and a sanitized forward-upgrade copy in isolation. Run `post_install_assertions.sql` there. Validate actual PostgREST roles, Auth and transactional behavior; catalog assertions alone are not acceptance.

Do not invent timestamp filenames, modify an applied migration or deploy the new OTP handler before its verified-phone lookup RPC exists. An interrupted preparer leaves created files visible; inspect them rather than deleting history or forcing overwrite. A stale `.mobio-hardening-prepare.lock` requires manual inspection.

## Behavior and compatibility

**01 / Booking write authority.** Clients lose all direct booking mutation privileges, including column-level grants. Existing SELECT policies remain. Agency and consumer screens must use the existing authorized server operations; any direct-write agency path will be blocked. No new refund, cancellation or inventory sweeper is supplied here.

**02 / Verified phone authority.** The authoritative lookup is `auth.users.phone` with a confirmed, nonanonymous, available account. Editable profile aliases no longer select login or phone-discovery recipients. Confirmed digits-only and leading-plus Auth representations are recognized without guessing a country. Duplicate/unconfirmed legacy records fail closed and need an approved recovery process. Identity fields cannot be modified through ordinary client requests or client-invoked profile RPCs. A verified phone-change workflow is not implemented by this patch; current attempts to mutate those fields will be rejected. Existing session issuance and real Auth collision behavior require rehearsal.

**03 / Subscription receipts.** Automatic allocation is off by default in both Edge configuration and the new per-collector policy table. Enabling requires an approved collector, nonempty exact merchant and sender lists, an explicit acceptance-record reference, and the supported evidence policy. No example merchant or live acceptance record is seeded. The only proposed automatic template is the English MTN-style received-payment fixture with one explicit amount/currency, invoice reference, provider transaction reference and merchant code. It is NOT a certified operator format. Other languages/formats, ambiguous/nonpayment messages and absent fields are retained as unmatched for review; they cannot activate an entitlement. Confirm actual operator messages before enabling. Different invoices serialize by profile/vehicle entitlement; duplicate invoices remain idempotent. Real two-session READ COMMITTED, serialization failure/retry and duplicate-receipt tests remain required.

## Required adversarial rehearsal

Use only synthetic users, collectors, invoices and amounts in an isolated environment. Record exact schema and application revisions.

- Passenger direct REST attempts to set paid/confirmed, seats, price, route, expiry and ownership are denied; legitimate hold/confirmation/cancellation still works through authorized operations.
- Updating profile verified aliases, identity timestamps or IDs is denied for real authenticated clients and client-invoked RPCs; editable nonauthority profile fields still work.
- Alias spoofing, banned/anonymous/unconfirmed and duplicate Auth phone records cannot select or reassign another identity. Existing-user login must not call phone reassignment. Verify actual new-user races and recovery behavior.
- `anon` and `authenticated` cannot execute internal lookup/allocation functions or read policy records.
- Negative classification, malformed amounts, absent provider/invoice IDs, wrong merchant/currency, unsupported sender/template, expired/revoked collector and missing acceptance record produce no credit.
- Replaying one provider reference on the same invoice is idempotent; another invoice cannot consume it. Two concurrent renewals retain both paid durations; record transaction isolation and retry outcomes.
- Fail between receipt write, invoice update and activation; verify atomic rollback. Confirm out-of-order offline receipts and lost acknowledgements do not cause silent false success.

Known residual limits: parsing remains synchronous before durable intake; the collector still needs its own transactional queue, minimization and signing work. A reviewed receipt does not itself prove operator settlement. The institutional collection and data-handling approvals remain external prerequisites.
