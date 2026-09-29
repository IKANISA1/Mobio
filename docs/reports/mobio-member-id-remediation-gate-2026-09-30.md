# Member ID remediation gate — 30 September 2026

M005 requires six-digit IDs that remain bound to the right account. The earlier candidate body 04 silently nulled malformed IDs and all but the oldest owner of each duplicate, then generated replacements. Member IDs also appear in wallet, subscription and payment references, so an automatic reassignment could sever an external/account reference without a reviewed map.

## Changes and reason

| File | Reason |
| --- | --- |
| `supabase/hardening/2026-09-28/04_canonical_member_id.sql`, matching generated migration and `manifest.json` | Lock profile writers during preflight and installation. Abort before any change when a historical nonnull ID is malformed or duplicated; preserve account UUIDs and current IDs for controlled remediation. Retain automatic assignment only for null IDs, the unique six-digit index and the server allocation trigger. The body, generated candidate and manifest SHA-256 now match. This review-branch candidate has not been applied to a hosted database. |
| `supabase/hardening/2026-09-28/member_id_preflight.sql`, bundle `README.md` | Provide restricted read-only counts and affected account UUIDs for a data owner to review before a representative forward upgrade. The SQL outputs no phone or secret and makes no changes; its account-level output is still private evidence. Explain that financial and external references need an approved account-level correction before retrying body 04. |
| `scripts/qa/test_member_id_migration.py`, `.github/workflows/ci.yml` | Rehearse duplicate, malformed, valid, null and client-supplied IDs in an isolated pinned official PostgreSQL 17 image. Make the fail-closed test a mandatory CI step. |

## Verification

- **12 isolated PostgreSQL 17 checks passed:** the read-only preflight detected a duplicate, duplicate and malformed fixtures stopped with `MEMBER_ID_REMEDIATION_REQUIRED` and preserved values, a clean fixture retained both valid IDs and allocated the null ID, a caller-supplied invalid ID was replaced, concurrent client inserts received distinct IDs, and a later collision was rejected by the unique index.
- The reviewed body and generated migration have the same SHA-256, `ee3d38d442b16584b61900cec1ca1f95d58b3066282a1ea2d57e77fe4df9b894`; `prepare_hardening_migrations.py --check` passed.
- The pinned Supabase CLI 2.84.2 clean PostgreSQL 17 rehearsal passed **119 migrations**, the post-install catalog/data assertions and the full set of current local SQL suites after this change. The migration preparation suite passed 12 tests; the production-gate suite passed 35. Repository structure, secret-pattern, whitespace and Actions-pin checks passed.
- Dart analysis exited 0 with the existing 92 information-level findings. The pinned full Flutter suite finished with 969 passing tests and 152 reference-golden failures; these visual baselines remain an M076 release gate. The required Android appbundle release script stopped before compilation because all four public build values are absent locally; no artifact was produced.

## Acceptance still needed

No deployed duplicate inventory or approved remapping exists in this workspace. The data owner must run the preflight on a sanitized representative forward-upgrade copy, reconcile each affected account UUID and all financial/external references, approve and execute any correction with an audit trail, then rerun body 04 and concurrent allocation/recipient lookup checks. The `MEMBER_ID_REMEDIATION_REQUIRED` failure is an intentional release stop, not a completed migration. M005, M078/M079 and G01 remain open; this candidate has no hosted or live-user acceptance.
