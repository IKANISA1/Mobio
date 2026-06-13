# Google Play Submission Checklist

Last updated: 2026-06-11

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
- A signed local release AAB was built on 2026-06-11 at
  `build/app/outputs/bundle/release/app-release.aab` with SHA-256
  `4f33ee3e589a5c24b9ad3d0f6b6ad9dbcee969360657d0159cdccfa58017ba9b`.
- A signed local release APK was also built at
  `build/app/outputs/flutter-apk/app-release.apk` with SHA-256
  `c2c05cfc3c3ff9417fe83f46877163b5d2a99f82d1f034a3549313c68c337cb5` and
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
  this is intentional product-scope behavior. Play/store copy must continue to
  avoid route calculation, ETA, distance, polyline, route matrix, fare quote,
  dispatch, and payment claims. Google Routes API, Compute Route Matrix,
  Directions API, Distance Matrix API, ETA/distance/polyline/matrix, and
  dispatch-grade routing are out of context for this app and must not be listed
  as Mobio release-readiness work.
- Linked Supabase migrations and Edge Functions were updated on 2026-06-11.
  `supabase db push --linked --dry-run` reported the remote database is up to
  date, and `REQUIRE_LINKED_SUPABASE=true ./scripts/ci/verify_backend.sh`
  passed after the public-transport RPC qualification migration.
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
   owner-approved credential-use, Google Maps server-key proof, FCM HTTP v1
   proof, and device-smoke evidence exists:
   `RELEASE_TARGET=android PLAY_SERVICE_ACCOUNT_RETAINED=true PLAY_SERVICE_ACCOUNT_RETENTION_EVIDENCE=docs/release/evidence/play-service-account-retention-2026-06-12.md PLAY_CONSOLE_UPLOAD_VALIDATED=true PLAY_CONSOLE_UPLOAD_EVIDENCE=/secure/path/play-console-upload.md GOOGLE_MAPS_SERVER_SECRET_VALIDATED=true GOOGLE_MAPS_SERVER_SECRET_EVIDENCE=/secure/path/maps-gateway-secret.md FCM_HTTP_V1_SECRET_VALIDATED=true FCM_HTTP_V1_SECRET_EVIDENCE=/secure/path/fcm-http-v1-secret.md ./scripts/release/go_no_go_check.sh`.
   `RELEASE_TARGET=android` keeps iOS Firebase/native checks out of the Google
   Play gate; use the default target after Android is submitted and iOS release
   work resumes. When the target includes iOS, also provide
   `IOS_FIREBASE_APNS_VALIDATED`, `IOS_FIREBASE_APNS_EVIDENCE`,
   `IOS_CRASHLYTICS_SYMBOLS_VALIDATED`, and
   `IOS_CRASHLYTICS_SYMBOLS_EVIDENCE`.
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
