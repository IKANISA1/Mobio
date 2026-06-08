# MOBI Production Readiness Findings

> Historical snapshot: this 2026-05-06 findings log predates the 2026-05-23
> Mobio limited-scope cleanup. Treat it as audit history only. Current
> production blockers are in `docs/reports/production-readiness-audit.md` and
> `docs/release/go-no-go.md`. Legacy BioPay, payment, SMS ledger, and
> ride-request lifecycle references below are not approved active scope.

Date: 2026-05-06

| Severity | Area | Finding | Evidence | Risk | Recommended fix | Status |
| --- | --- | --- | --- | --- | --- | --- |
| P0 | Secrets | Google Play service-account JSON was tracked. | `android/fastlane/play-store-service-account.json` was tracked; `android/fastlane/Appfile:1` previously referenced it. | Store publishing compromise. | Rotate/revoke key, purge Git history, keep only CI secret. | Partially fixed locally: file deleted, Fastlane env-based. |
| P0 | Validation | Flutter/Dart tooling initially failed due system disk exhaustion. | Historical `flutter --version`/`dart --version` failed writing `engine.stamp`; current evidence in `docs/reports/production-readiness-audit.md` shows analyzer, full Flutter tests, release contract tests, signed AAB/APK builds, and local backend checks passing. | Production still needs physical-device smoke and Play upload validation. | Attach authorized Android device and validate Play Console upload after key rotation. | Locally improved, external smoke/upload pending. |
| P0 | Supabase migrations | Migration chain appeared to depend on remote-only tables/buckets, and linked validation remains unavailable. | Current local Docker Desktop replay, local DB lint, and SQL assertions are documented in `docs/reports/production-readiness-audit.md`; linked access to the intended project still returns login-role 403 without `SUPABASE_DB_PASSWORD`. | Staging/production drift may remain until linked replay and assertions run. | Provide privileged linked access or `SUPABASE_DB_PASSWORD`, replay staging, and rerun linked assertions. | Locally improved, linked validation blocked. |
| P1 | Admin revocation | Role-only admin fallback survived allowlist deactivation. | Old `has_platform_permission` in `20260501090000...sql` allowed `profiles.role = 'admin'`. | Offboarded admins could retain server access. | Bind fallback to active allowlist; revoke explicit grants on deactivation. | Fixed locally in `20260501132000...sql`. |
| P1 | Admin session | In-memory admin fallback was not tied to current Supabase user. | `AdminSessionGuard` stored only static admin flag/timestamp. | User switch/anonymous de-escalation could preserve admin UI fallback. | Store granted user id and revoke on mismatch. | Fixed locally. |
| P1 | Admin PWA routing | Admin deep links could render passenger wrappers after web reload. | `/admin` and `/admin/users` were shell branches using role-dependent wrappers. | Admin PWA usability and route correctness issue. | Render admin screens directly after guard; sync role on web. | Fixed locally. |
| P1 | PWA security | Generated client/admin bundles lacked Cloudflare `_headers`. | `scripts/web/prepare_pwa_bundles.sh` created redirects only. | Weak browser security policy and stale shell caching. | Emit CSP, frame, content-type, referrer, permissions, no-store shell headers. | Fixed locally. |
| P1 | Release gates | Release backend verification could skip linked Supabase gates. | `verify_backend.sh` skipped when env absent; `release.yml` did not require fail-closed. | Release could proceed without linked RLS/lint assertions. | Add `REQUIRE_LINKED_SUPABASE=true` for release. | Fixed locally. |
| P1 | OTP abuse | OTP send throttles were phone-only. | `send-login-otp` and `send-otp` queried recent rows by phone only. | Provider-cost abuse and account probing. | Add DB-backed phone/source/global quotas and plan CAPTCHA/App Check if needed. | Fixed locally with `otp_rate_limits`/`consume_otp_rate_limit`; linked project still lacks the table until `20260501132000` is applied. |
| P1 | Edge auth | Service-role functions needed stronger in-function auth checks. | Legacy BioPay/payment/SMS entrypoints previously carried privileged mutation risk; promo accepted service-role bearer. | RLS bypass if exposed/misconfigured. | Keep privileged paths either unavailable for Mobio scope or protected by dedicated cron/app auth. | Locally fixed: promo requires `PROMO_GENERATION_SECRET`; legacy BioPay/payment/SMS entrypoints return 410 scope-unavailable. Linked deployment validation pending. |
| P1 | Auth config | Supabase config enabled anonymous/email signup despite WhatsApp-only production assumption. | `supabase/config.toml` enabled anonymous sign-ins and email signup. | Unverified identities may reach flows not explicitly guarded. | Disable direct public Auth signup surfaces and keep WhatsApp OTP as boundary. | Fixed locally. |
| P1 | Mobile ledger | SMS provider cache, permissions, and destructive Room migrations needed release hardening. | The corrected Mobio scope excludes native SMS ledger/payment behavior. | Play policy and product-scope risk if reintroduced. | Keep ledger/SMS code and permissions out of active app unless separately approved. | Removed from active Android/Flutter package; signed artifacts build locally, device smoke pending. |
| P2 | Observability | Edge observability helper wrote to a table that had no admin review surface. | `_shared/observability.ts` inserts `operational_health_events`; linked assertions show the table is missing remotely. | Error telemetry can be missed by operators. | Create table/RLS/indexes, permission-gated admin RPC, and admin UI. | Fixed locally in `20260501132000...sql` and `/admin/health`; pending remote migration. |
| P2 | Supply chain | Deno/npm imports and GitHub Actions needed stronger drift control. | `supabase.ts` imports `npm:@supabase/supabase-js@2`; workflows previously used mutable action tags. | Drift and supply-chain exposure. | Keep `deno.lock` committed, run backend checks with `--frozen --lock`, and keep workflow actions pinned to 40-character SHAs. | Fixed locally: `deno.lock` is generated, backend verification enforces frozen lockfile checks, workflow actions are pinned to immutable SHAs, and `scripts/ci/check_github_actions_pinned.sh` guards future workflow edits. |
| P2 | Admin scale | Admin workspaces often paginate client-side over capped result sets. | Static review found 100/120 row caps in admin screens/providers. | Missing records at production scale. | Server-side pagination/search/sort RPCs with totals. | Not fixed. |
| P2 | Accessibility | Bottom nav/admin icon-only controls need stronger semantics and keyboard/focus coverage. | Static review found raw `GestureDetector` nav and icon-only admin buttons. | Screen-reader/keyboard failures. | Add Semantics/Tooltip/Focus or use Material navigation controls. | Not fixed. |

## Validation Status

- Current local Flutter analyzer, full Flutter tests, release contract tests,
  local backend checks, local Supabase replay/lint/assertions, public-site
  verification, and signed Android artifact builds are documented in
  `docs/reports/production-readiness-audit.md`.
- Linked Supabase validation is still blocked by missing privileged access or
  `SUPABASE_DB_PASSWORD`; physical Android smoke and Play upload validation are
  still external release gates.
- The deleted Play service-account file still exists in Git history until a history rewrite is performed outside this working-tree patch.
