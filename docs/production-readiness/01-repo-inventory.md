# MOBI Repo Inventory

> Historical snapshot: this 2026-05-06 inventory predates the 2026-05-23 Mobio
> limited-scope cleanup. Treat it as audit history only. Current production
> scope and release status are in `docs/product/scope.md`,
> `docs/reports/production-readiness-audit.md`, and
> `docs/release/go-no-go.md`. Legacy BioPay, payment, SMS ledger, and
> ride-request lifecycle references below are not approved active scope.

Date: 2026-05-06

## Repository State

- Git repo root: `/Volumes/PRO-G40/MOBI/mobi_app`
- Branch: `main`
- Head: `5d9c5dd feat: harden MOBI super app launch`
- Worktree before this pass was dirty with existing admin/campaign edits and untracked migrations/tests. Those changes were treated as user-owned and not reverted.

## App Boundaries

| Boundary | Current source of truth | Notes |
| --- | --- | --- |
| Flutter mobile | `lib/`, `android/`, `ios/`, `assets/`, `icon/`, `pigeons/` | Root Flutter package remains active runtime. |
| Flutter PWA/client | `lib/`, `web/`, `scripts/web/prepare_pwa_bundles.sh` | Generated to `build/pwa/client`. |
| Admin panel/PWA | `lib/features/admin`, admin routes in `lib/app/router/app_router.dart` | Embedded in the same Flutter app; generated to `build/pwa/admin`. |
| Public website | `landing/`, `firebase.json`, `.github/workflows/cloudflare-pages.yml` | Static marketing/privacy site. |
| Supabase backend | `supabase/config.toml`, `supabase/migrations`, `supabase/functions`, `supabase/tests`, `supabase/seed.sql` | Canonical backend source in this repo. |
| Local packages | `packages/design-system`, `packages/shared-types` | Path dependencies consumed by root Flutter app. The legacy `packages/payments` package has been removed from active scope. |
| CI/release/ops | `.github/workflows`, `scripts/ci`, `scripts/release`, `scripts/qa`, `scripts/web`, `infra/` | GitHub Actions plus local helper scripts. |

## Stack And Versions Detected

- Flutter/Dart package: `mobi_app`, Dart SDK constraint `^3.10.8`, Flutter dependencies in `pubspec.yaml`.
- Local Flutter packages: `mobi_design_system`, `mobi_shared_types`.
- Supabase CLI config: local Postgres major version 17, exposed schemas `public` and `graphql_public`, Edge runtime Deno 2.
- Deno installed locally: `2.7.5`.
- Supabase CLI installed locally: `2.90.0` with update notice to `2.98.2`.
- Node installed locally: `v25.9.0`.
- Android Gradle wrapper files exist locally, but `android/.gitignore` ignores `gradlew`, `gradlew.bat`, and `gradle-wrapper.jar`; only `gradle-wrapper.properties` is tracked.

## Key Runtime Dependencies

- Flutter state/navigation: `flutter_riverpod`, `go_router`.
- Backend/client: `supabase_flutter`, `dio`.
- Mobile platform: Firebase Core/Analytics/Crashlytics/Messaging/Remote
  Config/Auth plus location, notifications, app settings, and URL launch
  support. Camera, ML Kit Face Detection, TFLite, NFC, QR scanning, local auth,
  SMS ingestion, and payment-state dependencies were removed from the active
  Mobio package in the limited-scope cleanup.
- Google/Firebase API inventory: see `docs/reports/google_api_sdk_findings.md`.
  Needed Google Maps Platform APIs are Places API New and Geocoding API through
  the server-side `maps-gateway`. Google Routes API, Compute Route Matrix,
  Directions API, Distance Matrix API, route ETA/distance/polyline/matrix,
  fare-distance, and dispatch-grade routing are permanently out of context for
  this app.
- Web/PWA: Flutter web shell with generated service worker; Cloudflare Pages deploy scripts.
- Supabase functions: Deno, `npm:@supabase/supabase-js@2`, `jsr:@supabase/functions-js/edge-runtime.d.ts`, Google/Gemini integrations.

## Existing Validation Commands

- Flutter: `./scripts/ci/verify_flutter.sh`
- Backend: `./scripts/ci/verify_backend.sh`
- iOS release: `./scripts/ci/verify_ios_release.sh`
- Android release: `./scripts/release/build_android_release.sh appbundle|apk`
- Release config: `./scripts/ci/verify_release_config.sh`
- Secret scan: `./scripts/qa/scan_secrets.sh`
- PWA bundle prep: `./scripts/web/prepare_pwa_bundles.sh`
- Storage/realtime audit: `scripts/qa/audit_storage_realtime.sh`

## Deployment Targets

- Android Play Store: GitHub release workflow and Fastlane lanes.
- iOS: CI no-codesign release validation; full signed archive still needs human Apple environment.
- Public website: Firebase Hosting and Cloudflare Pages.
- Client/admin PWAs: Cloudflare Pages projects from `build/pwa/client` and `build/pwa/admin`.
- Supabase: migrations/functions in repo; linked security gates require `SUPABASE_ACCESS_TOKEN` and `SUPABASE_PROJECT_REF`.

## Must Not Be Changed Without Explicit Approval

- Root Flutter project layout and package boundaries; docs say runtime code must not move into `apps/` yet.
- Supabase destructive commands (`db reset`, production `db push`, destructive migrations).
- Product auth direction: passenger/driver WhatsApp OTP, admin WhatsApp OTP allowlist, Supabase/RLS as authority.
- Design tokens/style system in `design.md` and `packages/design-system`.
- User-owned uncommitted admin/campaign changes present before this pass.

## Duplicated, Deprecated, Or Unclear Areas

- `admin_audit_log` versus `admin_audit_logs` compatibility paths remain documented as a consolidation risk.
- BioPay/payment/SMS ledger migrations remain historical backend context, but a
  forward cleanup migration removes those objects on replay.
- Several late Supabase migrations appear to repair remote drift rather than define clean-checkout schema from first principles.
- Legacy Android ledger source trees were removed from the active app package.
- Static `apps/*` directories are boundary docs, not runtime apps.
