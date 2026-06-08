# MOBI Production Readiness Executive Summary

> Historical snapshot: this 2026-05-06 audit predates the 2026-05-23 Mobio
> limited-scope cleanup. Treat it as audit history only. Current production
> scope and release status are in `docs/product/scope.md`,
> `docs/reports/production-readiness-audit.md`, and
> `docs/release/go-no-go.md`. Legacy BioPay, payment, SMS ledger, and
> ride-request lifecycle references below are not approved active scope.

Date: 2026-05-06
Repo: `/Volumes/PRO-G40/MOBI/mobi_app`
Branch: `main`
Head: `5d9c5dd feat: harden MOBI super app launch`

## Overall Readiness

Status: **Red**

Recommendation: **No-go for production release until the P0/P1 items below are closed or explicitly accepted with owners and deadlines.**

The repo has a strong amount of production hardening already in place: Flutter route guards, WhatsApp OTP flows, Supabase RLS/RPC hardening, release scripts that require Supabase dart-defines, Deno backend verification, and prior audit documentation. This pass closes several code-level P1 risks, but production is still blocked by credential exposure/history, unproven Supabase migration replay against a real database, and unrun release-build validation.

2026-05-23 update: this historical snapshot is superseded by the current
limited-scope Mobio audit. Active Flutter/native BioPay, payment, SMS ledger,
ride-request, and route-computation surfaces have been removed or isolated.
Local Flutter analysis/tests, local backend verification, local Supabase replay,
and signed Android artifact builds now have evidence in
`docs/reports/production-readiness-audit.md`. Production remains no-go for
credential rotation/history purge, linked Supabase validation, linked staging
replay, Play Console upload validation, and physical-device Android smoke.

2026-05-24 update: release validation now has explicit fail-closed gates for
linked Supabase credentials and Play service-account Git history. The release
workflow checks out full history, requires `REQUIRE_SECRET_HISTORY_CLEAN=true`,
and Fastlane production promotion requires `PLAY_PRODUCTION_APPROVED=true`.
The Play service-account history gate still fails until the exposed key is
revoked/rotated and commit `b10e74f` is purged from history.

## Top Launch Blockers

| Severity | Area | Finding | Status |
| --- | --- | --- | --- |
| P0 | Secrets | Google Play service-account private key was tracked at `android/fastlane/play-store-service-account.json`; local working tree now deletes it and Fastlane reads `PLAY_STORE_SERVICE_ACCOUNT_JSON`, but history rotation/purge is still required. | Partially fixed |
| P0 | Validation | Historical Flutter/Dart disk issues are no longer the active local blocker. Current local evidence includes clean Flutter analyzer, full Flutter tests, release contract tests, backend checks, secret scan, public-site verifier, and signed Android AAB/APK builds. Physical-device smoke and Play upload validation are still external blockers. | Locally improved, externally blocked |
| P0 | Database | Static migration concerns were followed by local Docker Desktop replay, local DB lint, and local SQL assertions. Linked Supabase access remains blocked by missing privileged credentials or `SUPABASE_DB_PASSWORD`, so staging/production validation is still open. | Locally improved, linked validation blocked |
| P1 | Admin auth | Admin permission fallback previously trusted `profiles.role = 'admin'` after allowlist deactivation. A migration now binds the fallback to active admin WhatsApp numbers and revokes explicit grants on deactivation. | Fixed locally, unvalidated against DB |
| P1 | Admin UI | Web admin deep links could pass the guard but render passenger wrappers after reload. Routes now render admin screens directly and role sync runs on web. | Fixed locally; analyzer and targeted admin tests passed |
| P1 | PWA security | Generated Cloudflare PWA bundles lacked `_headers` security policy output. Bundle preparation now emits client/admin CSP and no-store shell headers. | Fixed locally |
| P1 | Release gates | Release backend verification could skip linked Supabase gates. Release now sets `REQUIRE_LINKED_SUPABASE=true`. | Fixed locally |
| P1 | Auth abuse | OTP send now uses DB-backed phone, source, and global rate-limit buckets. The linked project still lacks the `otp_rate_limits` table until migration `20260501132000` is applied. | Fixed locally, not applied remotely |
| P1 | Edge auth | Promo generation requires `PROMO_GENERATION_SECRET`; legacy BioPay/payment/SMS function entrypoints now return a 410 scope-unavailable response. Edited Edge Functions pass `deno check`, but linked deployment validation remains required. | Locally fixed, linked validation pending |
| P1 | Mobile ledger | Native ledger/SMS code, receivers, bridge, Room/WorkManager/SQLCipher dependencies, and Flutter ledger surfaces were removed from the active Android/Flutter package. Signed Android artifacts build locally; device smoke is still external. | Removed from active scope, device smoke pending |

## High-Leverage Improvements

1. Rotate and revoke the exposed Google Play service-account key; purge the file from Git history before pushing.
2. Free additional system disk space or move Flutter/Gradle caches to a writable volume, then run full Flutter test/build checks.
3. Prove Supabase clean-checkout migration reproducibility with local Docker or a disposable staging project.
4. Run clean Supabase migration replay and DB lint against local Docker or disposable staging.
5. Add CAPTCHA/App Check enforcement to OTP send surfaces if provider abuse remains a realistic threat.
6. Keep service-role functions covered by explicit in-function auth or
   dedicated cron secrets before deployment.
7. Add Edge Function tests for admin revocation, campaign authorization paths, and linked RLS assertions.
8. Add server-side pagination/count RPCs for admin workspaces and high-volume user/trip/audit tables.
9. Add PWA/admin browser validation with headers, offline behavior, keyboard navigation, and Lighthouse/axe.
10. Formalize release/rollback/incident runbooks and monitoring ownership.

## Changes Made In This Pass

- Removed the tracked Play service-account JSON from the working tree.
- Updated Fastlane to read Play upload credentials from `PLAY_STORE_SERVICE_ACCOUNT_JSON`.
- Expanded secret scanning to detect Google/private-key service-account JSON
  patterns and fail if the old Play service-account JSON path reappears.
- Added Cloudflare Pages `_headers` generation for client/admin PWA bundles.
- Bound the in-memory admin session fallback to the current Supabase user id.
- Made `/admin` and `/admin/users` render admin screens directly after route guard success.
- Added Supabase migration `20260501132000_admin_revocation_and_operational_events.sql`.
- Added DB-backed OTP rate-limit buckets and source/global limits for app/admin OTP send.
- Required `PROMO_GENERATION_SECRET` for promo generation instead of accepting service-role bearer tokens.
- Converted legacy BioPay/payment/SMS function entrypoints to scope-unavailable
  responses instead of active service-role mutation paths.
- Added canonical legacy table and storage bucket foundations for clean Supabase replay.
- Disabled direct anonymous/email signup defaults in local Supabase config.
- Removed native Android ledger/SMS code and high-risk payment/BioPay client
  dependencies from the active app package.
- Added an admin operational health screen backed by a permission-gated RPC for `operational_health_events`; linked validation shows this migration is still pending remotely.
- Added explicit admin permission grants during admin OTP session creation.
- Added `operational_health_events` schema support for existing Edge Function observability writes.
- Made release backend checks fail closed when linked Supabase credentials are absent.
- Hardened Android signing-file writes with owner-only permissions and release cleanup.

## Human Decisions Needed

- Confirm Google Play key rotation and Git history purge process.
- Confirm staging/production Auth config should match the WhatsApp-only local config hardening.
- Keep SMS receipt ingestion out of Mobio production unless a separate,
  Play-approved product scope is explicitly approved.
- Decide whether admin PWA should disable offline service-worker caching entirely.
- Confirm whether `paysnhuxngsvzdpwlosv` is staging or production before applying the pending `20260501132000` migration remotely.
