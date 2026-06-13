# Mobio Production Readiness Audit

Date: 2026-05-24
Repo: `/Volumes/PRO-G40/MOBI/mobi_app`

## Corrected Product Scope

Mobio is not a full ride-hailing or trip-management app. The approved scope is:
nearby discovery, profile/vehicle browsing, WhatsApp or in-app communication,
and scheduled trip posts. Fare negotiation is manual. The app must not expose
fare quotes, dispatch lifecycle, trip start/complete, driver earnings, refunds,
route tracking, BioPay trip settlement, or trip payment ledgers.

The canonical scope document is `docs/product/scope.md`.

## Repo Map

| Area | Current state |
| --- | --- |
| Flutter app | Root Flutter app in `lib`, already mostly feature-first: `admin`, `auth`, `bookings`, `chat`, `home`, `nearby`, `profile`; the Flutter BioPay, ledger, payments, and ride-request feature trees were removed from the active app package in this pass. |
| Admin panel | Flutter/admin routes under `lib/features/admin`; admin dashboard, users, vehicle types, trips, reports, health, audit, broadcasts. Finance/payment review is no longer linked from active admin navigation and `/admin/finance` resolves to a scope-unavailable screen. |
| Supabase schema | Migrations under `supabase/migrations`; current replay ends with forward cleanup that keeps active schema to `profiles`, `trips`, `driver_locations`, chat tables, reports/blocks, admin/audit, storage, notifications, and tenant/admin support tables. Legacy BioPay/payment/ledger/SMS and ride-request lifecycle tables are dropped by forward migrations. |
| Edge Functions | `supabase/functions`; includes OTP/login, chat assist, maps gateway, promo generation. Legacy-named BioPay/payment/SMS/admin transaction functions now return a 410 scope-unavailable response and do not mutate backend tables. |
| Auth | Supabase WhatsApp OTP login and admin session guard; route guards are in `lib/core/router/app_router.dart`. |
| RLS/storage tests | SQL assertions in `supabase/tests`; linked gates require Supabase credentials. |
| Nearby location | `DriverLocationService`, `LocationService`, `rpc_search_nearby_drivers`, `driver_locations`. |
| Scheduled trips | `TripService`, `bookings` screens, `schedule_trip_provider`, `trips` table/RPCs. |
| Chat/WhatsApp | `ChatService`, `features/chat`, WhatsApp login/handoff helpers. |
| Notifications | Firebase/Supabase notification services plus notification consent/admin campaign code. |
| Google/Firebase APIs | Current findings and needed API/SDK work are tracked in `docs/reports/google_api_sdk_findings.md`; route APIs are permanently out of context for Mobio. |
| CI/CD | GitHub Actions for CI, release, Cloudflare Pages/PWA; release depends on env vars and signing/Play secrets. |
| Android release | `rw.mobi.app`, target SDK 35, compile SDK 36, signing via `android/key.properties`; Play upload uses `PLAY_STORE_SERVICE_ACCOUNT_JSON`. |

## Out-Of-Scope Features Found

- BioPay Flutter hub, QR, scan, face enrollment, face scan, ML models, tests,
  and Android dependencies were removed from the active app package. The
  BioPay Edge Function entrypoint remains only as a 410 scope-unavailable
  handler; BioPay migration history remains.
- Payment intent/session Flutter models and local `packages/payments` were
  removed from the active app package. Legacy payment Edge Function entrypoints
  remain only as 410 scope-unavailable handlers; payment migration history
  remains.
- Native Android ledger/SMS ingestion code under `android/app/src/main/kotlin`
  was removed from the active app package.
- Historical `ride_requests`/`trip_requests` migrations remain in repository
  history, but the Flutter service, provider, model export, and shared sheet
  entrypoints were removed and the forward cleanup migration drops the live
  schema on replay.
- Admin finance/payment review surfaces and client risk-flag review APIs.
- Profile BioPay handle editing.
- Trip lifecycle `completed` state in active Flutter models/admin UI.
- Legacy payment-oriented documents remain in older `docs/architecture` and
  `docs/security` snapshots, but current release docs point to this audit and
  `docs/product/scope.md`.

## Fixes Applied In This Pass

- Replaced the active passenger bottom nav with Home / Trips / Profile.
- Removed BioPay as the second active tab and removed profile Face ID/Ledger
  entry points.
- Kept `/biopay*` and `/ledger` routes explicit but changed them to an
  unavailable notice explaining the current product scope.
- Removed native ledger credential sync from app session handling.
- Removed ride-request/request-offer buttons from active discovery and trips
  UI; nearby cards now expose chat/details only.
- Removed ride-request notification bottom sheet behavior from Home.
- Removed inactive Flutter ride-request lifecycle entry points:
  `RideRequestService`, `rideRequestServiceProvider`, `ride_request_sheet.dart`,
  and the app-level `ride_request.dart` model export.
- Changed trip details copy to manual coordination/fare negotiation and hid
  cancel from non-owners.
- Removed Android camera/SMS/boot permissions and SMS/boot receivers from the
  active manifest.
- Removed the Flutter BioPay, ledger, and payment feature trees, the
  `packages/payments` package, ML face-model assets, generated Pigeon ledger
  bridge, and native Android ledger/SMS source trees from the app package.
- Removed high-risk client dependencies for camera, QR scanning, NFC,
  biometrics/local auth, secure-storage payment state, TFLite/ML Kit face
  detection, image saving, and generated Pigeon ledger bindings from
  `pubspec.yaml`.
- Removed native Gradle dependencies for Room, WorkManager, SQLCipher,
  security crypto, native Supabase/Ktor/OkHttp ledger sync, Kotlin
  serialization, and KSP.
- Changed legacy-named backend functions for BioPay, payment intent creation,
  payment status verification, SMS parsing, MoMo SMS reconciliation, and admin
  transaction review to a shared 410 scope-unavailable response with no
  service-role database mutation path.
- Added `20260501134000_scope_cleanup_legacy_trip_payment_biopay.sql` to drop
  out-of-scope BioPay/payment/SMS ledger/ride-request schema objects, remove
  profile BioPay columns, remove the country SMS sender column, and remove the
  `admin.finance.review` platform permission. The routine cleanup uses a
  `pg_proc` lookup by legacy routine name so environments without pgvector
  argument types do not fail before `IF EXISTS`.
- Removed BioPay handle loading/saving from the active profile edit flow and
  deleted the unused profile BioPay widget.
- Removed the admin Finance tab from active admin navigation and changed
  `/admin/finance` to the same scope-unavailable notice used for legacy
  payment/BioPay routes.
- Added report/block foundations for in-scope marketplace safety:
  `user_blocks`, `user_reports`, report/block RPCs, block-aware chat creation,
  block-aware message insert policy, ChatService methods, and chat UI actions.
- Replaced active login/admin copy that referenced payments or Face ID with
  discovery, schedule, chat, profile, and driver-profile language.
- Added release-scope regression tests for restricted Android permissions,
  profile BioPay isolation, admin finance isolation, and login copy.
- Added report/block contract tests and linked-backend assertions covering
  report/block tables, RPCs, direct-write denial, and block-aware chat policy.
- Added an active admin Reports workspace at `/admin/reports` for listing,
  searching, marking reviewing, resolving, and dismissing `user_reports` through
  the guarded admin RPCs.
- Rewrote Google Play text metadata and regenerated Play screenshots so store
  assets describe nearby discovery, scheduled trip posts, profiles, chat,
  WhatsApp handoff, manual negotiation, reports/blocks, and privacy controls
  without advertising BioPay, payment, dispatch, or trip lifecycle features.
- Reworked the public landing/privacy/terms pages to match the corrected scope,
  added `landing/account-deletion.html`, exposed account deletion from the
  Profile screen, and made `ACCOUNT_DELETION_URL` a required release/PWA build
  define.
- Added `scripts/web/verify_public_site.sh` and wired it into the Cloudflare
  Pages workflow so public pages must include the limited-scope marketplace
  terms and reject stale payment, BioPay, ride-booking, and route-calculation
  claims before deployment.
- Replaced the landing-page copy of `mobi_icon.png` with the existing Android
  launcher-size PNG after Cloudflare Pages asset uploads repeatedly failed on
  the original 1024px icon. Production Pages deployment then succeeded on
  branch `main`.
- Updated general CI so it skips the signed release AAB step when Android
  signing secrets are unavailable instead of attempting an unsigned release
  build that Gradle correctly rejects.
- Tightened `scripts/qa/scan_secrets.sh` so the known high-risk
  `android/fastlane/play-store-service-account.json` path fails the scan if it
  reappears, even before content-pattern matching.
- Added `scripts/qa/check_secret_history.sh` so production readiness can
  explicitly prove the historical Play service-account JSON path has been
  purged from all Git refs after key rotation.
- Added `scripts/qa/preflight_secret_history_purge.sh`, a non-destructive
  safety check for the later Git history rewrite. It requires a full clone,
  clean working tree, absent credential file, and installed `git-filter-repo`
  before printing the purge command.
- Wired release config validation to optionally require a clean secret-history
  scan with `REQUIRE_SECRET_HISTORY_CLEAN=true`; the GitHub Release workflow
  now checks out full history and enables that gate.
- Tightened release config validation so `PLAY_STORE_SERVICE_ACCOUNT_JSON` must
  parse as service-account JSON with `client_email`, `private_key`, and
  `token_uri` fields before CI attempts a Play upload.
- Changed GitHub Actions and Fastlane Play uploads to default to the internal
  track and require `PLAY_PRODUCTION_APPROVED=true` before any production-track
  upload is accepted.
- Added the same `PLAY_PRODUCTION_APPROVED=true` guard to the Fastlane
  `promote_to_production` lane so production promotion cannot bypass the direct
  upload guard.
- Added `scripts/release/smoke_android_release.sh` to install a signed release
  APK on an authorized Android device, launch `rw.mobi.app`, verify the process
  stays running, and write smoke evidence under `build/reports/android-smoke/`.
  If the APK is missing and CI signing env vars are present, it now writes
  temporary signing files, builds the APK, and removes those signing files on
  exit.
- Added `scripts/release/go_no_go_check.sh`, a fail-closed production gate that
  aggregates Flutter verification, secret scans, secret-history proof, linked
  Supabase gates, release/signing config, Play service-account rotation
  acknowledgement plus evidence file, Play Console upload validation
  acknowledgement plus evidence file, Google Maps server-secret evidence, FCM
  HTTP v1 secret evidence, iOS Firebase/APNs and Crashlytics dSYM evidence when
  the release target includes iOS, and physical Android smoke.
- Disabled active scheduled-trip route computation after origin/destination
  selection. The UI now stores route labels and optional coordinates only, and
  chat/schedule copy frames fares and timing as manually agreed by users.
- Disabled backend/client route calculation surfaces: `PlacesService` no longer
  exposes `computeRoute`, and `maps-gateway` returns 410 for `compute_route`
  instead of calling Google Routes.
- Removed the leftover active `RouteInfo` DTO/export/state surface from the app
  and shared package, including generated route-info artifacts and obsolete
  route DTO unit tests. Scheduled trip posts now carry place labels and
  optional coordinates only.
- Cleaned active chat-assist and promo-generation prompts so suggestions and
  marketing assets stay inside profile discovery, scheduled trip posts, and
  manually agreed fare coordination.
- Recommendation boundary: Google Routes API, Compute Route Matrix, Directions
  API, Distance Matrix API, ETA/duration, route distance, route polyline,
  fare-distance basis, and dispatch-grade routing must not be recommended as
  production-readiness gaps, roadmap items, or Mobio implementation work. Their
  absence is intentional because those capabilities are out of context for this
  app.
- Added `docs/reports/google_api_sdk_findings.md` as the authoritative
  Google/Firebase API inventory. The needed implementation work is limited to
  Places/Geocoding gateway hardening, Firebase/FCM release evidence, and
  optional-infrastructure configuration; route APIs remain permanently excluded.
- Removed the inactive shared ride-request DTO export/files from
  `packages/shared-types`.
- Removed obsolete ProGuard/R8 keep rules for deleted TFLite, ML Kit face,
  camera, and QR scanner dependencies, and refreshed historical
  production-readiness docs so they defer to the current limited-scope audit.
- Added `deno.lock` and made `scripts/ci/verify_backend.sh` run Deno checks and
  tests with `--frozen --lock`, reducing Edge Function dependency drift risk.
- Updated `scripts/ci/verify_backend.sh` so linked gates can run with either
  `SUPABASE_PROJECT_REF + SUPABASE_ACCESS_TOKEN` or
  `SUPABASE_PROJECT_REF + SUPABASE_DB_PASSWORD`, matching the documented
  release gate.
- Wired `SUPABASE_DB_PASSWORD` into CI and release backend verification as the
  documented fallback when linked lint/query needs direct database access.
- Pinned GitHub Actions workflow dependencies to immutable commit SHAs and added
  `scripts/ci/check_github_actions_pinned.sh` as a CI guard.
- Expanded `.env.example` with public client config placeholders and explicit
  no-secret notes.
- Updated `AGENTS.md` with product-boundary and secret-handling rules.
- Added required production docs.
- Deleted the inactive admin finance review screen, removed client/admin risk
  flag review APIs and models, and extended release tests so those APIs cannot
  re-enter active admin code.
- Removed the active `completed` trip lifecycle state from shared trip models,
  admin trip filters, admin dashboard stats, and tests. Scheduled trip posts now
  expose active/cancelled state only in Flutter models.
- Replaced the stale schema inventory with a current limited-marketplace schema
  map and marked the older Supabase payment/BioPay backend audit as a
  historical snapshot.
- Added a release-scope regression test that requires historical docs to defer
  to the current limited-scope product/release documents.
- Patched the historical ledger migration so local replay drops incompatible
  pre-existing/sample ledger table shapes before recreating the temporary legacy
  schema needed by later historical payment migrations.
- Added
  `20260524001000_final_scope_cleanup_after_linked_history.sql`, a final
  forward cleanup that removes legacy ledger/SMS tables from realtime, drops the
  country SMS sender column, and normalizes linked-history admin policy/tenant
  drift when those objects exist.

## Security And Secrets

- `.env` is present locally but not tracked.
- `.env.example` is tracked and contains placeholders only.
- `android/fastlane/play-store-service-account.json` is deleted in the working
  tree, but it was tracked previously. Treat that key as compromised until it is
  rotated/revoked and Git history is purged.
- Supabase service-role keys appear only as environment variable names in server
  code/scripts, not as committed literal secrets in this pass.

## Supabase/RLS Audit

Observed coverage:

- `profiles` and `trips` have RLS policies and later hardening migrations.
- `driver_locations` has RLS and online-driver read policy.
- `chat_conversations` and `chat_messages` have participant RLS plus later
  read-receipt-only update hardening.
- `user_blocks` and `user_reports` now have organization-scoped tables, no
  direct client write grants, RPC-only user report/block actions, and admin
  report review RPCs guarded by `admin.reports.*` permissions.
- `backend_security_assertions.sql` checks broad profile select, anon trip
  access, payment grants, chat update grants, storage buckets, realtime exposure,
  platform permissions, tenant columns, report/block invariants, block-aware
  chat policies, and campaign/admin RPCs.
- `storage_realtime_audit.sql` checks storage policies, sensitive realtime
  exposure, realtime tables without RLS, and public bucket bounds.

Missing or not proven in this pass:

- Linked Supabase assertions were not run because `SUPABASE_ACCESS_TOKEN` and
  `SUPABASE_PROJECT_REF` were not available in the environment.
- The cached Supabase CLI session can list projects, but the project ref from
  the local `.env` is not visible in that project list. A read-only linked lint
  attempt against that ref failed with login-role status 403 and requested a
  valid `SUPABASE_DB_PASSWORD`.
- Local Supabase replay was validated through Docker Desktop's `desktop-linux`
  context after Colima failed with Lima/VZ disk attachment error `failed to run
  attach disk "colima", in use by instance "colima"`.
- `supabase start --ignore-health-check` applied all repository migrations and
  seeded after removing BioPay wallet/transaction seed rows and adding
  deterministic local auth users for the seeded profiles. The CLI still reports
  local Storage health as slow/unhealthy in this environment, but database
  replay and assertions are now proven separately.
- `supabase db reset --local` replayed every migration through
  `20260524001000_final_scope_cleanup_after_linked_history.sql` and seeded.
  The CLI exited nonzero only during the post-reset service health wait because
  local Storage was still `starting`; database lint and SQL assertions passed
  immediately afterward.
- A forward cleanup migration now removes legacy payment/BioPay/ledger/SMS and
  ride-request tables/functions; linked staging replay is still required before
  production.

## Validation Results

| Command | Result | Notes |
| --- | --- | --- |
| `dart format ...` | Passed | Formatted touched Dart files. |
| `scripts/qa/scan_secrets.sh` | Passed | No forbidden Play service-account JSON path and no committed secret patterns found. |
| `scripts/qa/check_secret_history.sh` | Passed after history rewrite | Rewritten Git refs no longer contain `android/fastlane/play-store-service-account.json`; the old exposed Play key still needs provider-side revoke/rotation evidence before production release. |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | Passed | No analyzer issues, including after deleting route-info source and generated files. |
| `flutter test` | Passed | 154 tests passed after adding backend schema-cleanup, report/block, release-scope, smoke-tooling, scheduled-trip no-route/no-fare, backend route-disablement, chat-assist, promo-prompt, shared-contract cleanup, historical-doc boundary coverage, secret-history purge preflight coverage, and removing obsolete route-calculation DTO tests. |
| `flutter test test/release/backend_scope_boundary_test.dart test/release/report_block_contract_test.dart test/release/scope_boundary_test.dart` | Passed | 25 release contract tests passed, including guards that legacy BioPay/payment/ledger packages are not shipped, stale ProGuard rules for deleted high-risk dependencies are absent, shared ride-request DTOs are absent, legacy-named backend functions are inert, cleanup migrations remove legacy schema objects, scheduled trip posts do not expose completed trip lifecycle state, scheduled trips and maps backend do not compute automatic routes or fares, Play/public website metadata stays within the marketplace scope, release builds require `ACCOUNT_DELETION_URL`, historical docs defer to current product scope, secret-history purge has a non-destructive preflight, and Play uploads default to internal validation with a production approval guard. |
| `SUPABASE_URL=... SUPABASE_ANON_KEY=... PRIVACY_POLICY_URL=... ACCOUNT_DELETION_URL=... FIREBASE_IOS_APP_ID=... ./scripts/ci/verify_release_config.sh` | Passed | Release config validation accepts the new account-deletion URL gate with dummy public URLs and no Android signing requirement. |
| `... PLAY_STORE_SERVICE_ACCOUNT_JSON=<dummy service-account json> REQUIRE_ANDROID_SIGNING=true ./scripts/ci/verify_release_config.sh` | Passed | Release config validation accepts structurally valid Play service-account JSON without printing secret values. |
| `... PLAY_STORE_SERVICE_ACCOUNT_JSON='{"type":"not_service_account"}' REQUIRE_ANDROID_SIGNING=true ./scripts/ci/verify_release_config.sh` | Failed as expected | Release config validation rejects malformed Play service-account JSON before upload. |
| `... PLAY_RELEASE_TRACK=production REQUIRE_ANDROID_SIGNING=true ./scripts/ci/verify_release_config.sh` | Failed as expected | Production-track Play uploads are blocked unless `PLAY_PRODUCTION_APPROVED=true` is set. |
| `... PLAY_RELEASE_TRACK=production PLAY_PRODUCTION_APPROVED=true REQUIRE_ANDROID_SIGNING=true ./scripts/ci/verify_release_config.sh` | Passed | Production-track validation is allowed only with the explicit approval flag. |
| `... PLAY_RELEASE_TRACK=gamma REQUIRE_ANDROID_SIGNING=true ./scripts/ci/verify_release_config.sh` | Failed as expected | Unknown Play tracks are rejected before upload. |
| `... REQUIRE_SECRET_HISTORY_CLEAN=true ./scripts/ci/verify_release_config.sh` | Failed as expected | Release config validation now fails closed on the known historical Play service-account JSON path until Git history is purged. |
| `deno check supabase/functions/chat-assist/index.ts supabase/functions/generate-promo-content/index.ts supabase/functions/maps-gateway/index.ts` | Passed | Edited Edge Functions type-check after chat-assist, promo-prompt, and route-disablement changes. |
| `scripts/ci/check_github_actions_pinned.sh` | Passed | All GitHub Actions `uses:` references in `.github/workflows` are pinned to 40-character commit SHAs. |
| `flutter test test/release/scope_boundary_test.dart` | Passed | Scope boundary sub-suite passed after adding ProGuard, shared-package, full-history secret gate, release workflow, and Fastlane production-promotion guards. |
| `flutter test test/services/places_service_test.dart test/features/bookings/models/schedule_trip_state_test.dart test/release/scope_boundary_test.dart` | Passed | Targeted route-scope cleanup tests passed after removing the obsolete `RouteInfo` DTO/state surface. |
| `dart format test/release/scope_boundary_test.dart` | Passed | Formatted the added historical-doc release boundary test. |
| `bash -n scripts/qa/preflight_secret_history_purge.sh scripts/qa/check_secret_history.sh scripts/qa/scan_secrets.sh` | Passed | Secret-scan and history-purge helper scripts parse. |
| `bash -n scripts/release/go_no_go_check.sh` | Passed | Production go/no-go gate parses. |
| `RUN_FLUTTER_GATE=false RUN_ANDROID_SMOKE=false ./scripts/release/go_no_go_check.sh` | Failed as expected | Production go/no-go skips are not allowed unless `GO_NO_GO_DRY_RUN=true` is set. |
| `GO_NO_GO_DRY_RUN=true RUN_FLUTTER_GATE=false RUN_ANDROID_SMOKE=false ./scripts/release/go_no_go_check.sh` | Failed as expected | Aggregate no-go gate allows Flutter/device skips only in dry-run mode and still refuses production approval with `NO-GO: dry-run mode cannot approve production`. After history rewrite, remaining hard blockers are linked Supabase credentials, release config env, Play service-account retention/upload validation acknowledgement, and required non-template Play evidence file paths. |
| `GO_NO_GO_DRY_RUN=true RUN_FLUTTER_GATE=false RUN_ANDROID_SMOKE=false PLAY_SERVICE_ACCOUNT_RETAINED=true PLAY_CONSOLE_UPLOAD_VALIDATED=true ./scripts/release/go_no_go_check.sh` | Failed as expected | Aggregate no-go gate rejects Play acknowledgements unless `PLAY_SERVICE_ACCOUNT_RETENTION_EVIDENCE` and `PLAY_CONSOLE_UPLOAD_EVIDENCE` point to existing files. |
| `GO_NO_GO_DRY_RUN=true RUN_FLUTTER_GATE=false RUN_ANDROID_SMOKE=false PLAY_SERVICE_ACCOUNT_RETAINED=true PLAY_SERVICE_ACCOUNT_RETENTION_EVIDENCE=docs/release/evidence/play-service-account-retention.example.md PLAY_CONSOLE_UPLOAD_VALIDATED=true PLAY_CONSOLE_UPLOAD_EVIDENCE=docs/release/evidence/play-console-upload.example.md ./scripts/release/go_no_go_check.sh` | Failed as expected | Aggregate no-go gate rejects committed `*.example.md` templates as production evidence. |
| `scripts/qa/preflight_secret_history_purge.sh` | Blocked as expected | Current shell does not have `git-filter-repo`, so the destructive history purge is not ready to run here. This is safer than attempting a rewrite from the dirty shared worktree. |
| `./scripts/ci/verify_backend.sh` | Passed with linked gates skipped | Secret scan, frozen-lock Deno checks, BioPay scope-unavailable tests, and OTP security tests passed. Linked Supabase gates skipped because `SUPABASE_PROJECT_REF` plus `SUPABASE_ACCESS_TOKEN` or `SUPABASE_DB_PASSWORD` were not available. CI/release workflows now pass both linked credential options when configured. |
| `REQUIRE_LINKED_SUPABASE=true ./scripts/ci/verify_backend.sh` | Failed as expected | Local Deno checks/tests passed, then the script exited nonzero because linked credentials were incomplete. This proves the linked gate can be made mandatory in release contexts. |
| `supabase db lint --linked --schema public --fail-on error` | Blocked | With the project ref from local `.env`, the cached Supabase CLI session returned login-role status 403 and required `SUPABASE_DB_PASSWORD`; no linked database checks were run. |
| `colima start` | Blocked | Lima/VZ failed before Docker startup with `failed to run attach disk "colima", in use by instance "colima"`. |
| `DOCKER_CONTEXT=desktop-linux supabase start --ignore-health-check` | Passed with service-health caveat | Local migrations and seed completed after seed cleanup; CLI required `--ignore-health-check` because local Storage health was slow/degraded. |
| `DOCKER_CONTEXT=desktop-linux supabase db reset --local` | Database replay passed; CLI health check failed | All migrations replayed through `20260524001000_final_scope_cleanup_after_linked_history.sql` and seed ran. The command exited nonzero only after restart because `supabase_storage_MOBI` was still `starting` at the health-check deadline; database lint/assertions passed afterward. |
| `DOCKER_CONTEXT=desktop-linux supabase db lint --local --fail-on error` | Passed | No schema lint errors after dropping legacy BioPay rate-limit routines and qualifying OTP rate-limit updates. |
| `psql ... -f supabase/tests/backend_security_assertions.sql` | Passed | Backend security assertions passed against the freshly replayed local database. |
| `psql ... -f supabase/tests/storage_realtime_audit.sql` | Passed | Storage/realtime audit returned zero findings. |
| `scripts/web/verify_public_site.sh landing` | Passed | Public site source includes nearby discovery, scheduled trip posts, WhatsApp handoff, account deletion, no in-app ride payments, and no automatic fare quotes; stale payment/BioPay/ride-booking claims are rejected. |
| route/fare scope source scan | Passed | `schedule_trip_provider.dart` and `PlacesService` no longer call/expose `computeRoute`; the app/shared package no longer ships `RouteInfo` or `route_info.dart`; `maps-gateway` returns 410 for `compute_route`; active trip-post UI states that Mobio stores route labels/optional coordinates only and that fares/timing are agreed manually in chat or WhatsApp. |
| `npx wrangler pages deploy landing --project-name=mobio --branch=main --commit-dirty=true` | Passed | Production Pages deployment completed after replacing the problematic 1024px landing icon with the Android launcher-size PNG. |
| `curl -L https://mobio.ikanisa.com/{,privacy-policy,account-deletion,terms-and-conditions}` content scan | Passed | Live custom-domain pages contain the corrected limited-scope terms and no `biopay`, biometric payment, instant payment, MoMo, route-calculation, ride-booking, start-ride, or payment-options claims. |
| `scripts/release/build_android_release.sh appbundle` | Passed | Signed release AAB built at `build/app/outputs/bundle/release/app-release.aab` in 1059.7s; artifact size was 55.1 MB in Flutter output and 55,058,166 bytes on disk. |
| `shasum -a 256 build/app/outputs/bundle/release/app-release.aab` | Passed | Release AAB SHA-256: `ce11278526a031ffa233b9c81988f0c2ce17919796175d101b8fe0688bff67f9`. |
| `jarsigner -verify -strict build/app/outputs/bundle/release/app-release.aab` | Warned | JAR structure verified, but `-strict` exits nonzero because the local upload certificate is self-signed and lacks a timestamp. This is expected for an Android upload key artifact check, but Play upload validation is still required. |
| `scripts/release/build_android_release.sh apk` | Passed | Signed release APK built at `build/app/outputs/flutter-apk/app-release.apk` in 480.7s; artifact size was 68.3 MB in Flutter output and 68,361,609 bytes on disk. |
| `shasum -a 256 build/app/outputs/flutter-apk/app-release.apk` | Passed | Release APK SHA-256: `862f9d989d32750fd229c35e3286c2ae76f24adab6f43ccda5fbacd93710d4df`. |
| `apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk` | Passed | APK verifies with APK Signature Scheme v2 and signer certificate `CN=MOBI Rwanda, OU=Mobile, O=MOBI, L=Kigali, ST=Kigali, C=RW`. |
| `adb devices` | Blocked | No physical Android device or emulator was attached, so release install/launch smoke could not be run. |
| `bash -n scripts/release/smoke_android_release.sh` | Passed | Android release smoke script parses after adding temporary signing-file creation/cleanup for CI env-based release smoke. Runtime smoke still requires an authorized device. |
| `scripts/release/smoke_android_release.sh` | Blocked as expected | Script failed cleanly with no authorized Android device attached and printed the `adb devices` state. |
| `ruby -c android/fastlane/Fastfile` | Passed | Fastlane file syntax is valid after adding internal-track defaults, direct production upload approval, and production promotion approval guard. |
| `bash -n scripts/qa/check_secret_history.sh` | Passed | Secret-history gate parses. |
| `git diff --check` | Passed | No whitespace errors. |
| `./gradlew :app:assembleDebug` | Passed | Debug APK built successfully after removing native ledger code and high-risk dependencies. |

## Production Blockers

1. Rotate/revoke the previously tracked Play service-account JSON in Google
   Cloud/Play Console and store the replacement only in CI secret storage. The
   Git history purge is complete for current refs and
   `scripts/qa/check_secret_history.sh` now passes, but provider-side revocation
   evidence is still external.
2. Provide privileged linked Supabase access, or `SUPABASE_DB_PASSWORD`, and run
   linked lint/storage/RLS gates against the intended staging or production
   project.
3. Smoke the signed release AAB on a physical Android device and validate Play
   Console upload.
4. Replay and apply the legacy BioPay/payment/ledger/SMS/ride-request schema
   cleanup migration against linked staging, then rerun linked security
   assertions.

## Roadmap

| Priority | Task | File paths | Acceptance criteria |
| --- | --- | --- | --- |
| P0 | Credential cleanup | `android/fastlane/play-store-service-account.json`, repo history, Play Console, `scripts/qa/preflight_secret_history_purge.sh`, `scripts/qa/check_secret_history.sh` | Git history purge is complete and both `scripts/qa/scan_secrets.sh` and `scripts/qa/check_secret_history.sh` pass. Remaining acceptance criteria: old key revoked in Google Cloud/Play Console, replacement key stored only in CI secret storage, and non-template evidence recorded. |
| P0 | Linked backend validation | `scripts/ci/verify_backend.sh`, `supabase/tests/*.sql` | Run with `SUPABASE_PROJECT_REF` plus `SUPABASE_ACCESS_TOKEN` or `SUPABASE_DB_PASSWORD`; linked gates pass or produce filed blockers with exact SQL failures. |
| P0 | Release smoke | `scripts/release/build_android_release.sh`, Android device | Signed AAB installs, launches, logs in, nearby/schedule/chat work. |
| P0 | Final go/no-go gate | `scripts/release/go_no_go_check.sh`, `docs/release/evidence/*.example.md` | Gate passes with linked Supabase credentials, release signing/Play secrets, revoked/rotated Play key acknowledgement plus non-template evidence file, Play Console validation acknowledgement plus non-template evidence file, Google Maps server-secret evidence, FCM HTTP v1 evidence, iOS Firebase/APNs/dSYM evidence when applicable, and physical Android smoke evidence. |
| P0 | Legacy schema cleanup replay | `supabase/migrations/20260501134000_scope_cleanup_legacy_trip_payment_biopay.sql`, `supabase/tests/backend_security_assertions.sql` | Migration replay is now proven locally through Docker Desktop; linked staging replay and assertions pass without breaking current profile, nearby discovery, scheduled trips, chat, reports/blocks, admin moderation, storage, or notification gates. Current regression tests cover manifest, active profile edit, admin finance navigation, login copy, removed Flutter ride-request lifecycle entry points, removed Flutter/native BioPay/payment/ledger package code, inert legacy-named Edge Functions, and cleanup-migration intent. |
| P1 | Report/block | `lib/features/chat`, `lib/features/admin/admin_reports_screen.dart`, `supabase/migrations/20260501133000_user_reports_blocks.sql`, `supabase/tests/backend_security_assertions.sql`, `test/release/report_block_contract_test.dart` | Users can report/block from chat; blocked users cannot create/open/send chat; admins can review reports through `/admin/reports`; linked RLS assertions pass against staging/production. |
| P1 | Scope docs cleanup | `docs/architecture/*`, `docs/security/*`, `docs/production-readiness/*`, `docs/product/*`, `supabase/docs/*` | Current schema inventory describes the limited marketplace schema; older BioPay/payment/ledger/ride-request audit documents are marked as historical snapshots and point back to current scope. Release tests guard the highest-risk doc entry points. |

## Go/No-Go

No-go for production on 2026-05-24. This pass removes additional active
scope-drift surfaces, including the Flutter/native BioPay/payment/ledger app
package code and live legacy Edge Function mutation paths. Signed AAB/APK
artifacts now build locally, but production still requires credential
remediation, linked backend validation, linked replay of the legacy schema
cleanup migration, Play Console upload validation, and physical-device smoke.
