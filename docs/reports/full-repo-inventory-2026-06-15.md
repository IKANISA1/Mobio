# Full Repo Inventory - 2026-06-15

This inventory is the current source map for the full production-readiness goal. Historical inventories under `docs/production-readiness/` remain useful context, but this file is the active inventory for the 2026-06-15 phased audit.

## Repository State

- Repo root: `/Volumes/PRO-G40/MOBI/mobi_app`.
- Branch: `main`.
- Current baseline before this audit phase: `c458446 Finalize Mobio v14 production gate evidence`.
- Current worktree contains active uncommitted changes in Mo Mobio SMS and profile/Driver Plus areas plus new audit workpapers. These are treated as current state until committed or explicitly deferred.

## Executable Surfaces

| Surface | Paths | Runtime / deployment | Notes |
| --- | --- | --- | --- |
| Mobio Flutter app | `lib/`, `android/`, `ios/`, `web/`, `assets/` | Android, iOS, Flutter web/PWA | Main product app. BioPay is a Mobio feature, not a separate app identity. |
| Admin panel/PWA | `lib/features/admin/**`, admin routes in `lib/core/router/app_router.dart`, `scripts/web/**` | Embedded Flutter admin workspace, PWA bundle/deploy scripts | Shares app package and Supabase backend. Guarded by admin OTP/session/role boundaries. |
| Mo Mobio SMS utility app | `apps/momobio_sms_bridge/**` | Private Android office-phone app | Internal utility that receives new MoMo SMS and uploads raw SMS to Supabase. Not a Play Store public app. |
| Supabase backend | `supabase/migrations/**`, `supabase/functions/**`, `supabase/tests/**`, `supabase/config.toml`, `supabase/seed.sql` | Linked Supabase project plus local Deno/SQL validation | 80 SQL migrations detected. Edge Functions include active Mobio functions and legacy/scope-boundary functions. |
| Local design package | `packages/design-system/**` | Path dependency consumed by Flutter app | Shared theme/tokens/widgets. |
| Compatibility local package | `packages/lucide_icons_compat/**` | Path override | Lucide compatibility dependency used by app. |
| Release/QA scripts | `scripts/ci/**`, `scripts/qa/**`, `scripts/release/**`, `scripts/web/**`, `scripts/validate-momobio-sms-bridge.mjs` | Local and CI release gates | Includes Flutter/backend gates, release config, Android smoke, BioPay readiness, SMS utility validator, PWA scripts. |
| Evidence/docs | `docs/release/evidence/**`, `docs/reports/**`, `docs/product/**`, `docs/production-readiness/**` | Audit artifacts | Older evidence may be superseded by newer scope decisions; current register controls final status. |

## Active Route Inventory

Current active paths in `lib/core/router/app_router.dart`:

- App shell/config/auth: `/config-error`, `/login`, `/`.
- Core Mobio: `/nearby`, `/bookings`, `/schedule`, `/trip/:id`, `/trip/:id/edit`, `/chat`, `/notifications`, `/profile`, `/edit-profile`, `/profile/setup`.
- Wallet/subscription: `/wallet`, `/mobio-plus`, `/ledger` (scope-unavailable).
- BioPay feature: `/biopay`, `/biopay/qr`, `/biopay/scan`, `/biopay/face-scan`, `/biopay/enroll`, `/biopay/nfc`, `/biopay/nfc/write-card`.
- Admin: `/admin`, `/admin-auth`, `/admin/users`, `/admin/profile`, `/admin/vehicle-types`, `/admin/agencies`, `/admin/subscriptions`, `/admin/trips`, `/admin/reports`, `/admin/biopay`, `/admin/finance` redirect, `/admin/health`, `/admin/audit`, `/admin/broadcasts`.

Detailed route workpaper: `docs/reports/route-screen-matrix-2026-06-15.md`.

## Backend Inventory

Supabase source areas:

- Edge Functions: `_shared`, `admin-review-transaction`, `biopay-api`, `biopay-face-provider`, `create-payment-intent`, `generate-promo-content`, `maps-gateway`, `momobio-sms-ingest`, `parse-sms`, `reconcile-momo-sms`, `send-login-otp`, `send-otp`, `send-push`, `verify-login-otp`, `verify-otp`, `verify-payment-status`.
- SQL migrations: 80 migration files detected in `supabase/migrations`.
- SQL tests: `supabase/tests/backend_security_assertions.sql`, `supabase/tests/storage_realtime_audit.sql`.
- Deno tests exist for BioPay, maps gateway, OTP security, phone, WhatsApp Cloud, and shared MoMo SMS parsing helpers.

## QA Commands Verified In This Phase

| Command | Result | Notes |
| --- | --- | --- |
| `node scripts/validate-momobio-sms-bridge.mjs` | Passed | Validates private SMS utility app scope, Supabase bridge contract, and no device-side filtering/backfill markers. |
| `/Volumes/PRO-G40/flutter_3_44/bin/flutter test --no-pub test/release/profile_verified_contact_contract_test.dart test/release/wallet_driver_plus_contract_test.dart` | Passed | Verifies authenticated WhatsApp is read-only, plus wallet/tokens/subscriptions/Mobio Plus contracts. |
| `JAVA_HOME=... ANDROID_HOME=/Volumes/PRO-G40/AppData/android/sdk ANDROID_SDK_ROOT=/Volumes/PRO-G40/AppData/android/sdk android/gradlew -p apps/momobio_sms_bridge --no-daemon --no-watch-fs -Dorg.gradle.workers.max=1 :app:compileDebugKotlin` | Passed | Verifies Mo Mobio SMS app compiles after removing `READ_SMS` and inbox backfill. |
| `/Volumes/PRO-G40/flutter_3_44/bin/flutter analyze` | Passed | Verifies current Flutter code compiles and has no analyzer issues. |

## Current Inventory Risks

- Older Mo Mobio SMS QA evidence folders still contain historical `READ_SMS` proof. These are superseded by `apps/momobio_sms_bridge/qa/new-incoming-only-uat-20260615-0018/` and must not be used as current scope evidence.
- Admin/PWA and iOS proof are not refreshed in this phase yet.
- Security scan work has not reached the full Codex Security phase sequence yet; current evidence is release-gate secret scans and targeted contract checks only.

