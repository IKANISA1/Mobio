# Google Play Submission Checklist

Last updated: 2026-05-24

## Current Android Readiness

- Package name: `rw.mobi.app`.
- Version: `1.0.0+12` in `pubspec.yaml`.
- Android config: `compileSdk = 36`, `targetSdk = 35`, `minSdk = 24`.
- Release signing: `android/key.properties` required for release Gradle tasks.
- Google Play service-account JSON: must be supplied by
  `PLAY_STORE_SERVICE_ACCOUNT_JSON`; do not commit JSON credentials. Release
  config validation now checks that this secret is valid service-account JSON
  before upload.
- Play uploads default to the internal testing track through GitHub Actions and
  Fastlane. Set `PLAY_RELEASE_TRACK=production` only after go/no-go approval,
  and set `PLAY_PRODUCTION_APPROVED=true` for production-track validation.
- A signed local release AAB was built on 2026-05-23 at
  `build/app/outputs/bundle/release/app-release.aab` with SHA-256
  `ce11278526a031ffa233b9c81988f0c2ce17919796175d101b8fe0688bff67f9`.
- A signed local release APK was also built at
  `build/app/outputs/flutter-apk/app-release.apk` with SHA-256
  `862f9d989d32750fd229c35e3286c2ae76f24adab6f43ccda5fbacd93710d4df` and
  verified with APK Signature Scheme v2. Physical-device smoke and Play Console
  upload validation are still required.
- Required build defines: `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
  `PRIVACY_POLICY_URL`, `ACCOUNT_DELETION_URL`.
- Manifest after scope fix: network, location, and notification permissions
  remain; camera/SMS/boot ledger receivers are not active.
- Flutter/native app package cleanup removed BioPay, payment, ledger, camera,
  QR, NFC, SMS ingestion, face-model, and local-auth dependencies from the
  active Android build.
- Fastlane text metadata and phone screenshots now describe only nearby
  discovery, scheduled trip posts, profiles, chat, WhatsApp handoff, manual
  negotiation, report/block controls, and privacy controls.
- Scheduled-trip UI stores route labels and optional coordinates only. It does
  not compute automatic routes, timing, fare quotes, or payment settlement.
- Active scheduled-trip models/admin screens expose scheduled post state only;
  no completed trip lifecycle filter/status is shipped.
- `maps-gateway` rejects route-computation requests with a 410 scope response;
  Play/store copy must continue to avoid route calculation, fare quote,
  dispatch, and payment claims.
- Local Supabase replay through
  `20260524001000_final_scope_cleanup_after_linked_history.sql` passed DB lint,
  backend security assertions, and storage/realtime audit. Linked Supabase
  replay/assertions are still required before Play production.
- Public landing, privacy, terms, and account-deletion pages now describe the
  same limited marketplace/discovery scope.
- Live public pages were verified on `https://mobio.ikanisa.com/`,
  `/privacy-policy`, `/account-deletion`, and `/terms-and-conditions` on
  2026-05-23 after deploying the corrected Cloudflare Pages bundle.

## Pre-Submission Gates

1. Rotate/revoke the previously tracked Play service-account key and purge Git
   history before public or production release. Verify the purge with
   `scripts/qa/check_secret_history.sh`.
2. Before running the destructive history rewrite, run
   `scripts/qa/preflight_secret_history_purge.sh` from a clean full clone.
3. Run `scripts/qa/scan_secrets.sh`.
4. Run `scripts/qa/check_secret_history.sh`.
5. Run `flutter analyze --no-fatal-infos --no-fatal-warnings`.
6. Run `flutter test`.
7. Run release contract tests, including
   `flutter test test/release/backend_scope_boundary_test.dart test/release/report_block_contract_test.dart test/release/scope_boundary_test.dart`.
8. Run `./scripts/ci/verify_backend.sh` with linked Supabase credentials for
   RLS/storage/realtime assertions.
9. Run `./scripts/ci/verify_release_config.sh` with release env/secrets.
   Production release validation must set `REQUIRE_SECRET_HISTORY_CLEAN=true`;
   this requires a full Git clone and fails until the historical Play
   service-account JSON path has been purged.
10. Rebuild the signed AAB using `./scripts/release/build_android_release.sh appbundle`.
11. Upload the AAB to Play Console internal/closed testing for validation, then
   smoke test the installed build on a physical Android device.
   For local install/launch smoke, build a release APK with
   `./scripts/release/build_android_release.sh apk` and run
   `./scripts/release/smoke_android_release.sh`.
12. Re-verify `PRIVACY_POLICY_URL` and `ACCOUNT_DELETION_URL` over HTTPS on
   the production/public domain.
13. Run the final fail-closed go/no-go gate after linked Supabase, Play upload,
   key-rotation, and device-smoke evidence exists:
   `PLAY_SERVICE_ACCOUNT_ROTATED=true PLAY_SERVICE_ACCOUNT_ROTATION_EVIDENCE=/secure/path/play-service-account-rotation.md PLAY_CONSOLE_UPLOAD_VALIDATED=true PLAY_CONSOLE_UPLOAD_EVIDENCE=/secure/path/play-console-upload.md ./scripts/release/go_no_go_check.sh`.
   Evidence templates live under `docs/release/evidence/`; do not commit
   service-account JSON, private keys, access tokens, or credential screenshots.
   The gate rejects `*.example.md` template paths.
14. Complete closed testing with location permission, notification permission,
   profile, nearby discovery, schedule, chat, WhatsApp handoff, reports/blocks
   where implemented, and account deletion.

## Store Listing And Declarations

- Position Mobio as nearby discovery, scheduled trip posting, and communication.
- Do not describe in-app payment, BioPay settlement, automatic fare quotes,
  dispatch, or trip lifecycle.
- Data Safety must include location, phone/profile data, chat/user content,
  diagnostics/crash data if Firebase Crashlytics remains enabled, and push token
  data.
- Privacy policy must describe manual fare negotiation and external WhatsApp
  handoff.
- Provide a working account deletion URL and support contact. The local source
  page is `landing/account-deletion.html`; release builds require
  `ACCOUNT_DELETION_URL`.

## Permission Notes

- Location permissions are justified by nearby discovery.
- Notification permission is justified by chat/admin/service notifications.
- Camera, NFC, SMS, biometric/payment, and related high-risk dependencies should
  remain absent unless a future approved product scope re-enables those flows
  and Play declarations are updated.
