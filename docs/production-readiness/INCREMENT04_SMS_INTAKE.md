# Mobio Increment04 — durable SMS intake

Date: 28 September 2026. Status: implemented source and locally verified handler/guard fixtures; database, Deno and production acceptance **not established**.

## What changed

The latest complete Increment03 package still parsed eligible receipts sequentially during the signed ingestion request. A slow provider could delay storage/acknowledgement for a batch. Increment04 replaces this with a single atomic admission RPC and a separate worker. It preserves the approved face-to-USSD scope, previous backend hardening and the collector's existing signed protocol.

1. `momobio-sms-ingest` verifies the actual collector signature/replay contract, validates the complete envelope batch, calls `rpc_admit_momobio_sms_batch`, and returns HTTP 202 only after a complete, validated database acknowledgement. Acknowledgement means **receipt custody**, not payment, subscription activation or operator settlement. No model or financial allocator is called by this endpoint.
2. `07_durable_sms_intake.sql` provides private intake/configuration/budget tables and five service-only RPCs. Admission is immutable by collector/message hash; mismatched reuse fails. Capacity checks and the whole batch are transactional. Review records are retained when processing/policy/sender approval is absent.
3. `momobio-sms-process` requires its own random server token, rejects browser-origin requests, ignores caller job data and claims one persisted job. Both the global Edge lists and current per-collector policy must approve the sender/merchant before model disclosure.
4. Completion validates the current lease token and deadline before calling the original strict financial allocator. That allocator's work and queue completion are designed to commit in one PostgreSQL transaction. Collector identity is taken from the admitted row, not model output. The existing allocator independently verifies evidence, current collector/policy and invoice/receipt idempotency.
5. Expired claims can be recovered; superseded results are fenced out. Provider failures have bounded retries and sanitized codes. A lost completion response is not interpreted as a failed financial commit or immediately retried inside the same invocation.
6. Health separates storage readiness, queued/review counts, worker recency and automatic-allocation enablement. The trigger script and optional systemd units make scheduling explicit; nothing is installed, enabled or called against a live service by this delivery.

## Baseline and integration order

Use `production-hardening/2026-09-28-increment03-complete/Mobio_Hardening_Increment03_2026-09-28.zip` as the prior **cumulative overlay**. The earlier separately named `Implementation_Increment_03_2026-09-28` contains an authored collector generator and is not a substitute for that complete package. Do not run older generators over newer hardening files.

The new delivery includes an exact Increment03-to-04 delta patch, cumulative source overlay, per-file hashes and a guarded hash-checking applier. These are not a complete Flutter repository or a signed application. Reconcile them with the full source tree in the Mobio folder; the upstream Git commit/live branch was not established.

Run the applier in check-only mode first. Existing modified files must match either the recorded prior bytes or the already-integrated new bytes; new paths must not contain unrelated content. Apply on an isolated review branch, not a production checkout. Review the patch before any database work.

Use the existing `scripts/ci/prepare_hardening_migrations.py` to prepare the seven reviewed bodies. It invokes the installed Supabase CLI to create genuine migration names and never applies SQL. Preserve already-applied bodies 01–06. Do not invent timestamps or reset an existing database. Rehearse both the full clean migration chain and a sanitized forward-upgrade copy. Run `post_install_assertions.sql` and real Auth/PostgREST authorization tests.

For a staged rollout: keep all allocation controls OFF, rehearse body 07, then deploy the new worker and intake handlers/config together. Confirm the schema/RPC version and actual signatures, lost-response retries and storage outages before enabling a scheduler. Old phones remain compatible with `accepted`/`duplicate` receipt results and additional response fields, but this must still be verified on the supported devices.

## Controls and proposed defaults

| Control | Initial setting | Operational meaning |
|---|---:|---|
| Database processing | OFF | Explicit operator approval required |
| Existing per-collector allocation policy | OFF unless separately approved | Approved sender/merchant lists and acceptance record remain necessary |
| Global Edge enable flag/lists | Explicit configuration required | Must agree with the per-collector policy |
| Retained intake rows | 50,000 globally; 10,000 per collector | Includes review/completed rows, not just pending work |
| Retained payload-byte budget | 128 MiB | Raw SMS and sender bytes; not total database/storage overhead |
| Active worker claims | 2 | Global database ceiling |
| Lease | 120 seconds | Provider work should finish well inside it |
| Attempts per job | 5 | Exhausted jobs go to review |
| Parser attempt budget | 120 per fixed UTC hour | Includes failed attempts; not a rolling-window limit |
| Retry delay | 60 seconds, exponential, capped at 1 hour | Rate-limit failures wait at least 5 minutes |

These are engineering starting points, not operator, legal or contractual requirements. Validate actual receipt volume, latency and costs before changing them. The queue's shared database lock favors correctness and bounded volume; benchmark contention and full-table capacity accounting before scaling its limits.

**No automatic purge or automatic review replay is supplied.** Default-off receipts enter review, not a hidden backlog that starts crediting when a switch changes. Capacity eventually fills without an approved retention/reconciliation process. A full queue rejects new admission; the collector must retain and retry. Do not delete queued/review data to bypass a capacity incident. Supervised review/replay must preserve provenance, segregation of duties and the original strict allocation rules. This remains open work.

## Worker scheduling and secrets

The deployed worker reads `MOMO_SMS_WORKER_TOKEN`, `MOMO_AUTO_ALLOCATION_ENABLED`, `MOMO_RECEIPT_ALLOWED_SENDERS`, `MOMO_RECEIVING_MERCHANT_CODES`, and the existing backend/parser settings. The worker token must be independently generated with at least 32 bytes of cryptographically random entropy, encoded as base64url; length validation alone does not prove entropy. Do not reuse a client API key, an enrollment key or another app's secret.

An operator may schedule `scripts/operations/run_sms_intake_worker.py --calls 2` on an approved server after acceptance. It allows only the exact HTTPS hosted Supabase worker path, passes the credential to curl through stdin (not command arguments), disables user curl configuration, forbids redirects and limits time/response size. It emits only classified outcomes. Custom endpoint hosts require separate review rather than weakening this default.

Optional systemd units are under `scripts/operations/systemd/`. They assume a dedicated `mobio-worker` service account, a read-only checkout at `/opt/mobio`, and a protected environment file at `/etc/mobio/sms-intake-worker.env`. The file needs `MOMO_SMS_WORKER_URL` and `MOMO_SMS_WORKER_TOKEN`; provision it through an approved secret manager, outside Drive/source control, with restricted access. Review and install the units explicitly. The timer is once per minute; up to two sequential calls are attempted per activation. A still-running service is not deliberately overlapped. No timer has been enabled in this session.

Observe queued count, oldest queued age, review growth, lease expiries, retry failures, admission-capacity responses and the database worker heartbeat. Heartbeat means the claim endpoint was reached, not successful settlement. Test alert thresholds, provider outages and incident ownership in staging.

## Verification commands and limits

```sh
bash scripts/ci/run_sms_intake_tests.sh
node --experimental-strip-types --test scripts/tests/edge/hardening.test.mjs
python3 scripts/ci/check_github_actions_pinned.py
```

The first command runs actual Node handler/module code with real WebCrypto RSA signatures and explicit database/collector-registry fixtures, plus Python operational guards and SQL/source contract checks. It does **not** execute PostgreSQL, a real Supabase client, Deno deployment or provider calls. The TypeScript compile adapter likewise does not verify the real Supabase SDK types.

For a newly created, empty, isolated local PostgreSQL **17** database named `mobio_intake_test_<suffix>`, configure `MOBIO_INTAKE_TEST_DSN` in the local environment and run:

```sh
python3 scripts/qa/test_sms_intake_postgres.py
```

The runner rejects hosted/non-test databases and missing tooling; requires an empty test database; loads minimal synthetic prerequisites; executes the real body 07; checks rollback, fencing, retry, capacity, policy changes and catalog privileges; then launches eight separate sessions to test the two-worker ceiling. Its financial allocator is an explicitly labeled test double. Even a passing component run does not establish the real allocator/full-schema correctness. Use only a disposable local cluster; the bootstrap may create test roles if absent. This runner has been supplied but not executed here because `psql` is unavailable.

The hosted workflow now includes the new Node/Python fixtures. Actual hosted CI execution, required branch checks, a real PostgreSQL-17 lane, Deno checks and signed-device tests remain unverified. Missing tools are UNAVAILABLE, not PASS.

## Required acceptance before use

Run the original real-allocator negative/duplicate/concurrent-invoice scenarios in the full schema. Test the actual service role plus authenticated, anonymous, revoked and cross-collector identities. Verify that a client timeout after a committed admission leads to the same stored identity and that stale parser callbacks have no financial side effects. Inject faults between allocator writes and queue completion and prove transactional rollback/commit with real PostgreSQL.

Validate approved operator SMS formats, privacy/processor permissions, device updates/offline recovery and actual collector endpoint signatures. Complete the signing/access containment, ledger-to-operator reconciliation, audited manual review/replay, retention/deletion and rollback plans. Keep paid transport, automatic activation and face discovery behind their existing separate release gates. This increment does not add liveness, face-based payer authentication, automatic debits, PIN handling or new face UI.
