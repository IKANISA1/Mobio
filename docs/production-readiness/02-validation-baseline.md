# MOBI Validation Baseline

> Historical snapshot: this 2026-05-06 validation baseline predates the
> 2026-05-23 Mobio limited-scope cleanup. Treat it as audit history only.
> Current validation status is in `docs/reports/production-readiness-audit.md`
> and `docs/release/go-no-go.md`. Legacy BioPay, payment, SMS ledger, and
> ride-request lifecycle references below are not approved active scope.

Date: 2026-05-06

## Commands Run

| Command | Result | Notes |
| --- | --- | --- |
| `git status --short` | Passed | Worktree was already dirty before this pass. |
| `git branch --show-current` | Passed | `main`. |
| `git log -1 --oneline` | Passed | `5d9c5dd feat: harden MOBI super app launch`. |
| `git diff --check` | Passed | No whitespace/conflict-marker issues in the current diff. |
| `flutter --version` | Passed after initial failure | Initial run failed because Flutter could not write `/usr/local/share/flutter/bin/cache/engine.stamp`; later run reported Flutter 3.38.9 / Dart 3.10.8 after system space became available. |
| `dart --version` | Passed after initial failure | Later run reported Dart 3.10.8. |
| `deno --version` | Passed | `deno 2.7.5`. |
| `supabase --version` | Passed | `2.90.0`; CLI reported newer version available. |
| `node --version` | Passed | `v25.9.0`. |
| `./scripts/qa/scan_secrets.sh` | Passed | After scanner expansion, current working tree has no forbidden Play service-account JSON path and no matching secret patterns outside ignored paths. |
| `deno fmt supabase/functions/verify-otp/index.ts` | Passed | Reformatted modified Edge Function. |
| `deno check supabase/functions/verify-otp/index.ts` | Passed | Modified Edge Function type-checks. |
| `deno fmt supabase/functions/_shared/otp-security.ts supabase/functions/_shared/otp-security_test.ts supabase/functions/send-login-otp/index.ts supabase/functions/send-otp/index.ts supabase/functions/generate-promo-content/index.ts supabase/functions/biopay-api/index.ts supabase/functions/verify-otp/index.ts` | Passed | Formatted modified Deno functions/tests. |
| `deno check supabase/functions/send-login-otp/index.ts supabase/functions/send-otp/index.ts supabase/functions/generate-promo-content/index.ts supabase/functions/biopay-api/index.ts` | Passed | Modified send/promo/BioPay functions type-check. |
| `deno test --allow-env supabase/functions/_shared/otp-security_test.ts` | Passed | 2 OTP rate-limit helper tests passed. |
| `deno test --allow-env supabase/functions/biopay-api/index_test.ts` | Passed | 16 BioPay tests passed. |
| `./scripts/ci/verify_backend.sh` | Passed | Secret scan, Deno checks, BioPay tests, and OTP security tests passed; linked Supabase gates skipped without credentials. |
| `bash -n scripts/ci/verify_backend.sh scripts/ci/write_android_signing_files.sh scripts/qa/scan_secrets.sh scripts/web/prepare_pwa_bundles.sh` | Passed | Shell scripts parse. |
| `dart format --set-exit-if-changed <touched Dart files>` | Passed | 13 touched Dart files checked; 0 changed. |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | Passed | No issues found. |
| `flutter test test/app/router/admin_session_guard_test.dart` | Passed | 7 tests passed. |
| `flutter test test/features/admin/widgets/admin_ui_test.dart` | Passed | 6 tests passed, including the operational health model/tab checks. |
| `flutter test test/features/admin/widgets/admin_ui_test.dart test/app/router/admin_session_guard_test.dart test/features/admin/data/admin_service_test.dart` | Passed | 27 targeted admin/service tests passed. |
| `set -a; source .env; set +a; SKIP_FLUTTER_BUILD=true ./scripts/web/prepare_pwa_bundles.sh /tmp/mobi_pwa_check` | Passed | Prepared client/admin PWA bundles from existing build output. |
| `SKIP_FLUTTER_BUILD=true ./scripts/web/prepare_pwa_bundles.sh /tmp/mobi_pwa_check` | Failed | Expected without environment; `SUPABASE_URL` was not set. |
| `supabase db lint --local --fail-on error` | Failed | Local Postgres at `127.0.0.1:54322` refused connection; Supabase local stack not running. |
| `docker --version` | Passed | Docker CLI present. |
| `docker info --format '{{.ServerVersion}}'` | Passed after Colima restart | Docker daemon reported server `28.4.0`; initial attempt failed because the Colima Docker socket was not responding. |
| `supabase status` | Failed | No local Supabase DB container existed for `MOBI` before local start attempt. |
| `supabase start` | Failed | Default Colima/containerd first hit `input/output error` while pulling `public.ecr.aws/supabase/postgres:17.6.1.016`. A validation-only Colima/Lima profile was then created on `/Volumes/PRO-G40`, but the first Supabase image pull hit public ECR `429 Too Many Requests` for realtime and later stalled in Docker layer extraction; the start attempt was stopped. Local migration replay did not run. |
| `supabase migration list --linked` | Failed release gate | Linked project is missing local migration `20260501132000_admin_revocation_and_operational_events.sql`; all prior local migrations through `20260501131000` are applied remotely. |
| `supabase db lint --linked --schema public --fail-on error` | Passed | No linked public schema lint errors found. |
| `supabase db query --linked --file supabase/tests/backend_security_assertions.sql --output table` | Failed | Backend assertions failed because `otp_rate_limits` and `operational_health_events` are missing on the linked project. |
| `supabase db query --linked --file supabase/tests/storage_realtime_audit.sql --output table` | Passed | Direct linked query returned no failure/warning rows. The shell wrapper `scripts/qa/audit_storage_realtime.sh` could not create a temp file while system volume was full. |

## Environment Blockers

- System volume `/System/Volumes/Data` had about 123 MB free during discovery; a later check showed about 1.5 GB available, enough for Flutter/Dart startup and analyze/test, then fell back to about 124 MB free during linked Supabase validation. Removing rebuildable Deno and partial Colima caches raised available space to about 3.3 GB, but this is still tight for Docker-heavy validation.
- Flutter SDK is installed under `/usr/local/share/flutter`, which resides on the nearly-full system volume.
- Repo volume `/Volumes/PRO-G40` has hundreds of GB free, but release builds may still fail if Flutter/Gradle need more system-volume cache space.
- Local Supabase DB is not running on `127.0.0.1:54322`; `supabase start` remains blocked by Docker image pull/extraction reliability. A validation-only Docker context `colima-mobi-validation` was created on `/Volumes/PRO-G40` and then stopped; the active Docker context was restored to `colima`.
- Linked Supabase gates can authenticate, but the linked project is one migration behind and fails backend security assertions until `20260501132000_admin_revocation_and_operational_events.sql` is applied to the intended staging/production target.

## Locally Validatable After Environment Fix

- `./scripts/ci/verify_flutter.sh`
- `dart format --set-exit-if-changed .`
- `flutter test --coverage`
- Android release build smoke checks
- `./scripts/release/build_android_release.sh appbundle` with real `.env` and signing files

## Requires Credentials Or External Environment

- `supabase db lint --linked --schema public --fail-on error`
- `scripts/qa/audit_storage_realtime.sh`
- `supabase db query --linked --file supabase/tests/backend_security_assertions.sql`
- Cloudflare Pages deploy checks and header verification
- Firebase/Crashlytics/Remote Config production verification
- Google/Firebase API inventory verification from
  `docs/reports/google_api_sdk_findings.md`, including Maps gateway secret
  evidence, maps-gateway tests, iOS Firebase/APNs evidence where applicable, and
  FCM HTTP v1 deployment evidence. Route APIs are not part of this validation
  because they are out of context for Mobio.
- Google Play upload/draft validation
- iOS no-codesign and full archive validation on a working macOS/iOS toolchain

## Baseline Risk

Do not treat the current repo as release-validated. Backend static/type checks, Flutter analyze, the targeted admin-session test, and the targeted admin UI test passed, but clean Supabase migration replay, linked Supabase RLS/security assertions, mobile release builds, iOS builds, full Flutter coverage, and browser/PWA runtime checks remain blocked or unrun.
