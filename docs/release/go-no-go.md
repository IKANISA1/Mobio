# Go/No-Go

Last updated: 2026-05-24

## Verdict

No-go for Google Play production today.

The app is closer to the corrected Mobio scope after this pass. Active profile
editing no longer loads or saves BioPay handles, active admin navigation no
longer exposes Finance/payment review, release-scope regression tests guard
those boundaries, and chat now has report/block actions backed by
organization-scoped Supabase tables/RPCs with an active admin Reports queue.
Scheduled-trip origin/destination selection now stores route labels and
optional coordinates only; active UI no longer computes automatic route
distance, duration, or fares. The client route helper was removed and
`maps-gateway` now rejects `compute_route` with a 410 scope response. The
inactive finance review screen/client APIs and completed trip lifecycle state
were also removed from active code. The schema inventory now reflects the
limited marketplace schema, and a release regression test guards the highest
risk historical docs so payment/BioPay/SMS/ride-request snapshots defer to the
current product scope. The leftover `RouteInfo` DTO/state/export surface is now
removed from active app/shared code, so scheduled trip posts carry place labels
and optional coordinates only. A non-destructive secret-history purge preflight
now exists for the later Git history rewrite. Local Supabase replay now reaches
the final scope cleanup migration and passes backend/storage assertions.
Production release still needs linked Supabase validation, physical-device
smoke testing, credential rotation/history cleanup for the previously tracked
Play service account, and Play Console upload validation.

## Passed In This Pass

- `scripts/qa/scan_secrets.sh`: passed; it now fails if the old Play
  service-account JSON path reappears.
- `scripts/qa/check_secret_history.sh`: failed as expected; Git history still
  contains `android/fastlane/play-store-service-account.json` in commit
  `b10e74f` from 2026-03-27. This makes the credential-history blocker
  repeatable and auditable.
- `scripts/qa/preflight_secret_history_purge.sh`: added as a non-destructive
  check for the later history rewrite. It currently fails before any rewrite
  because `git-filter-repo` is not installed in this shell.
- The GitHub Release workflow now checks out full history and sets
  `REQUIRE_SECRET_HISTORY_CLEAN=true`, so release config validation fails
  closed until the Play service-account history purge is complete.
- `./scripts/ci/verify_release_config.sh` now validates that
  `PLAY_STORE_SERVICE_ACCOUNT_JSON` is structurally valid service-account JSON
  before CI attempts a Play upload. Dummy positive and negative checks passed.
- GitHub Actions and Fastlane Play uploads now default to the internal track.
  Production-track uploads are blocked unless `PLAY_PRODUCTION_APPROVED=true`
  is set; validation passed for the approved path and failed as expected without
  the approval flag. Fastlane `promote_to_production` now uses the same explicit
  production approval guard.
- `flutter analyze --no-fatal-infos --no-fatal-warnings`: passed.
- `flutter test`: passed, 154 tests. The count dropped because obsolete
  `RouteInfo` route-calculation DTO tests were removed with the DTO itself.
- `flutter test test/release/backend_scope_boundary_test.dart test/release/report_block_contract_test.dart test/release/scope_boundary_test.dart`:
  passed, 25 release contract tests, including the scheduled-trip/maps no
  automatic route/fare guard, completed trip lifecycle guard, and shared
  ride-request DTO cleanup guard. The suite now also guards that historical
  schema/backend audit docs defer to current limited-scope release documents
  and that the secret-history purge has a non-destructive preflight.
- Google Play text metadata and phone screenshots were rewritten to match the
  limited marketplace/discovery scope and remove stale BioPay/payment/trip
  lifecycle claims.
- Public landing, privacy, terms, and account-deletion pages now match the
  limited marketplace/discovery scope. The Profile screen links account deletion
  when `ACCOUNT_DELETION_URL` is supplied.
- Scheduled-trip UI now states that Mobio stores route labels and optional
  coordinates only. Fare and timing are manually agreed by users in chat or
  WhatsApp.
- The obsolete `RouteInfo` model/export/state surface and generated route-info
  artifacts were removed from active app/shared code.
- `PlacesService` no longer exposes route computation, `maps-gateway` returns
  410 for `compute_route`, chat assist suggests manually agreed fares, and promo
  generation no longer contains face-scan/cashless-payment imagery prompts.
- Obsolete ProGuard/R8 keep rules for deleted TFLite, ML Kit face, camera, and
  QR scanner dependencies were removed; release-scope tests now guard those
  rules from reappearing.
- `deno.lock` is now present and backend verification runs Deno checks/tests
  with `--frozen --lock`, so Edge Function dependency drift fails CI.
- GitHub Actions workflow dependencies are pinned to immutable commit SHAs, with
  `scripts/ci/check_github_actions_pinned.sh` guarding future workflow edits.
- `scripts/web/verify_public_site.sh landing`: passed, and the Cloudflare Pages
  workflow now runs this scope verifier before deploy.
- `npx wrangler pages deploy landing --project-name=mobio --branch=main --commit-dirty=true`:
  passed after replacing the problematic 1024px landing icon with the existing
  Android launcher-size PNG.
- Live checks passed for `https://mobio.ikanisa.com/`,
  `https://mobio.ikanisa.com/privacy-policy`,
  `https://mobio.ikanisa.com/account-deletion`, and
  `https://mobio.ikanisa.com/terms-and-conditions`: required limited-scope terms
  are present and stale payment/BioPay/ride-booking terms are absent.
- `scripts/release/build_android_release.sh appbundle`: passed. A signed release
  AAB was built at `build/app/outputs/bundle/release/app-release.aab`
  (55,058,166 bytes, SHA-256
  `ce11278526a031ffa233b9c81988f0c2ce17919796175d101b8fe0688bff67f9`).
- `scripts/release/build_android_release.sh apk`: passed. A signed release APK
  was built at `build/app/outputs/flutter-apk/app-release.apk` (68,361,609
  bytes, SHA-256
  `862f9d989d32750fd229c35e3286c2ae76f24adab6f43ccda5fbacd93710d4df`) for
  physical-device smoke.
- `apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk`:
  passed with APK Signature Scheme v2.
- `jarsigner -verify -strict build/app/outputs/bundle/release/app-release.aab`:
  JAR structure verified, but strict verification exits nonzero because the
  local upload certificate is self-signed and untimestamped. Play Console upload
  validation is still required.
- `adb devices`: no attached devices, so physical-device release smoke was not
  run.
- Added `scripts/release/smoke_android_release.sh` to make the remaining
  Android device smoke gate repeatable once an authorized device is attached.
  If a release APK is missing and CI signing env vars are present, it now writes
  temporary signing files, builds the APK, and cleans those signing files on
  exit. Running it now fails cleanly because no authorized device is attached.
- Added `scripts/release/go_no_go_check.sh` as the final fail-closed production
  gate. It aggregates local verification, secret-history proof, linked Supabase
  checks, release/signing config, Play key rotation acknowledgement plus
  evidence file, Play Console upload acknowledgement plus evidence file, and
  physical Android smoke.
- `RUN_FLUTTER_GATE=false RUN_ANDROID_SMOKE=false ./scripts/release/go_no_go_check.sh`:
  failed immediately as expected because production go/no-go skips require
  explicit dry-run mode.
- `GO_NO_GO_DRY_RUN=true RUN_FLUTTER_GATE=false RUN_ANDROID_SMOKE=false ./scripts/release/go_no_go_check.sh`:
  failed as expected. The aggregate gate allows Flutter/device skips only in
  dry-run mode and still refuses production approval with
  `NO-GO: dry-run mode cannot approve production`. In this shell it also
  reported the hard blockers: historical Play credential still in Git history,
  linked Supabase credentials incomplete, release config env absent, Play key
  rotation/upload validation not acknowledged, and required Play evidence file
  paths absent.
- `GO_NO_GO_DRY_RUN=true RUN_FLUTTER_GATE=false RUN_ANDROID_SMOKE=false PLAY_SERVICE_ACCOUNT_ROTATED=true PLAY_CONSOLE_UPLOAD_VALIDATED=true ./scripts/release/go_no_go_check.sh`:
  failed as expected because `PLAY_SERVICE_ACCOUNT_ROTATION_EVIDENCE` and
  `PLAY_CONSOLE_UPLOAD_EVIDENCE` were not set to existing files.
- `GO_NO_GO_DRY_RUN=true RUN_FLUTTER_GATE=false RUN_ANDROID_SMOKE=false PLAY_SERVICE_ACCOUNT_ROTATED=true PLAY_SERVICE_ACCOUNT_ROTATION_EVIDENCE=docs/release/evidence/play-service-account-rotation.example.md PLAY_CONSOLE_UPLOAD_VALIDATED=true PLAY_CONSOLE_UPLOAD_EVIDENCE=docs/release/evidence/play-console-upload.example.md ./scripts/release/go_no_go_check.sh`:
  failed as expected because the gate rejects committed `*.example.md` templates
  as production evidence.
- `./scripts/ci/verify_release_config.sh` now requires `ACCOUNT_DELETION_URL`
  and passed with dummy public URLs. With
  `REQUIRE_SECRET_HISTORY_CLEAN=true`, it fails as expected on the known
  historical Play service-account JSON path.
- `./scripts/ci/verify_backend.sh`: passed local secret scan, Deno checks, and
  Deno tests with the frozen lockfile; linked Supabase gates skipped because
  `SUPABASE_PROJECT_REF` plus `SUPABASE_ACCESS_TOKEN` or
  `SUPABASE_DB_PASSWORD` were not present. CI and release workflows now pass
  both linked credential options when configured.
- `REQUIRE_LINKED_SUPABASE=true ./scripts/ci/verify_backend.sh`: failed as
  expected after local Deno checks/tests because linked credentials were
  incomplete. This confirms the linked gate can be enforced in release
  contexts.
- `deno check supabase/functions/chat-assist/index.ts supabase/functions/generate-promo-content/index.ts supabase/functions/maps-gateway/index.ts`:
  passed for the edited Edge Functions.
- `supabase db lint --linked --schema public --fail-on error`: blocked. The
  cached Supabase CLI session can list projects, but the local Mobio project ref
  returned login-role status 403 and requires `SUPABASE_DB_PASSWORD` or
  privileged linked access.
- `colima start`: blocked by Lima/VZ disk attachment error `failed to run attach
  disk "colima", in use by instance "colima"`.
- `DOCKER_CONTEXT=desktop-linux supabase start --ignore-health-check`: applied
  all repository migrations and seeded the local database after seed cleanup,
  with local Storage health caveats.
- `DOCKER_CONTEXT=desktop-linux supabase db reset --local`: replayed all
  migrations through
  `20260524001000_final_scope_cleanup_after_linked_history.sql` and seeded. The
  CLI exited nonzero only during the post-reset health wait because local
  Storage was still starting at the deadline; database checks passed afterward.
- `DOCKER_CONTEXT=desktop-linux supabase db lint --local --fail-on error`:
  passed.
- `psql ... -f supabase/tests/backend_security_assertions.sql`: passed.
- `psql ... -f supabase/tests/storage_realtime_audit.sql`: passed with zero
  findings.
- Direct schema checks confirmed `transactions`, `sms_raw_queue`,
  `biopay_profiles`, `payment_intents`, `ride_requests`, and `trip_requests`
  are absent from the final local schema and absent from realtime; the country
  `sender_id` column is absent.
- `git diff --check`: passed.
- `./gradlew :app:assembleDebug`: passed.

## Production Blockers

- Previously tracked `android/fastlane/play-store-service-account.json` requires
  key rotation/revocation and Git history purge. The new
  `scripts/qa/check_secret_history.sh` gate and release config history gate
  currently fail on commit `b10e74f`, so this blocker is still active.
  `scripts/qa/preflight_secret_history_purge.sh` also shows `git-filter-repo`
  is missing from the current shell.
- Linked Supabase RLS/storage/realtime assertions were not run in this pass; the
  local Mobio project ref is not accessible with the cached Supabase CLI account.
- Signed Android AAB/APK builds locally, but the build has not been installed or
  smoke tested on a physical device and has not been validated by Play Console
  upload.
- Flutter/native BioPay/payment/ledger app package code has been removed and
  forward schema cleanup migrations now drop legacy BioPay/payment/SMS
  ledger/ride-request objects. Local replay is now proven through Docker
  Desktop through the final cleanup migration; linked staging replay and linked
  assertions are still required.
  Legacy-named Edge Functions now return 410 and do not mutate payment, SMS,
  ledger, or BioPay tables.
- Report/block user UX, backend contract, and active admin moderation workspace
  are implemented locally; linked Supabase RLS assertions still need final
  verification before production.
- Privacy policy and account deletion paths are deployed and live-verified on
  the production custom domain; keep this as a release gate before each Play
  submission.

## Next PR Tasks

| Task | Files | Acceptance criteria |
| --- | --- | --- |
| Replay legacy schema cleanup migration on staging | `supabase/migrations/20260501134000_scope_cleanup_legacy_trip_payment_biopay.sql`, `supabase/migrations/20260524001000_final_scope_cleanup_after_linked_history.sql`, linked database | Migrations replay cleanly on staging; legacy BioPay/payment/SMS ledger/ride-request objects are absent from schema/realtime; current profile, nearby discovery, scheduled trips, chat, reports/blocks, admin moderation, storage, and notification gates still pass. |
| Validate historical schema cleanup | `supabase/migrations/*ride_requests*`, linked database | Flutter service/provider/model/sheet entry points remain absent; local forward cleanup migration has replay evidence; linked RLS tests pass. |
| Run linked Supabase gates | `scripts/ci/verify_backend.sh`, `supabase/tests/*.sql` | Script passes with `SUPABASE_PROJECT_REF` plus `SUPABASE_ACCESS_TOKEN`, or with `SUPABASE_PROJECT_REF` plus valid linked DB access via `SUPABASE_DB_PASSWORD`; failures triaged in audit report. |
| Verify admin report queue on linked backend | `lib/features/admin/admin_reports_screen.dart`, `supabase/migrations/20260501133000_user_reports_blocks.sql` | Operators can list and resolve `user_reports` through active admin UI on staging/production; RPC authorization remains server-enforced. |
| Secret history purge | `docs/security/secret_rotation_runbook.md`, `scripts/qa/preflight_secret_history_purge.sh`, `scripts/qa/check_secret_history.sh`, Play Console/IAM | Exposed Play key is revoked, replacement secret is only in CI, preflight passes in a clean full clone with `git-filter-repo`, history is rewritten/pushed with lease, and `scripts/qa/check_secret_history.sh` passes. |
| Release build smoke | `scripts/release/build_android_release.sh`, `scripts/release/smoke_android_release.sh`, Android CI/device | Signed AAB builds with release secrets, uploads to Play Console validation, writes temporary signing files from env when needed, cleans them afterward, and passes physical-device smoke with evidence under `build/reports/android-smoke/`. |
| Final go/no-go gate | `scripts/release/go_no_go_check.sh`, `docs/release/evidence/*.example.md` | Gate passes only after all local, linked backend, Play credential, Play upload, and physical-device smoke blockers are cleared with existing non-template evidence files for Play key rotation and Play upload validation. |
| Keep public policy URLs release-gated | `landing/privacy-policy.html`, `landing/account-deletion.html`, `scripts/web/verify_public_site.sh`, hosting config | Every release verifies `PRIVACY_POLICY_URL` and `ACCOUNT_DELETION_URL` over HTTPS and reruns the public-site scope verifier before deploy. |
