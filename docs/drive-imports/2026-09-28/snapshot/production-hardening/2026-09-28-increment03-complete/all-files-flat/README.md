# Mobio hardening Increment03 — 28 September 2026

## Delivered

**Actual revised source files and executable tests**, not just a patch generator.
The cumulative tree contains 86 changed source/test/documentation files;
28 are new or revised relative to Increment02. The previously saved
Increment02 was read back from Drive and its 62 source checksums verified before
this continuation. Do not layer the old Increment01 generator over this delivery.

The new work concentrates on the native institutional SMS collector, its actual
Edge intake handler and the corresponding CI/operating workflow. It adds a
versioned local data filter/notice, a bounded SQLite queue, legacy-data preservation,
shared upload locking, retry handling, verified health, safe signing/install checks
and device/operational acceptance specifications. The server no longer sends
unapproved-sender or disabled/unconfigured-allocation bodies to the AI parser.

The cumulative package retains Increment02's identity, member-ID, booking, receipt,
discovery, logout/FCM, NFC, inference and release-gate changes. Those remain subject
to the original task acceptance criteria and are not deployed by this package.

## Validation actually executed

- **330 passing local tests/scenarios**: 254 hardening checks plus 69 existing
  Pages/admin tests and 7 existing Worker tests. All are from this source state,
  not totals accumulated across old reports.
- Actual collector schema/DML exercised using Python SQLite, including reopen,
  row/byte capacity, transactional rollback, deduplication, review retention and
  two concurrent database writers. These are not PostgreSQL or Android tests.
- Production pure Kotlin policy/file-lock code compiled and run, including a
  competing separate JVM process. This is not telephony/WorkManager acceptance.
- Both delivered patches successfully applied to isolated matching baseline files;
  every resulting file matched its delivered SHA-256.
- The required migration-preparation gate correctly remains **INCOMPLETE**: none
  of the six candidate forward SQL bodies has been installed/applied.

See `VALIDATION_RESULTS.json`, `PATCH_VERIFICATION.json` and `evidence/` for exact
scope, commands/output and limitations. Eight additional Android queue-adapter
instrumentation tests and Android-SDK/JUnit upload component tests are present but
were **not run** (the separate pure Kotlin policy/lease harness did run).

## Choose exactly one integration path

1. From a clean reviewed copy matching the supplied audit baseline, use
   `MOBIO_HARDENING_CUMULATIVE_03.patch`.
2. From a clean reviewed copy with the full Increment02 already integrated, use
   `MOBIO_INCREMENT02_TO_03.patch`.

Compare before-checksums in `CHANGE_MANIFEST.json` and preserve unrelated changes.
On a review branch, run `git apply --check /path/to/the-selected.patch`, then
`git apply /path/to/the-selected.patch`. Do not apply both patches. The `changed-files/`
tree is the exact cumulative source overlay, not a complete standalone repository.
The local reconstruction commits recorded here are not original upstream commits.

Run `bash scripts/ci/run_hardening_tests.sh` from the integrated checkout, then
all full-runtime gates. Use the existing preparer and actual Supabase CLI to
create reviewed ordered migration filenames. Rehearse clean/forward upgrades,
Auth/RLS/financial concurrency and post-install assertions on an isolated target
before deploying the dependent Edge functions. Do not edit historical migrations.

The collector operational build now requires approved filter and managed-signing
configuration. Compile/inspect QA artifacts and run the real device matrix before
upgrading a live fleet. Keep uncertain financial features disabled. Installation,
health, receipt admission and actual payment allocation remain different states.

## Still open

Production deployment; actual PostgreSQL/PostgREST/Auth; Deno integration; full
Flutter/golden suites; Android compilation/JUnit/instrumentation; signed Android/iOS;
operator/AI/vector/model acceptance; live credentials and exposed signing-key
remediation; Drive sharing containment; privacy/regulatory approvals; staffed
reconciliation/recovery; full asynchronous receipt intake (M032) and remaining audit
work. `TASK_STATUS_ALL95.json` preserves the 95-task boundary with no production
acceptance claimed. **Mobio is not yet accepted for unrestricted production.**

The Supabase project-list read returned no visible projects on 28 September 2026;
no live SQL/Edge deployment was attempted. This is a connection visibility result,
not a claim that your organization has no projects.

## Delivery status

This package was created in the working container. The session's currently exposed
Drive/Files actions did not provide a usable upload mutation. No Increment03 Drive
upload is claimed; `UPLOAD_STATUS.json` records this separately from implementation
and tests. Existing Drive files, permissions, cloud resources and live accounts were
not modified. Source outputs exclude signing stores and passwords.
