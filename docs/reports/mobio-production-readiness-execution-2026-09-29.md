# Mobio production-readiness execution — 29 September 2026

This record follows the [95-task register](mobio-production-readiness-remaining-tasks-2026-09-29.md). It records local work and its evidence boundary. No task or release gate is marked production-accepted by this run.

## Correction found by actual PostgreSQL execution

The initially imported `12_privacy_request_workflow.sql` failed during `rpc_privacy_fulfil` with PostgreSQL `column reference "outcome" is ambiguous`. The PL/pgSQL function declares an `outcome` variable and had two unqualified references to the `privacy_current_evidence` result columns. Both predicates now qualify `e.outcome`; the due-retention predicate also qualifies `e.retention_until`. The ordered hardening manifest was updated to the corrected body SHA-256 `ef252a85845524ab2252df2fcf67391eb9f0b3e42b4d37248b5b91fae7c446ff`. The immutable Drive snapshot was not edited.

This corrects an executable blocker in the M069/M070 privacy fulfilment path. It does **not** implement provider erasure, set retention policy, install the migration, or establish full-schema/live Auth acceptance. Privacy intake and processing must remain disabled until the wider criteria pass.

## Local checks performed

| Check | Result | Evidence boundary |
| --- | --- | --- |
| PostgreSQL 17 chat body 10 component runner | 27 checks passed | Synthetic Auth/Plus/trigger prerequisites; not full-schema or provider acceptance. |
| PostgreSQL 17 push body 11 component runner | 47 checks passed | Synthetic prerequisites; not actual Firebase/APNs delivery. |
| PostgreSQL 17 privacy body 12 component runner | Initially failed on ambiguous `outcome`; after correction, 28 checks passed | Synthetic Auth prerequisites; not cross-store deletion or hosted acceptance. |
| `bash scripts/ci/run_privacy_checks.sh` | 70 Node gateway fixtures, 40 evidence tests, 10 runner guards, 11 applier tests passed | Local gateway/evidence/tooling only. |
| Identity lifecycle and hardening-preparation unit suites | 22 and 12 tests passed | Source-contract and preparer behavior; no migration installation. |
| Hardening migration plan | All 12 body hashes validated; all 12 `installed` fields are null | Forward source exists; no applied migration history was demonstrated. |
| `dart analyze` with Flutter 3.44.3 / Dart 3.12.2 | Exit 0; 92 info-level lint findings | No analyzer error; lints remain. |
| Full `flutter test --reporter compact` with Flutter 3.44.3 | Exit 1; 969 passed, 152 failed | Reference-golden failures remain; no baseline was regenerated or approved. |
| Android release script, appbundle target | Stopped before compilation | Root `.env` and all four mandatory public build values were absent. No release artifact was produced. |
| Secret-pattern and repository-structure checks | Passed | Neither is a repository-history secret audit or production release acceptance. |

The three PostgreSQL runners used separate, disposable, network-disabled containers from the locally present official `postgres@sha256:f4c66b820c6f974249089d3d16d86a3698eae11e8746eb6644b2271031e91232` image (PostgreSQL server version number 170011). No hosted database, provider, Drive permission, signing identity, or store state was changed.

## Still required before acceptance

- Rehearse the original migrations plus all 12 ordered hardening bodies on a clean PostgreSQL 17/Supabase stack and a sanitized forward-upgrade copy; execute real Auth/PostgREST and full-schema negative/concurrency tests, especially M003, M004, M015, M016, M069 and M070.
- Implement and verify actual cross-store erasure and retention execution for M069/M070. A successful privacy evidence receipt is not deletion.
- Review and resolve the 152 current golden failures against approved design, then rerun the full suite for M076. Do not mass-approve changed images without review.
- Supply the four required public Android build values through the approved private configuration path, then build and inspect a trusted signed artifact. Do not commit `.env` or signing material.
- Close the SMS collector saturation gap, private Storage race verification, live provider/device/operator/store checks, governance decisions and each applicable G01–G10 gate. The [task register](mobio-production-readiness-remaining-tasks-2026-09-29.md) remains the complete scope.
