# Mobio hardening — implementation increment 01
**Delivery date: 28 September 2026**

## What this delivery is

This is a real source-code implementation increment, not a repeat audit or a production release. It contains **46 changed source/supporting files (21 modified and 25 added)**, an applicable Git patch, SHA-256 change manifest, reproducible regression sources, execution logs and an updated **95-task CSV/JSON status register**. Twenty backlog items have implementation or supporting work; **none is certified complete for production**.

The source baseline was reconstructed from all **2,076 files in the supplied Drive Git index**. A local synthetic Git commit exists solely to construct and verify the patch; it is not an independently verified remote branch HEAD. The patch was applied to a separate clean worktree of that reconstructed baseline, and all 46 resulting file hashes matched the manifest.

The Google Drive app allowed new files but rejected replacement of an original source file with `403 appNotAuthorizedToFile`. Therefore this delivery is versioned under `Mobio_Implementation_2026-09-28` in the requested Mobio folder. **The original source files were not replaced, and no production deployment was performed.** No signing credentials, fonts, database contents, raw biometric captures or binary builds are included in this package. Existing unchanged project assets remain in the original repository.

## Implemented changes

### Verified identity and profile authority — M003/M004

The OTP handler now resolves a phone through a service-only authoritative Auth lookup and then reads a profile only by the validated Auth ID. Editable `profiles.phone` / `whatsapp_e164` aliases and newest-created ordering no longer choose the login identity. Existing-user login changes the random login password and appropriate metadata, but **does not reassign or confirm an existing phone/email**. The returned session is checked against the resolved identity. New-account creation retains the OTP-verified provisioning path.

A staged database body supplies the verified-phone lookup and a trigger protecting identity fields, including calls made through client-invoked security-definer profile RPCs. Phone-based BioPay discovery is changed to the same authoritative identity source, while receiving-method privacy/grants are preserved. Ambiguous, unconfirmed, anonymous, banned or inconsistent identities fail closed. This introduces a deliberate compatibility boundary: verified phone-change and historical alias recovery still require an approved workflow; the patch does not silently rebind existing accounts.

### Booking authority containment — M015

A staged forward body removes direct client INSERT/UPDATE/DELETE/TRUNCATE authority from `bus_bookings`, including separately granted column INSERT/UPDATE privileges. It preserves existing reads and rejects residual effective client write grants. Trusted authorized server operations remain the intended write path. Direct-write agency screens will also be blocked and must be rehearsed through their authorized RPCs before deployment. Seat expiry, cancellation/refunds and all receipt-binding defects are not claimed fixed by this containment.

### SMS evidence and subscription allocation — M016/M019/M020/M031

The parser no longer turns malformed signs/fractions/identifiers or out-of-range confidence into plausible payment evidence. Automatic allocation defaults to disabled. Eligibility requires a configured sender/merchant, supported raw received-payment wording and corroborated exact amount/currency, invoice reference and provider transaction reference; model confidence alone is insufficient.

The signed collector handler persists weak/unproven messages as unmatched before acknowledging them, reads back their durable state, preserves previously matched receipts on retries and returns a failure when persistence/readback fails. It retains the registered collector signature/replay/revocation checks. The two legacy shared-secret ingestion endpoints now return a controlled **410** response.

A third staged SQL body adds a private per-collector default-off policy with an acceptance-record requirement, exact invoice/merchant/amount/time binding, unique provider-reference handling and atomic receipt/invoice/activation operations. Different renewal invoices lock the shared profile/vehicle entitlement before extending periods. **These SQL changes were not executed here.** No live merchant, operator format or acceptance record is invented or enabled.

The single English MTN-style receipt template used in tests is a **synthetic engineering fixture, not an operator-certified payment format**. Unsupported/ambiguous messages remain for review. Parsing is still synchronous before durable admission, so the separate collector queue, minimization, asynchronous intake and reconciliation tasks remain open.

### Provider budgets and OTP logging — M012/M091

New bounded fetch handling covers headers and response bodies, request deadlines, inherited cancellation and maximum response sizes. It is used by OTP delivery, AI parsing and maps. Selected Supabase calls have finite request budgets. Provider errors are sanitized. OTP dry-run is permitted only in explicitly isolated development/test mode and is rejected for deployment-like environments; its logs contain neither the OTP nor the full phone.

This does **not** implement durable cross-instance rate/cost quotas, full circuit-breaker behavior or production provider acceptance. There are no automatic retries of a completed financial mutation.

### NFC and Android — M044/M047

A pure Kotlin policy now binds advertisements to the current process instance and both wall and monotonic deadlines, rejects malformed/expired setup, caps the engineering advertisement window at five minutes, and validates the exact SELECT APDU structure. The native service clears stale material and returns no payload after expiry, wall-clock rollback, elapsed-time reset or process restart. Native status and the Dart capability check respect expiry. The consumer Android target SDK is now **36**.

Twenty pure JVM scenarios passed. This is **not** an Android framework build, physical-reader test or proof of ordinary logout/account-switch cleanup; the latter still requires the account-lifecycle workstream. No signed APK/AAB was produced.

### Private face inference serving — M042

The private Python HTTP adapter now uses a bounded worker pool and admission semaphore, finite absolute request budgets, strict size/framing checks, sanitized structured errors, explicit connection closure and draining behavior. Real model/runtime/hash/shape initialization is still required before binding in the normal entry point. The Dockerfile includes the shared protocol module.

Sixteen real local HTTP/socket tests passed using an **explicit fake model**. The actual pinned Linux image/model, recognition accuracy, gallery calibration, capacity and deployment shutdown behavior were not tested. Face remains an optional, gated recipient-discovery feature. The approved scope is unchanged: **no AWS fallback, no liveness, no payer biometric authorization, no mandatory extra app review screen, and no claim that dialer launch means payment completion**.

### CI, release truth and reproducible preparation — M074/M075/M077/M081/M082/M090

The action-pin checker parses YAML rather than matching lines. It recognizes quoted/inline values and safe same-repository workflow/action references while rejecting unpinned remote references, malformed/dynamic paths, duplicate mapping keys and symlinks. The integrated readiness script cannot report PASS after required groups are skipped. Play upload evidence must contain one exact current version declaration; version `16` no longer accepts `160`.

A read-only-by-default migration preparer verifies checksums, names and order. With `--write`, it invokes the installed `supabase migration new` command and fills only the new empty files. It never links, resets, pushes or applies SQL. Existing/applied migrations are never overwritten. CI and go/no-go now require the generated reviewed migrations to exist; **the current local installation check correctly returns INCOMPLETE because the CLI is unavailable and those migrations have not been generated**.

Added CI lanes cover the available unit/fixture/HTTP/JVM work, and Node fixtures are outside Deno's automatic test tree. Dependency update coverage now includes face-service npm, inference/CI Python and Docker. Remote CI and protection rules were not executed/configured. The new CI Node pin is 22.23.3, checked against the current official release; the local execution logs explicitly record Node 22.16.0. A complete dependency advisory/toolchain audit remains open.

## Fresh validation performed

| Suite | Passed | Boundary |
|---|---:|---|
| Release gate regression | 29 | Python subprocess fixtures; not Flutter |
| Migration preparer | 12 | Fixture CLI protocol; no real CLI/database |
| Exact version evidence | 8 | Declaration parser, not an upload receipt |
| Pure Edge modules | 66 | Node TypeScript execution with env fixture |
| Actual Edge handler fixtures | 14 | Real handler flow/RSA fixtures, mocked Auth/database |
| NFC policy | 20 | Real Kotlin compilation/JVM scenarios, not Android |
| Private inference HTTP bounds | 16 | Real local sockets, fake model |
| Existing Pages/admin | 69 | Node fixtures |
| Existing face Worker | 7 | Mocked bindings |
| Existing source boundaries | 5 | Python fixtures |
| Existing runtime-defines | 7 | Python fixtures |
| Existing version assets | 7 | Python fixtures |
| **Total passed tests/scenarios** | **260** | **165 new; 95 existing. Not production acceptance.** |

Separately: **65 Python/Bash syntax checks passed**, selected pure modules passed TypeScript 5.8.3 strict checking, the patched source action-pin gate passed, and the full source patch passed application/hash verification. These checks are not added to the 260 test/scenario count.

The original seven-case Android smoke-harness run was attempted repeatedly but exceeded the available execution-call budget during its physical-device *fixture*. Its incomplete log is included and it is **not counted as passed**. No real device was connected. The original smoke test source was left unchanged.

Runtime: Python 3.13.5; Node 22.16.0; Kotlin 1.9.0; Java 21.0.11; selected TypeScript check 5.8.3. No Flutter/Dart, Deno, PostgreSQL, Docker, adb or Xcode execution was available. No signed app, actual remote Auth/database transaction, live operator payment, real face benchmark or production deployment is claimed.

## Integrate and verify

Use a clean review branch of the **matching** source checkout. Preserve unrelated local changes. From the repository root:

```bash
git apply --check /path/to/MOBIO_HARDENING.patch
git apply /path/to/MOBIO_HARDENING.patch
python3 -m pip install -r scripts/ci/requirements.txt
./scripts/ci/run_hardening_tests.sh
python3 scripts/ci/prepare_hardening_migrations.py
```

After reviewing database bodies, use the actual installed CLI to generate migration filenames:

```bash
supabase migration new --help
python3 scripts/ci/prepare_hardening_migrations.py --write
python3 scripts/ci/prepare_hardening_migrations.py --check
```

These commands **prepare files only**. Read `supabase/hardening/2026-09-28/README.md` for deployment order, compatibility and the real adversarial rehearsal matrix. Commit the generated migrations together with their dependent Edge source. Do not deploy the new identity handler before its database lookup exists. Run the full maintained Flutter/Deno/database/native suites and actual provider acceptance in isolated staging; promote only after those results and external gates are accepted.

`changed-files/` contains the exact replacement/addition bytes with original paths. The Git patch is preferred because it checks context and preserves unrelated files. This is a change package, not a standalone complete repository. Original fonts/assets are intentionally not redistributed.

## Remaining release blockers

The public-folder/signing exposure and credential provenance/reset work remain unresolved. Canonical unique member IDs, ordinary logout/FCM ownership, secure native session persistence, booking inventory/receipt/refund completion, the collector's transactional queue/filter/signing/health, account deletion/retention, current privacy/governance/processor records and real signed-platform/provider/operational acceptance remain open. The CSV/JSON register preserves all 95 original tasks, their dependencies, acceptance criteria and source evidence; twenty have work recorded in this increment, with no blanket closure.

The next engineering sequence is: integrate this package; generate/rehearse its SQL; resolve verified-identity migration/recovery and legitimate booking callers; then complete canonical member IDs and account/logout/push ownership. Source integration does not substitute for restricting the original folder or rotating exposed active credentials.

## Reference guidance consulted

These are external implementation references, not evidence that Mobio has passed their requirements:

- Supabase column privileges: https://supabase.com/docs/guides/database/postgres/column-level-security
- Supabase CLI migration commands: https://supabase.com/docs/reference/cli/supabase-migration-new
- GitHub reusable workflows: https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows
- Pinned setup-node v6.3.0 release/commit: https://github.com/actions/setup-node/releases/tag/v6.3.0 ; https://github.com/actions/setup-node/commit/53b83947a5a98c8d113130e565377fae1a50d02f
- Current Node maintenance release index: https://nodejs.org/en/blog/release
- Approved Mobio face-to-USSD scope: existing `docs/product/face-ussd-20260920/` and the supplied specification; it remains controlling for the feature.

## Delivery integrity

`CHANGE_MANIFEST.json` gives all changed-file paths, before/after hashes, patch digest and the reconstructed baseline identity. `VALIDATION_RESULTS.json` gives scope-specific results and limits. `PACKAGE_CHECKSUMS.json` is the digest list for packaged files. The original XLSX audit tracker was not overwritten; the updated CSV/JSON status register is the operative increment record. No remote production acceptance or background work is implied by this delivery.
