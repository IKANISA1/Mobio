# Profile identity authority regression — 30 September 2026

This is source and local database progress for M003/M004/G01. It does not close their real Auth, PostgREST, provider or deployed-service acceptance.

## Added files and reason

| File | Reason |
| --- | --- |
| `supabase/tests/profile_identity_authority.sql` | Exercise the actual replayed `profiles` table, synthetic Auth users/sessions, `authenticated` SQL role, RLS, identity guard trigger and profile/Admin RPCs. Verify effective client/service function grants, an ordinary owner edit, direct and RPC mutation denials for protected fields, cross-owner write denial, and unchanged protected values after each attempted mutation. Every fixture and edit rolls back. |
| `scripts/qa/test_biopay_full_schema.sh` | Make the new authority regression mandatory in the clean full-schema replay and fail the run if it fails. |

## Verification

- The pinned Supabase CLI 2.84.2 replayed **119 migrations** into a disposable PostgreSQL 17 instance. The existing BioPay, security, schema, provider, notification, realtime, permission-expiry, live-identity, Admin-login, driver-discovery and OTP rate-limit suites passed, followed by the new profile identity authority suite. The instance and its synthetic data were removed by the test harness.
- The new suite tested current effective SQL-role privileges and the actual migrated table/function definitions. A verified synthetic owner could change an ordinary profile field. Direct changes to member ID, verified phone, WhatsApp verification timestamp, Admin role, driver flag and organization were denied. An attempted cross-owner update changed zero rows; the profile RPC could not change verified phone or escalate role; the Admin role RPC denied an ordinary user. The final baseline comparison verified that protected values for both synthetic accounts were unchanged.
- The first run found an overly narrow test assumption about two default profile values; the assertion was corrected to compare before/after protected values. The full replay then passed. No production source migration was changed to make the test pass.

## Remaining acceptance

M004 still requires real signed Auth/JWT and PostgREST cross-owner checks, a complete effective table/column/RPC grant audit for the deployed schema, and deployed migration parity. M003 still needs real OTP collision, timeout, replay and concurrent-login tests. The associated Drive access and credential-provenance work also keeps G01 open. This local SQL test does not establish production authority or user acceptance.
