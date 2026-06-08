# MOBI Production Audit and Phase 1 Hardening

> Historical snapshot: this 2026-05-01 audit predates the 2026-05-23 Mobio
> limited-scope cleanup. Treat BioPay, payment, SMS ledger, and ride-request
> lifecycle references below as historical findings only. Current production
> scope and blockers are in `docs/product/scope.md`,
> `docs/reports/production-readiness-audit.md`, and
> `docs/release/go-no-go.md`.

Date: 2026-05-01
Branch inspected: `feature/mobi-super-app-merger`

## Scope Inspected

- Flutter mobile/PWA code under `lib/`, `android/`, `ios/`, `web/`, and `landing/`.
- Supabase schema, migrations, RLS, Edge Functions, storage references, realtime publication entries, and admin scripts under `supabase/` and `scripts/`.
- Admin, BioPay, ledger, booking, nearby, profile, chat, payment, dashboard, CI, release, and documentation surfaces.
- Agent/channel artifacts in `AGENTS.md`, `prompts.md`, Edge Functions, WhatsApp OTP/admin allowlist code, Firebase, Google Maps/Gemini, SMS parsing, and payment guidance flows.

## Architecture Map

- Client: Flutter app with mobile and web/PWA targets, feature modules under `lib/features`, shared services/router under `lib/core`, shared widgets under `lib/shared`, and extracted local packages for theme tokens (`packages/design-system`) and pure model contracts (`packages/shared-types`).
- Admin: Embedded Flutter admin surface mounted through `/admin*`, backed by Supabase RPCs and admin services.
- Public web: Static landing and web assets under `landing/` and `web/`, deployed through Firebase/Cloudflare scripts.
- Backend: Supabase Postgres migrations, RLS policies, RPCs, storage bucket setup, realtime publication, and Edge Functions.
- Payments: Payment intent tables and Edge Functions layered over ledger `transactions`, QR/NFC session tables, SMS parsing, and manual reconciliation paths.
- BioPay: Flutter biometric enrollment/scan services, Deno `biopay-api`, vector migrations/RPCs, and service-role-managed biometric tables.
- Native ledger: Android SQLCipher ledger code under active `com.mobi.ledger`; legacy `rw/mobi/app/ledger` package is excluded by Gradle.
- CI/CD: GitHub Actions run Flutter verification, backend Deno checks, release config checks, Android/iOS builds, and Cloudflare/Firebase deploy helpers.

## Module Inventory

- Flutter features: `admin`, `biopay`, `bookings`, `chat`, `home`, `ledger`, `nearby`, `payments`, `profile`, `splash`.
- Core areas: router/session guard, admin services, Supabase services, country/vehicle/subscription services, theming, constants, errors, logging.
- Tests: unit/widget tests under `test/core`, `test/features`, `test/models`, `test/providers`, and `test/services`.
- Release/ops scripts: `scripts/ci`, `scripts/release`, `scripts/admin`, `scripts/web`.

## Supabase and Backend Inventory

- Migrations: 36 tracked SQL migrations plus the Phase 1 migration added here.
- Edge Functions: `_shared`, `admin-review-transaction`, `biopay-api`, `chat-assist`, `create-payment-intent`, `generate-promo-content`, `maps-gateway`, `parse-sms`, `reconcile-momo-sms`, `send-otp`, `verify-otp`, `verify-payment-status`.
- Shared backend helpers: Supabase client creation, HTTP/CORS helpers, admin access helpers, OTP security, WhatsApp helpers, observability.
- Core tables/RPC areas: profiles, trips, countries, admin audit/access, OTP, notifications, BioPay, ledger transactions, payment intents/events, QR/NFC sessions, risk flags.

## Agent and Channel Inventory

- No OpenClaw workspace or MCP server definitions were found in this repo.
- Agent-like surfaces are prompt/docs and AI Edge Functions: `AGENTS.md`, `prompts.md`, `chat-assist`, and `generate-promo-content`.
- Channel adapters/integrations present: WhatsApp Cloud OTP/admin allowlist, SMS parsing/reconciliation, Firebase messaging/config/crashlytics, Google Maps gateway, Gemini-backed promo generation, Cloudflare/Firebase hosting, Supabase realtime/storage.

## Ranked Risks

- P0: `reconcile-momo-sms` used service-role writes without caller authentication/authorization.
- P0: Payment Edge Functions had weak input validation and broad CORS/method handling.
- P1: Admin trip cancellation updated `trips` directly from Flutter with no server-side authorization/audit RPC.
- P1: Flutter referenced `vehicle_types`, `vehicle_type_countries`, and `subscription_plans`, but those tables/RLS policies were missing locally.
- P1: QR/NFC payment session tables allowed public full-row reads.
- P1: Android ledger database has a fixed SQLCipher passphrase pattern that needs hardware-backed per-install keying.
- P1: `_shared/supabase.ts` allowed the anon client to fall back to a service-role key if anon env vars were missing.
- P2: `admin_audit_log` and `admin_audit_logs` both exist with different shapes; `admin_audit_log` is now canonical and a bridge migration backfills compatible legacy payment-review rows.
- P2: Several BioPay migrations overlap and need consolidation.
- P2: `parse-sms` still has permissive `Access-Control-Allow-Origin: *`.
- P2: Analyzer reports 48 warnings/infos across existing Flutter files.
- P3: Supabase CLI installed locally is behind the latest available version.

## Dead, Duplicated, and Hardcoded Areas

- Proven dead/excluded: `android/app/src/main/kotlin/rw/mobi/app/ledger/**` is not used by the active package and is excluded by Gradle.
- Duplicated audit storage: singular `admin_audit_log` is canonical; plural `admin_audit_logs` is retained for compatibility and bridged into the canonical log.
- Duplicated BioPay migrations/RPC definitions across multiple foundation/compat migrations.
- Hardcoded catalog fallback still exists in Flutter for resilience, but Phase 1 adds database-backed tables.
- Admin trip cancellation still passes a fixed operational reason from the UI; the state change and audit now happen server-side.
- Release/build commands still require explicit dart-defines for Supabase and policy URLs.

## Phase 1 Implemented

- Removed service-role fallback from anon Supabase client construction.
- Added shared Edge Function input/auth validation helpers.
- Hardened payment intent creation/status verification/reconciliation/admin review Edge Functions.
- Product correction on 2026-05-01: passenger in-app payment creation and
  status verification are unsupported. `create-payment-intent` and
  `verify-payment-status` now return `410 Gone`; USSD instructions and
  manual/back-office confirmation remain the supported payment path.
- Required authenticated callers for MoMo SMS reconciliation and verified payee/transaction ownership before service-role writes.
- Added admin-only transaction review flow with audit logging and generic server error responses.
- Added missing catalog tables/RLS for vehicle types, country allocations, and subscription plans.
- Replaced public QR/NFC session select policies with owner/admin select policies.
- Added `rpc_admin_cancel_trip` for audited admin trip cancellation.
- Updated Flutter admin trip cancellation to call the new RPC instead of direct table updates.
- Deployed hardened payment/reconciliation Edge Functions to the linked Supabase project:
  `create-payment-intent`, `verify-payment-status`, `reconcile-momo-sms`, and `admin-review-transaction`.
- Added admin-only audit and finance-review list RPC contracts on 2026-05-01, and aligned `admin-review-transaction` audit writes with the canonical `admin_audit_log` table.

## Files Changed in Phase 1

- `lib/core/services/admin/admin_trip_service.dart`
- `lib/core/services/admin_service.dart`
- `lib/features/admin/admin_trips_screen.dart`
- `supabase/functions/_shared/supabase.ts`
- `supabase/functions/_shared/validation.ts`
- `supabase/functions/create-payment-intent/index.ts`
- `supabase/functions/verify-payment-status/index.ts`
- `supabase/functions/reconcile-momo-sms/index.ts`
- `supabase/functions/admin-review-transaction/index.ts`
- `supabase/migrations/20260501020000_phase1_catalog_and_admin_trip_hardening.sql`
- `supabase/migrations/20260501070000_admin_audit_finance_review_contracts.sql`
- `docs/security/production_audit_phase1.md`

## Verification Commands

- `deno fmt supabase/functions/_shared/supabase.ts supabase/functions/_shared/validation.ts supabase/functions/create-payment-intent/index.ts supabase/functions/verify-payment-status/index.ts supabase/functions/reconcile-momo-sms/index.ts supabase/functions/admin-review-transaction/index.ts`
- `dart format lib/core/services/admin/admin_trip_service.dart lib/core/services/admin_service.dart lib/features/admin/admin_trips_screen.dart`
- `./scripts/ci/verify_backend.sh`
- `./scripts/ci/verify_flutter.sh`
- `supabase db lint --local --fail-on error`
- `supabase migration list --local`

## Verification Results

- Deno formatting passed.
- Dart formatting passed.
- Backend CI passed: all Edge Functions type-checked, admin script type-checked, and BioPay API Deno tests passed.
- Flutter CI passed: pub get, l10n generation, analyzer with non-fatal warnings/infos, and full test suite passed.
- Local Supabase lint and migration list could not run because the local database on `127.0.0.1:54322` was not running.

## Rollback Strategy

- Revert the Phase 1 files listed above as one change set if application behavior regresses.
- If the migration has already been applied, restore the previous QR/NFC public policies only as an emergency compatibility rollback, then replace with token resolver RPCs before production exposure.
- Keep `admin_audit_log` and `admin_audit_logs` intact until all production readers/writers are confirmed on the canonical table; do not drop either table without data migration.
- Do not re-enable anon-client service-role fallback; fix missing anon env configuration instead.

## Next Phase

- Start Supabase locally or connect a staging database and run full migration/lint validation.
- Add token resolver RPCs for QR/NFC scan flows so scanners can resolve only valid session tokens without full table reads.
- Move Android ledger encryption to Android Keystore-backed per-install keys with migration handling.
- Finish audit-log consolidation by removing legacy plural-table dependencies after production verification.
- Complete SMS ingestion threat model and add provider-specific parser tests.
- Consolidate BioPay migrations and verify all biometric/RPC access paths.
- Reduce analyzer warnings and add targeted tests for admin cancellation and payment Edge Function contracts.

## 2026-05-01 Follow-Up

- Pushed `20260501020000_phase1_catalog_and_admin_trip_hardening.sql` to linked Supabase project `paysnhuxngsvzdpwlosv`.
- Added and pushed `20260501030000_driver_entitlements_saved_places_and_intelligence.sql`.
- New backend capabilities:
  - Moto taxi driver entitlement rule: 30 free driver trips per month, then Pro subscription required.
  - `driver_subscriptions` and `driver_trip_entitlement_usage` tables with RLS.
  - `rpc_create_trip` now owns trip creation, rejects anonymous scheduling, and records entitlement usage.
  - Direct client inserts into `trips` are disabled by RLS.
  - `favorite_addresses` table with owner/admin RLS for home, school, work, and other saved places.
  - `rpc_suggest_trip_pools` for driver/passenger and passenger/passenger pool suggestions.
  - `mobility_events` plus `rpc_get_driver_demand_zones` for driver passenger-probability maps.
- Flutter now calls `rpc_create_trip`, maps quota/login RPC errors to user-facing copy, and exposes service methods for saved addresses, pool suggestions, and demand zones.
- Remaining product work:
  - Add visible saved-address CRUD UI and route-form shortcuts.
  - Add pool suggestion cards after scheduling and demand-zone map UI for drivers.

## 2026-05-01 WhatsApp Login Slice

- Added and pushed `20260501040000_whatsapp_login_otp_and_audit.sql`.
- `otp_codes` now has a `purpose` column so admin login OTPs and app login OTPs cannot be replayed across flows.
- Added `app_auth_attempts` with service-role-only access for passenger/driver login audit events.
- Added and deployed app login Edge Functions:
  - `send-login-otp`
  - `verify-login-otp`
- Redeployed patched admin OTP Edge Functions:
  - `send-otp`
  - `verify-otp`
- Flutter now has a passenger/driver WhatsApp login screen at `/login`.
- App routing now treats anonymous Supabase sessions as unauthenticated and redirects protected app routes to `/login`.
- Push notification registration and role sync now skip anonymous sessions.
- Admin OTP remains allowlist-only and isolated from the app login OTP purpose.
- Remote verification:
  - Supabase remote DB dry-run reports up to date.
  - Invalid-payload smoke checks reached both new deployed Edge Functions and returned expected `400` validation responses.

## 2026-05-01 Product UI Follow-Up

- Removed the existing Flutter analyzer warnings and infos without changing business behavior.
- Added saved-place scheduling UI for home, school, work, and other addresses:
  - Route form can save selected origin or destination.
  - Saved places can be reused as departure or destination shortcuts.
  - Saved places can be deleted from the schedule flow.
- Added post-schedule pool suggestion cards powered by `rpc_suggest_trip_pools`.
- Added a driver passenger-probability panel on the home/discover screen:
  - Loads real `rpc_get_driver_demand_zones` results.
  - Uses cached location when available and falls back to global active signals.
  - Renders a compact probability map plus ranked signal rows from scheduled passenger trips and mobility events.
- Added focused unit tests for `FavoriteAddress` and `DriverDemandZone` parsing contracts.
- Verification run:
  - `flutter analyze --no-fatal-infos --no-fatal-warnings`: no issues found.
  - `flutter test test/core/services/driver_location_service_test.dart test/models/favorite_address_test.dart`: passed.
  - `./scripts/ci/verify_backend.sh`: passed; linked Supabase lint skipped because linked access env vars were not present.
  - `./scripts/ci/verify_flutter.sh`: passed.
  - `flutter build web --release --no-wasm-dry-run ...`: passed and built `build/web`.
  - `git diff --check`: passed.
  - Secret scan for JWT-style Supabase tokens and `sbp_` tokens: no matching files.
- Migration checks:
  - `supabase db push --dry-run`: blocked by Supabase platform privilege `403`; requires a privileged access token or `SUPABASE_DB_PASSWORD`.
  - `supabase db lint --local --fail-on error`: blocked because local Supabase Postgres was not running on `127.0.0.1:54322`.
- Remaining product work:
  - Rotate the Supabase keys and access tokens that were shared in chat, then update local/CI secrets.
  - Decide whether production should support embedded map tiles; the current Flutter app intentionally renders native route and demand visualizations without an embedded map SDK.

## 2026-05-01 Security Delta

- Re-audited the current release candidate worktree after the Phase 1, WhatsApp login, saved-address, pool, and demand-zone changes.
- Additional source-proven risks fixed:
  - `parse-sms` no longer uses bespoke wildcard CORS or raw exception responses.
  - `parse-sms` now uses shared Edge Function CORS, method, authorization, JSON, and error helpers.
  - `parse-sms` validates `agent_id`, caps SMS batch size to 100, bounds raw SMS/sender/hash field lengths, and returns `401`/`403`/`400`/`500` by failure class.
  - `scripts/admin/bootstrap_admin.ts` no longer prints generated admin passwords into terminal or CI logs.
- Verification:
  - `deno fmt supabase/functions/parse-sms/index.ts scripts/admin/bootstrap_admin.ts`: passed.
  - `deno check supabase/functions/parse-sms/index.ts scripts/admin/bootstrap_admin.ts`: passed.
  - `./scripts/ci/verify_backend.sh`: passed; linked lint is skipped by the script when env vars are absent.
  - `./scripts/ci/verify_flutter.sh`: passed.
  - `flutter build web --release --no-wasm-dry-run ...`: passed and built `build/web`.
  - `git diff --check`: passed.
  - Secret-pattern scan for JWT-style Supabase tokens and `sbp_` tokens: no matching files.
- Remote Supabase lint:
  - `supabase db lint --linked --fail-on error`: reached the remote DB but failed on pre-existing extension-owned functions `public.histogram` and `public.pgsm_create_view`, not on the new migrations.

## 2026-05-01 QR/NFC and Ledger Hardening

- Added `20260501050000_payment_session_resolvers_and_extension_lint.sql`.
- Added authenticated resolver RPCs:
  - `rpc_resolve_qr_payment_session(p_session_token text)`
  - `rpc_resolve_nfc_payment_session(p_ndef_payload text)`
- The resolver RPCs return only active, unexpired session metadata needed by scanners and do not expose raw QR session tokens, NFC payloads, phone numbers, or full session table rows.
- QR/NFC session table reads remain owner/admin-only through RLS.
- Added client-side payment session resolution models and service methods for scanner flows.
- Added a migration step that moves `pg_stat_monitor` out of `public` into `extensions` when the migration role owns the extension, reducing false-positive linked Supabase lint failures from extension-owned functions.
- Scoped CI-linked Supabase lint to `--schema public`, which is the app-owned API schema; extension-owned functions remain outside release lint gates.
- Hardened the active Android ledger database key path:
  - New installs receive a random per-install SQLCipher passphrase stored in Android Keystore-backed `EncryptedSharedPreferences`.
  - Existing installs with the previous fixed SQLCipher passphrase are rekeyed in place on first open when SQLCipher can open the legacy database.
  - If legacy rekeying fails, the app preserves legacy access instead of destructively losing local ledger data and records the legacy key mode for follow-up remediation.
- Deployment and verification:
  - `supabase db push --linked --yes --include-all`: applied `20260501050000_payment_session_resolvers_and_extension_lint.sql`.
  - `supabase migration list --linked`: remote migration history includes `20260501050000`.
  - `supabase db lint --linked --schema public --fail-on error`: passed with no schema errors.
  - Default linked lint without `--schema public` still reports extension-owned issues under `extensions`; this is intentionally outside the app-owned release lint gate.
  - `./scripts/ci/verify_backend.sh` with linked lint credentials: passed.
  - `dart analyze` on the payment resolver client files: passed.
  - `flutter test test/features/payments/models/payment_session_resolution_test.dart`: passed.
  - `./gradlew :app:compileDebugKotlin`: passed; existing Room destructive-migration API deprecation warning remains.
  - `./scripts/ci/verify_flutter.sh`: passed.
  - `git diff --check`: passed.
  - Secret-pattern scan for JWT-style Supabase tokens and `sbp_` tokens: no matching files.

## 2026-05-01 Security/Privacy Hardening Follow-Up

- Added `20260501110000_security_profile_chat_dashboard_hardening.sql`.
- Fixed source-proven high-risk issues:
  - Direct profile self-updates can no longer mutate `role`, `is_driver`, `is_online`, `member_id`, `organization_id`, WhatsApp verification, or auth-provider fields.
  - Driver-mode escalation now requires a non-anonymous WhatsApp Cloud OTP session and a verified WhatsApp profile.
  - Chat conversation rows are no longer directly client-updatable.
  - Chat message updates are restricted to the `read_at` column, with a trigger preventing message content and sender metadata mutation.
  - `get_dashboard_stats()` now uses the explicit `admin.dashboard.read` permission instead of a direct `role = 'admin'` check.
  - OTP generation now uses `crypto.getRandomValues` instead of `Math.random`.
  - `chat-assist` validates the caller is a real participant in the requested conversation and loads messages/peer/trip context through RLS-backed database reads instead of trusting caller-supplied chat payloads.
  - `generate-promo-content`, `maps-gateway`, and `biopay-api` no longer return raw unexpected error messages to clients; promo generation now records canonical audit-log rows for generation runs.
- Added backend security assertions for profile privilege immutability, chat update grants/policies, and dashboard permission checks.
- Security model note: app UI guards remain useful for UX only. Role changes, driver escalation, chat integrity, payment state changes, and admin stats must continue to be enforced by Supabase RLS/RPC/Edge Function authorization.
- Deployment and verification:
  - `supabase db push --linked`: applied `20260501110000_security_profile_chat_dashboard_hardening.sql`.
  - `supabase db push --linked`: applied `20260501113000_security_lint_fixes.sql`.
  - Deployed hardened Edge Functions: `send-otp`, `send-login-otp`, `chat-assist`, `generate-promo-content`, `biopay-api`, and `maps-gateway`.
  - Re-deployed `generate-promo-content` with `--no-verify-jwt`; it remains protected by its internal cron-secret/service-role authorization check.
  - Remote backend security assertions returned zero failure rows.
  - `supabase db lint --linked --schema public --fail-on error`: passed with no errors; only legacy disabled BioPay transfer RPC unused-parameter warnings remain.
  - `deno check` on touched Edge Functions: passed.
  - `deno test --allow-env supabase/functions/biopay-api/index_test.ts`: passed.
  - `flutter test test/core/services/admin_service_test.dart test/core/router/admin_session_guard_test.dart`: passed.
  - `flutter analyze --no-fatal-infos --no-fatal-warnings`: no issues found.
  - `git diff --check`: passed.

## 2026-05-01 Tenant/Storage/Campaign Hardening Follow-Up

- Added and deployed `20260501120000_tenant_storage_campaign_final_hardening.sql`.
- Tenant isolation:
  - Added `organization_id` to remaining legacy operational/sensitive tables including admin WhatsApp numbers, app auth attempts, OTPs, promo jobs, ride/trip requests, saved places, and legacy BioPay tables.
  - Backfilled all tenant keys and made every public `organization_id` column non-null with a default platform organization.
  - Added enforcement triggers for ride requests, trip requests, saved places, BioPay wallets/transactions, and notification consent rows.
- Permission hardening:
  - Replaced remaining direct admin-role RLS checks in audit logs, profiles delete, promo jobs, QR sessions, risk flags, trips, vehicle config, and storage write policies with explicit platform permissions.
  - Added broadcast, campaign, audit-write, trip-manage, and platform-config permission keys and granted them to current admin profiles.
- Campaign safety:
  - Added `campaign_approvals` and `notification_consents`.
  - Promotional sends now require an approved campaign and granted promotional consent; missing approval creates/request paths instead of mass sending.
  - System announcements remain operational but are scoped to the sender organization and write audit records.
  - Admin broadcast UI now submits promos for approval instead of presenting them as immediate all-device pushes.
- Storage/realtime:
  - Removed legacy `storage_%` policies and JWT-role storage admin policies.
  - Recreated canonical avatar, media, promo-media, and ticket object policies.
  - Preserved current realtime app channels for chat, ride requests, driver locations, and ledger transactions while explicitly excluding sensitive payment/admin/campaign tables.
- Disabled BioPay transfer RPC stubs remain blocked and no longer produce unused-argument lint warnings.
- Verification:
  - `supabase db push --dry-run --linked`: found the pending migration.
  - `supabase db push --linked --yes`: applied `20260501120000_tenant_storage_campaign_final_hardening.sql`.
  - `supabase db lint --linked --schema public --fail-on error`: passed with no schema errors.
  - Backend security assertion union query returned zero failure rows.
  - Post-checks confirmed all public `organization_id` columns are `NO` nullable, storage policies no longer include `storage_%`, direct admin-role RLS queries return zero rows, and realtime still publishes only `chat_conversations`, `chat_messages`, `driver_locations`, `ride_requests`, and `transactions`.
  - `dart format lib/core/services/admin/admin_broadcast_service.dart lib/core/services/admin_service.dart lib/features/admin/admin_broadcasts_screen.dart`: passed.
  - `flutter analyze --no-fatal-infos --no-fatal-warnings`: no issues found.
  - `git diff --check`: passed.
- Verification caveat:
  - `flutter test test/core/services/admin_service_test.dart test/core/router/admin_session_guard_test.dart` could not complete in this session because the local Flutter SDK/filesystem setup crashed before running tests. From the repo volume it failed with `Operation not permitted` reading a source file; from a `/tmp` copy it failed inside Flutter shader compilation and SDK `dart:ui` setup. These are environment/toolchain failures, not assertion failures from the changed code.

## 2026-05-01 Campaign UI, Secret Rotation, and Periodic Audit Pass

- Added and deployed `20260501123000_campaign_approval_ui_contracts.sql`.
- Added and deployed `20260501124000_storage_media_bucket_limits.sql`.
- Added `rpc_admin_list_campaign_approvals` as the typed admin read contract for campaign approval queues.
- Expanded the admin broadcast surface from a composer-only screen into an operational promo approval queue:
  - Pending promos can be approved or rejected.
  - Approved promos can be sent through the existing consent-gated backend RPC.
  - Sent promos show recipient counts returned by the backend.
  - The queue has loading, empty, error, and action-busy states.
- Added `AdminCampaignApprovalItem` to shared admin DTOs and covered parsing in admin model tests.
- Added `docs/security/secret_rotation_runbook.md`.
- Added `scripts/qa/scan_secrets.sh` for repeatable committed-secret scans.
- Added `supabase/tests/storage_realtime_audit.sql` and `scripts/qa/audit_storage_realtime.sh` for repeatable storage/realtime exposure audits.
- Bounded the public `media` bucket with a 50 MB file limit and explicit image/video/PDF MIME allowlist so the storage audit returns cleanly.
- Secret rotation note:
  - Exposed Supabase credentials must be revoked/regenerated in the external Supabase account/project secret controls and then updated in CI/CD/runtime secret stores. Replacement secret values must not be committed or pasted into chat.
- Verification:
  - `supabase db push --linked --yes`: applied both new migrations.
  - Remote migration query confirms `20260501123000` and `20260501124000` are applied.
  - `supabase db lint --linked --schema public --fail-on error`: passed with no schema errors.
  - `scripts/qa/audit_storage_realtime.sh`: passed with no findings after bounding `media`.
  - `scripts/qa/scan_secrets.sh`: passed.
  - `flutter analyze --no-fatal-infos --no-fatal-warnings`: no issues found.
  - `flutter test test/core/services/admin_service_test.dart --plain-name AdminCampaignApprovalItem`: blocked by local Flutter/filesystem `Operation not permitted` before tests ran.
