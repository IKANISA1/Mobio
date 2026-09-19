# Admin login authority — local QA checkpoint

Subsequent local verification: [edge-otp-session-review.md](edge-otp-session-review.md) records 30 actual handler/Auth/REST checks and repairs to Admin account lookup. The SQL and earlier HTTP findings below retain their original checkpoint scope; delivery, configured UI and hosted Edge parity remain unverified.

15 September 2026, Africa/Kigali. **FQA-032 is repaired locally:** a consumer session can no longer gain Admin access merely through a permission grant or profile promotion. Twenty-two actual HTTP checks, 29 SQL assertions, the fresh 102-migration rehearsal and 643 Flutter tests passed. Actual Admin OTP issuance and configured UI acceptance remain incomplete.

## Requirement and reproduction

[CRITICAL_RULES.md](../../../CRITICAL_RULES.md) requires a separate Admin WhatsApp OTP purpose, an allowlisted phone and server-side authorization. In the isolated Auth/PostgREST environment, a genuine consumer session initially received a denial from Admin user listing. The same bearer then received HTTP 200 in each of two cases: an explicit `admin.users.read` grant without Admin login, and an Admin profile role plus allowlisting without the Admin login marker. The stricter BioPay Admin endpoint already denied that consumer marker.

The probe also applied the account-update payload used by the current Admin session-creation code, including email/password rotation and server metadata. Actual Auth deleted the older consumer session: Auth returned 403, REST returned 401 and refresh returned 400. A newly issued Admin-marker session worked. This rules out the suspected old-session refresh escalation for that tested update path. The payload was applied by the fixture; the Edge OTP handler itself was not executed in this probe.

## Repair

The forward migration `20260914222140_enforce_admin_login_authority.sql` introduces `verified_admin_user_id()`. It requires a live eligible session, non-anonymous claims, a confirmed Auth phone, the Admin provider marker in both the signed JWT and current server metadata, and an active allowlist entry for that Auth phone. An allowlisted phone written only into the application profile does not satisfy the check.

Permission resolution now uses this Admin identity. Existing explicit permission scopes, expiry behavior and the full-Admin fallback remain available to qualified Admin identities. Shared application identity also requires Admin authority when the profile role is Admin, protecting legacy role-based RPC/RLS branches after a profile promotion or allowlist change.

An Admin profile opened with an older consumer login therefore needs the separate Admin login before protected database access resumes. Configured UI recovery for this transition still needs testing. The migration has been applied only to disposable local databases.

## Evidence

All raw paths are under `build/qa/fullstack-qa-20260914/`.

| Check | Result | Artifact |
| --- | --- | --- |
| Original grant/promotion bypass | Two unexpected Admin admissions | admin-session-purpose-reproduction.json |
| Auth password-rotation behavior | Old session removed; Auth403, REST401, refresh400; new session accepted | admin-session-purpose-reproduction.json |
| Actual consumer/Admin HTTP regression | 22 passed, including qualified positives and immediate allowlist revocation | admin-login-authority-http-regression.json |
| Permanent Admin authority suite | 29 passed | db-admin-purpose-final-admin_login_authority.log |
| Existing identity and expiry suites | 40 identity and 9 expiry assertions passed | db-admin-purpose-final-sql-suites.json |
| Fresh pinned CLI rehearsal | 102 migrations, 9 SQL suites and 8 rate-limit cases passed | db-admin-purpose-cli-rehearsal.json |
| Reduced BioPay fixture | Passed | db-admin-purpose-fast-biopay.json |
| Full Flutter / Dart | 643 passed; no analysis issues | admin-purpose-flutter-test.log; admin-purpose-dart-analyze.log |
| Routine checking | 142 routines / 166 contexts, zero errors, four explained compatibility warnings | db-admin-purpose-routine-summary.json |

The expiry HTTP checks now use an eligible Admin-purpose identity and a delegated explicit grant. The earlier consumer-grant fixture is no longer accepted as an Admin identity. Its historical evidence remains preserved, and the current case rows point to the repaired authority test.

All probe grants, temporary allowlist entries and profile promotions were removed. Seven synthetic users/sessions remain for continued QA; the four preexisting migration-seeded allowlist rows are unchanged. There are no FCM tokens, queued HTTP requests or external network paths in this fixture. Local credentials remain outside the evidence directory in a mode-0600 file.

## Remaining work

Complete the actual Edge OTP issuance/claim/session path, account lookup and failure handling, the remaining RPC/role/argument matrix, configured Admin-login recovery after promotion, Storage/Realtime integration and native/web/PWA journeys. Test profiles and Auth-issued fixture sessions do not establish real WhatsApp delivery or full application authentication.

Current source contains 1,960 files at fingerprint `6aa84b05a7ddd589aea786008ad67b3554f27bef7dbba70011f9f60467e4172e`. Five database/test files changed or were added; none were removed. The goal remains active, and overall readiness remains **NO-GO** pending the remaining planned execution and acceptance work.
