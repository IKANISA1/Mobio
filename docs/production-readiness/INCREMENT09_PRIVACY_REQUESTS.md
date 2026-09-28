# Mobio Increment09 — privacy-request integration and acceptance

28 September 2026. Source candidate, not an applied migration or production release.

## 1. What this increment does and does not do

The current profile Delete Account action opens the configured external contact page. This increment adds a verified-user Flutter screen, a caller-scoped Edge gateway and a private SQL request/evidence lifecycle. The original external contact page remains available; anonymous/unverified access continues to use it. The application distinguishes a request receipt, processing, a blocked case, cancellation and recorded completion evidence.

**There is no cross-provider erasure executor in this increment.** Storage objects, SQL business records, vectors, processor data and backups are not deleted by a request or an evidence upload. The service-only fulfilment RPC records separately executed work. Actual provider adapters, complete schema/storage inventory, retention rules and automatic retry/recovery of erasure remain M069–M070 work. The original requirement to avoid a hidden manual-only process is preserved, not marked satisfied by this supervised interim path.

No queue, scheduler, production credentials, folder permissions or financial operation was changed. All earlier admin/wallet/chat/push/native-session cutover conditions remain applicable.

## 2. Integration baseline

Use a complete, reviewed Mobio checkout containing the reconciled Increment01–08 changes. The cumulative overlay is not a standalone repository and does not establish the upstream main commit. Inspect `DELTA_MANIFEST.json`, `SOURCES.json` and the patch before integration. Checksums detect drift, not author authenticity.

```sh
python3 apply_increment09.py --bundle /path/to/Mobio_Increment09_2026-09-28 --repo /path/to/mobio-review
python3 apply_increment09.py --bundle /path/to/Mobio_Increment09_2026-09-28 --repo /path/to/mobio-review --apply
```

The first command is check-only. The second changes reviewed local files after all baseline checks pass. Replacements are atomic per file, not one cross-file transaction. Preserve a clean review branch and reconcile newer edits rather than forcing an overwrite.

## 3. Database and authorization boundaries

`12_privacy_request_workflow.sql` is the twelfth ordered forward source body. Bodies01–11 are unchanged. Generate migration filenames only through the existing preparation workflow and the actual approved Supabase CLI; never pretend that this source filename is an applied migration:

```sh
python3 scripts/ci/prepare_hardening_migrations.py
python3 scripts/ci/prepare_hardening_migrations.py --write --supabase /path/to/approved/supabase
python3 scripts/ci/prepare_hardening_migrations.py --check
```

These commands plan or prepare files, not deploy the database. Inspect the CLI help and run complete clean/forward schema rehearsals on an approved isolated environment. The source requires existing `verified_app_user_id`, `verified_admin_user_id` and `_mobio_is_service_role` helpers. Private tables have RLS enabled and no direct client/service table grants. Privileged RPCs have explicit grants and fixed search paths.

| RPC | Authority | Purpose |
|---|---|---|
| `rpc_privacy_user` | Authenticated, live verified account | Own policy/list/status/request/cancel only; no caller-supplied subject |
| `rpc_privacy_configure` | Service role | Explicit intake/processing policy and approval reference |
| `rpc_privacy_fulfil` | Service role | Revision-checked start/block/evidence/complete recording |
| `rpc_privacy_worklist` | Service role | Bounded 50-case worklist with timestamp/UUID cursor |
| `rpc_privacy_health` | Active verified admin or service role | Aggregated health; no subject identifiers |

Initial intake and processing are **OFF**. Proposed technical defaults are fresh-session age300seconds and three new requests per rolling24hours; these are not statutory periods. They require owner/abuse/availability review. Never set an arbitrary deletion deadline or retention duration merely to enable the feature.

Owner-scoped request admission is serialized. A same-ID/same-notice retry returns the original record, including after cancellation or policy disablement. The database prevents more than one active case per owner. A changed notice with the same ID conflicts. Cancellation is allowed only before `started_at`; blocking an already-started case does not restore cancellation rights. Request IDs are stable during the screen attempt; server ownership and the one-active-case constraint are the restart safety boundary, not an unimplemented local offline outbox.

The new request requires a fresh actual Auth session, not merely a refreshed JWT. Status/list/cancellation require live identity but do not impose the additional fresh-login window. Existing access tokens and session revocation must be tested through real Auth/PostgREST, not the synthetic fixture helpers.

## 4. Edge and Flutter release

Deploy the reviewed `privacy-requests` function together with the accepted database RPC. The function uses only `SUPABASE_URL`, the existing public client key `SUPABASE_ANON_KEY`, and exact browser origins from comma-separated `MOBIO_PRIVACY_ALLOWED_ORIGINS`. An empty origin allowlist permits native requests without an Origin header but denies browser cross-origin access. No wildcard origin is generated.

The config disables platform JWT prechecking for this entrypoint because the gateway forwards the exact caller bearer to PostgREST, which validates it and invokes the live-account check. The gateway itself performs shape checks, not cryptographic JWT authorization. Never substitute a service-role key for the caller. Targeting is fixed to the configured canonical Supabase host and one RPC; redirects, arbitrary URLs, owner IDs and arbitrary SQL are not accepted.

Inputs are bounded to4096bytes; the gateway returns sanitized errors and explicit unknown outcomes when a mutation response cannot be confirmed. The Flutter service captures the bearer and account/session before awaiting network work. Old-account results are rejected. The screen hides or clears its state on account/lifecycle changes and exposes the original contact path when intake is disabled or unavailable.

Read the approved deletion notice at the existing configured page before enabling intake. The configured notice version and page contents must correspond; this increment does not publish or approve that notice. New UI copy is English and still requires promised-language and accessibility acceptance. After the Auth user is actually removed, that user's authenticated status page is no longer available. A verified completion-notice channel/support process remains outstanding; do not add an unauthenticated subject-lookup endpoint as a shortcut.

No native plugin, additional package or dependency upgrade is introduced. Run the repository's normal Flutter analysis/tests/build scripts with the required public `--dart-define` values. The new domain suite is:

```sh
flutter test test/increment09
```

Native session storage and earlier client/database transitions still require their own signed-device acceptance. A source-only hot update must not bypass those requirements.

## 5. Fulfilment is supervised evidence recording, not automated erasure

Before processing, obtain the genuine complete data inventory, approved plan and retention decisions. `rpc_privacy_configure` records the notice version, inventory SHA-256 and approval reference. `rpc_privacy_fulfil(start)` binds the case to that approved inventory and plan hash. Do not label a partial source scan as a complete production inventory.

Every fulfilment action has an immutable UUID, expected case revision, fixed action/payload and operator/change reference. A retry with the same action ID and input is idempotent; changed input conflicts. A new action must use the current revision. Evidence corrections append a later revision; they do not overwrite prior attestations. Cancellation and start serialize on the case row, so a completed start prevents later cancellation.

The current coverage categories are an implementation checklist, not proof that every production store has been inventoried:

| Category | Required evidence scope |
|---|---|
| `sessions` | Auth sessions/revocation, current-session authorization and affected client lifecycle |
| `auth` | Removed Auth user and relevant identity records |
| `profile_and_activity` | Actual profile, discovery, trip, chat and activity relations from the full schema |
| `financial_records` | Approved treatment of wallet, invoice, booking and receipt records, including necessary exceptions |
| `delivery_journals` | SMS/chat/wallet/push operations, bindings, jobs and retained recovery identifiers |
| `storage` | Actual owned objects, derived copies, signed access and caches—not only SQL object metadata |
| `face_vectors` | Enabled vector/model/provider stores and deferred cleanup; justified N/A only where evidenced |
| `processors` | Actual analytics, messaging, logs and subprocessors in the approved inventory |
| `backups` | Retention expiry and restoration/replay safeguards; do not claim immediate erasure of immutable backups |
| `privacy_case_records` | This workflow's subject/session links, request/action/evidence records and external manifests |

Auth and sessions must be recorded as deleted, not retained or not-applicable. **The privacy case/audit records remain identifiable in this implementation**, so `privacy_case_records` must carry a documented retained outcome, finite future review/expiry date and basis reference. This makes accepted closure `completed_with_retention`; it cannot honestly be represented as total erasure while those records remain. There is no automated expiry/purge implementation. The health RPC reports due exception reviews; a responsible process must act on them.

Other retained categories also require a future finite date and basis reference. Unknown provider state is a blocker, not `not_applicable`. The source blocks completion without all ten current evidence categories, the manifest hash and direct checks that the actual Auth user and sessions are absent. Those two live probes do not independently prove the truth of the other provider attestations. Cross-store verification remains a required integration step.

## 6. Local evidence manifest verifier

`scripts/privacy/verify_completion_manifest.py` is read-only with respect to input evidence and the application. It validates bounded JSON, exact IDs/categories/outcomes, timezone-bearing dates, local file SHA-256 hashes and retention bindings. It rejects duplicate JSON keys, excessive nesting, nonfinite numbers, symlinks, traversal, missing/oversized files and unknown categories. Output is created exclusively with restricted permissions.

```sh
python3 scripts/privacy/verify_completion_manifest.py /restricted/case/manifest.json --output /restricted/case/verification-new.json
```

A manifest has exactly `schema_version:1`, `request_id`, `subject_id`, `notice_version`, `inventory_sha256`, `plan_sha256`, `generated_at` and a ten-item `receipts` array. Each receipt has `category`, `outcome`, relative `evidence_file`, `sha256`, `retention_until` and `basis_reference`. Retention fields are null when inapplicable. Each evidence file is a JSON envelope binding the same request, subject, category, outcome and retention fields, with `observed_at` and `verification_mode` (`operator_attestation` or `provider_probe_record`). Additional provider-specific evidence may live in that envelope, subject to minimization.

Do not put live evidence in this anyone-editable source folder. Store it in the approved restricted evidence system. A hash proves integrity relative to the supplied file, not that the supplied claim is true. The verifier explicitly returns `provider_deletion_independently_verified:false` and `database_case_changed:false`. The service RPC does not fetch that file or rerun the local verifier automatically; the operator/controller must bind the verified artifact to the recorded action and keep that evidence auditable. Fake or missing proof must never be replaced with generated production receipts.

## 7. Executable local checks and authored acceptance

```sh
bash scripts/ci/run_privacy_checks.sh
python3 scripts/qa/test_privacy_postgres.py --check-tools
```

The first command executes Node gateway fixtures, Python evidence validation, runner guards and source-applier tests. These do not execute PostgreSQL or Flutter. The SQL runner requires an actual approved official `postgres@sha256:<digest>` in `MOBIO_PRIVACY_POSTGRES_IMAGE`; no digest is fabricated. It starts an empty, network-disabled container with synthetic Auth helpers and no external DSN or host mounts. Docker and PostgreSQL were unavailable in this working environment, so its SQL cases have NOT executed.

After tooling is available, run the component suite, then separately the complete schema and real-role acceptance. Required cases include parallel same/different-ID admission, another user's UUID, stale session/notice, request/cancel/start races, service-role grants, CAS conflicts, evidence corrections, missing proof, false deletion attestations while Auth remains, finite retention, privacy-case retention, request lifecycle after account deletion, and restore/replay handling. Test full Flutter screen/service/account switching, browser CORS and native lifecycle against that accepted backend. Source assertions are not substitutes for these scenarios.

## 8. Deployment and rollback decision

Keep intake off until the notice, real schema/auth integration, support ownership and retention plan are accepted. Keep processing recording off until the complete inventory and fulfilment procedure are approved. Enable only through a controlled service-owned change with an authentic reference. A paused intake must not hide existing case status. A paused fulfilment workflow must not prevent an operator from recording a blocker.

For rollback, disable admission/processing before retiring the new UI/API; preserve cases and evidence, keep the existing contact channel available and reconcile any in-flight requests. Do not drop retained tables or restore broad grants to make an older client work. Rehearse compatibility and restoration before production; no rollback or production execution was performed here.
