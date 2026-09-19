# Auth and REST authority — local QA checkpoint

15 September 2026, Africa/Kigali. This review records the preceding 101-migration checkpoint. Current Admin-purpose qualification is in [admin-login-review.md](admin-login-review.md), and [progress.md](progress.md) contains the current rollup. **Three reproduced access-control defects were repaired locally.** Actual Auth and PostgREST requests, persistent synthetic rows and SQL-role assertions support the results below. Complete application authentication and release acceptance remain open.

## Executed environment

GoTrue 2.195.0 and PostgREST 16.1 run alongside the retained PostgreSQL 17.6 fixture. Both services share its network-none namespace. They have no published host ports, external network path, SMTP/phone provider credentials or FCM tokens. Resource limits, image IDs and fixture counts are recorded in `http-auth-retained-environment.json` under `build/qa/fullstack-qa-20260914/`.

Five synthetic accounts were provisioned through the actual Auth API. Three fixtures received a server-set verified phone/provider marker; one was email-only and one was created by the anonymous signup API. Actual Auth access and refresh tokens were issued. This fixture provisioning tests downstream authorization; it does not prove the application's WhatsApp OTP, Admin OTP or review-login flow. Synthetic conversations/messages stayed inside this namespace. The retained fixture has five users, five sessions, three conversations, four messages, zero permission grants, zero FCM tokens and zero HTTP requests queued. Scheduled jobs are disabled.

Local secrets and sessions are held in a mode-0600 file outside the evidence directory. Their values are excluded from source manifests, reports and new raw evidence. No production data, real messages, deployment or provider action was used.

## Confirmed defects and repairs

**FQA-029 — unverified protected chat access.** The anonymous and email-only Auth sessions each obtained HTTP 200 and persisted a conversation before the repair. The application had relied on the JWT subject for ownership. The new `verified_app_user_id()` requires an exact live Auth session, a non-anonymous identity, a confirmed phone and a trusted server provider marker. The migration applies that identity to effective application routines, ownership defaults and public/Storage RLS expressions. It preserves the platform's `auth.uid()` and public-read branches. Anonymous/unverified protected chat access is now denied; valid owner, public-catalog and service paths still pass.

**FQA-030 — timezone-sensitive permission expiry.** An expired synthetic `admin.users.read` grant was denied normally but accepted when PostgREST received `Prefer: timezone=Pacific/Auckland`. The old comparison converted `now()` to a timestamp without timezone before comparing it with an absolute expiry. The forward migration compares `timestamptz` instants directly using `now()`. Expired and future grants now behave consistently in UTC, Pacific/Auckland and America/Los_Angeles. These explicit grant fixtures qualify expiry behavior; Admin OTP purpose and the full permission matrix remain separate work.

**FQA-031 — REST access after logout.** Auth logout returned 204 and Auth rejected the old token, while REST still returned the protected profile. `live_auth_user_id()` now binds `session_id` to the same user in `auth.sessions`, checks expiry, deletion and ban state, and returns no identity after revocation. The PostgREST pre-request hook returns PT401 for an authenticated request without a live session. RLS and protected RPCs also reject the revoked identity independently. A fresh session for the same account does not restore the old token. Supabase documents the distinction between JWT expiry and session revocation, including checking the session row for stricter enforcement. [Supabase session documentation](https://supabase.com/docs/guides/auth/sessions).

The migrations are `20260914213843_harden_permission_expiry_instant.sql` and `20260914214407_enforce_live_verified_database_identity.sql`. Both apply in the fresh 101-file chain. The second migration refuses to silently replace a different existing PostgREST pre-request hook; integration with any deployed hook must be qualified before rollout. No remote migration has been applied.

## Evidence

Paths below are relative to `build/qa/fullstack-qa-20260914/`.

| Check | Result | Artifact |
| --- | --- | --- |
| Original HTTP reproduction | 4 status mismatches across 14 probes | http-authority-initial-probes.json |
| Repaired core HTTP batch | 13 probes passed | http-authority-after-live-identity.json |
| Extended actual HTTP batch | 24 checks passed | live-identity-http-regression.json |
| Request timezone / expiry | 6 HTTP checks passed | permission-expiry-http-green.json |
| Permanent identity suite | 40 SQL assertions passed | db-http-auth-final-live_identity_behavior.log |
| Permanent permission-expiry suite | 9 SQL assertions passed | db-http-auth-final-permission_expiry_behavior.log |
| Complete fresh pinned CLI rehearsal | 101 migrations, 8 SQL suites and 8 rate tests passed | db-http-auth-cli-rehearsal.json |
| Current retained-schema suites | 8 passed | db-http-auth-final-sql-suites.json |
| Reduced BioPay fixture | Passed | db-http-auth-fast-biopay.json |
| Routine checking | 142 routines / 166 contexts; zero errors, 4 explained warnings | db-http-auth-routine-summary.json |
| Full Flutter regression | 643 passed | http-auth-flutter-test.log |
| Dart analysis | No issues | http-auth-dart-analyze.log |

HTTP batches overlap; their sizes are not an additional unique-journey denominator. Deliberately signed malformed/missing/mismatched-session tokens are negative inputs only. Positive session tests use Auth-issued tokens. Early SQL-test authoring errors are retained separately and are not counted as product findings. Existing SQL fixtures now contain complete synthetic session rows rather than weakening the production guard.

## Remaining work

The full Admin-purpose/session and role matrix, Edge OTP issuance, attempt/claim behavior over actual HTTP, review-login exception, refresh/session lifecycle, account deletion and every active RPC/argument path remain incomplete. Storage has schema migrations only; Storage HTTP and Realtime websocket behavior are unverified. No configured consumer/Admin browser, native or installed-PWA journey used this local service environment. App performance after the identity changes also needs measurement on qualified runtimes.

Source at this checkpoint had 1,958 files, fingerprint `c6dda0a6f97bcb8235053ae1c79f91266e0838fb59414e57eca00931cbab9dc3`. Seven database/test files changed or were added in this batch; none were removed. Previous evidence and report copies remain retained. **The QA goal stays active and overall readiness remains NO-GO.**
