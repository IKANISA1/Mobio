# Google Play Submission Checklist

Last updated: 2026-06-15

> Historical June 2026 evidence. The current Android promotion process is
> [candidate and separate approval](README.md#android-candidate-and-play-promotion)
> as of 2026-09-30. The version, target SDK, linked backend, provider, device,
> credential and Play upload claims below are dated observations, not acceptance
> for a new candidate. The GitHub workflows now build candidate artifacts only.

## Current Android Readiness

- Package name: `rw.mobi.app`.
- Version: `1.0.0+14` in `pubspec.yaml`.
- Android config: `compileSdk = 36`, `targetSdk = 35`, `minSdk = 24`.
- Release signing: `android/key.properties` required for release Gradle tasks.
- Google Play service-account JSON: must be supplied by
  `PLAY_STORE_SERVICE_ACCOUNT_JSON`; do not commit JSON credentials. Release
  config validation now checks that this secret is valid service-account JSON
  before upload.
- Approved manual Play uploads default to the internal testing track through
  Fastlane. Set `PLAY_RELEASE_TRACK=production` only after go/no-go approval,
  and set `PLAY_PRODUCTION_APPROVED=true` for production-track validation.
- A signed local release AAB was built on 2026-06-15 at
  `build/app/outputs/bundle/release/app-release.aab` with SHA-256
  `632a4ee11283491b814a972d419d138d9be6d9a5e6f9950579b2234d7f0061a0`
  and uploaded to Google Play internal draft as versionCode `14`.
- A signed local release APK was also built at
  `build/app/outputs/flutter-apk/app-release.apk` with SHA-256
  `578dcfb44d60e3077718e2662c16e45d943088248505cb7fb5e1bbb8ca41a9b4`,
  verified with APK Signature Scheme v2, installed on Pixel 4a
  `13111JEC215558`, and smoke-tested successfully.
- Required build defines: `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
  `PRIVACY_POLICY_URL`, `ACCOUNT_DELETION_URL`.
- Manifest after scope fix: network, location, notification, camera, and NFC
  permissions are active for Mobio. SMS permissions remain absent from the main
  Mobio app and belong only to the private in-house Mo Mobio SMS utility app.
- BioPay is an active Mobio feature for USSD handoff, AWS-backed face flows,
  NFC, and QR receiver-code save/share. It is not an in-app settlement wallet
  or card-payment processor.
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

1. Keep the owner-approved Play service-account retention evidence current and
   verify secret history with `scripts/qa/check_secret_history.sh`.
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
   `RELEASE_TARGET=android PLAY_SERVICE_ACCOUNT_RETAINED=true PLAY_SERVICE_ACCOUNT_RETENTION_EVIDENCE=docs/release/evidence/play-service-account-retention-2026-06-12.md PLAY_CONSOLE_UPLOAD_VALIDATED=true PLAY_CONSOLE_UPLOAD_EVIDENCE=docs/release/evidence/play-console-upload-2026-06-15-v14.md GOOGLE_MAPS_SERVER_SECRET_VALIDATED=true GOOGLE_MAPS_SERVER_SECRET_EVIDENCE=docs/release/evidence/google-maps-server-secret-2026-06-14.md FCM_HTTP_V1_SECRET_VALIDATED=true FCM_HTTP_V1_SECRET_EVIDENCE=docs/release/evidence/fcm-http-v1-secret-2026-06-14.md ./scripts/release/go_no_go_check.sh`.
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
- Do not describe in-app card payment, automatic fare quotes, dispatch, or
  completed-trip lifecycle. BioPay may be described only as a Mobio USSD/NFC/QR
  handoff feature, not as in-app settlement.
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
- Camera and NFC are justified by active BioPay face/NFC/QR flows. SMS must
  remain absent from the main Mobio app; SMS collection is isolated to the
  private Mo Mobio office utility app.
