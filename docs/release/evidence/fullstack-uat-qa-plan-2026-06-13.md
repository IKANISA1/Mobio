# MOBI Fullstack UAT, QA, and Production Readiness Plan

Date: 2026-06-13  
Scope: MOBI Flutter app, BioPay, Supabase backend, edge functions, database, admin surfaces, PWA/public web, Android device release, release/store gates.

## Executive Correction

The previous BioPay device proof is not a full production UAT. It proves that the current fresh Android APK can launch BioPay entry points on a physical Android device and that the live Supabase BioPay health endpoint reports AWS Rekognition readiness. It does not prove the whole app is production-ready.

This document is the execution baseline for the full UAT and QA run that is still required. It covers every frontend screen, every critical backend function and database boundary, every user journey, on-device behavior, API/function behavior, and release readiness.

## Non-Negotiable Product Boundaries

1. BioPay payment remains pure USSD. The app may prepare the recipient, amount, and reference, then open the phone `tel:` USSD dialer. Payment is completed outside the app.
2. The app must not claim that in-app payment, card settlement, wallet settlement, or internal payment confirmation has occurred.
3. BioPay "paid" state must be treated as a user/admin/business confirmation workflow unless external operator proof is integrated later.
4. Face enrollment and face scan must use AWS Rekognition, not Google face APIs.
5. QR, NFC, face scan, and face enrollment screens must start from the recovered BioPay app behavior and then be visually fitted into MOBI's current design system.
6. The Revolut screenshots are reference material only. They must not be copy-pasted blindly. Search rows, activity feeds, and unrelated features must not be introduced unless MOBI actually supports them.
7. Unsupported "Activities" screen remains out of scope and must not reappear in public navigation.

## Current Evidence Already Available

BioPay reference evidence:

- Source reference screenshots exist under `/Volumes/PRO-G40/BioPay/mobile/test/screen_captures/`.
- MOBI fresh BioPay device screenshots exist under `/Volumes/PRO-G40/MOBI/mobi_app/docs/release/evidence/device-uat-biopay-2026-06-13-fresh/`.
- The BioPay readiness gate passed and wrote `/Volumes/PRO-G40/MOBI/mobi_app/docs/release/evidence/biopay-live-readiness-2026-06-13.md`.

Backend/AWS evidence:

- Supabase BioPay health reports AWS Rekognition as the active provider.
- AWS Rekognition collection for MOBI BioPay is configured as `mobio-biopay-prod`.
- Runtime AWS credentials were installed into the live Supabase project.

Android evidence:

- A fresh release APK was installed on device `13111JEC215558`.
- The physical device reports camera, NFC, and USSD dialer capability.

This evidence is useful, but it is not enough for full production readiness.

## Critical Gaps Before Production

P0 gaps:

- Full frontend UAT has not yet been executed across every screen and state.
- Full backend UAT has not yet been executed across all migrations, RLS policies, edge functions, RPCs, and live API contracts.
- Release build reproducibility must be proven. A fresh release APK exists, but recent build runs showed unstable Gradle/native-library behavior and terminated runs.
- Exposed Supabase tokens and project secrets in conversation history must be rotated before production release.
- Real OTP, USSD, face enrollment, face match, QR scan, NFC activation, and admin confirmation flows still need end-to-end UAT evidence.
- Legacy or boundary functions such as `create-payment-intent`, `verify-payment-status`, `parse-sms`, `reconcile-momo-sms`, and `admin-review-transaction` must be proven either intentionally unavailable or correctly scoped.

P1 gaps:

- Visual regression coverage is not yet complete for all screens, states, locales, and accessibility modes.
- Offline, poor-network, resume-from-background, and locked-device recovery have not been fully captured.
- Admin and PWA/public web flows need full browser QA and production configuration proof.
- Observability, audit logging, error surfaces, and support diagnostics need full review.

P2 gaps:

- Long-form usability polish, copy consistency, and microinteraction review should follow after functional blockers are cleared.

## UAT Workstreams

### 1. Repository and Build Integrity

Goal: prove the codebase, dependencies, generated files, and build artifacts are coherent.

Checks:

- `git status --short` inventory with unrelated dirty files separated from release-blocking changes.
- `flutter pub get`
- `flutter analyze`
- `dart format --set-exit-if-changed` on touched Dart code or scoped directories.
- `flutter test`
- Focused tests for BioPay, OTP, notification, profile, bookings, admin, and release boundary tests.
- Android clean build from a deleted `build/`, `.dart_tool/`, and Gradle build cache state.
- Release APK and AAB build reproducibility.
- APK install on physical device.
- Version name/code, signing config, permissions, manifest declarations, and Play release metadata.

Exit criteria:

- Clean reproducible release build.
- No hidden stale APK dependency.
- Test failures either fixed or logged as explicit blockers.

### 2. Full Frontend Screen UAT

Goal: capture and review every supported user-facing screen and all important states.

Screen groups:

- Launch, splash, first run, session restore, no-session state.
- WhatsApp login: phone entry, OTP entry, resend, invalid code, rate limit, network failure, success.
- Home: header, hero, route/search inputs if supported, nearby entry points, permissions, empty/error/loading.
- Nearby/map/list: location permission denied, granted, no results, live results, item details.
- Bookings/trips: bookings list, empty state, schedule trip, route form, timing, vehicle selection, confirmation, errors, existing trips.
- Chat: conversation list/state if supported, composer, send disabled, network error, admin/user role boundaries.
- Profile: profile overview, edit profile, contact section, vehicle section, MoMo receiver fields, notification consent, BioPay Face entry.
- Notifications: list, empty state, consent, push permission, read/unread behavior.
- BioPay home: Face Scan, NFC Tap, Get QR, Scan QR.
- BioPay face enrollment: AWS provider state, liveness session start, capture guidance, failure, retry, success, already enrolled.
- BioPay face scan: amount optionality, camera permission, capture, match failure, match success, USSD handoff.
- BioPay QR: number/code toggle, optional amount, QR generation, share/save if supported, invalid recipient.
- BioPay scanner: camera permission, torch, invalid QR, valid QR, USSD handoff.
- BioPay NFC: number/code toggle, optional amount, NFC unavailable, NFC active, detected tag, USSD handoff.
- Admin: auth, dashboard, users/profiles, vehicle types, subscriptions, broadcasts, BioPay confirmations, audit/error states.
- Public/PWA surfaces: landing, any admin/public bundles, installability, manifest, icons, offline behavior if supported.

Review criteria:

- Screen matches supported product behavior and does not invent unsupported features.
- BioPay screens use BioPay source behavior as baseline and apply MOBI/Revolut-inspired fit only where it improves clarity.
- Primary action is obvious and reachable.
- Icon-led controls are used where appropriate.
- No search row or activity/feed pattern appears unless the actual workflow needs it.
- No text overlap, clipping, or unreadable contrast.
- Loading, empty, error, disabled, success, and retry states are present where needed.
- Large text, small phone viewport, dark/light mode, and localization do not break layout.
- Camera/NFC/notification/location permission states are understandable and recoverable.

Artifacts:

- Screenshot set for every screen and state.
- Screen manifest mapping route -> screenshot -> status -> issue IDs.
- Critical UX findings with P0/P1/P2 severity.

### 3. Android Physical Device UAT

Goal: prove the app behaves on a real Android device, not only in tests or screenshots.

Device target:

- Current connected device: `13111JEC215558`.

Checks:

- Fresh uninstall/install of release APK.
- Fresh launch screenshot.
- Full route walkthrough with screenshots.
- `adb logcat` crash scan during walkthrough.
- Runtime permission checks for camera, NFC, notifications, and location.
- App background/resume behavior.
- Locked/unlocked recovery behavior.
- USSD dialer intent proof using encoded `tel:` URI.
- Camera proof for QR and face screens.
- NFC feature proof and unavailable-state fallback where possible.
- Network on/off and poor-network behavior.

Exit criteria:

- No crash, ANR, or broken first-run path.
- All supported screens can be reached.
- All hardware-gated flows show correct permission handling.
- USSD handoff opens the phone dialer and does not represent external payment as completed.

### 4. BioPay End-to-End UAT

Goal: prove BioPay is restored correctly and production-scoped.

Flows:

- Profile -> BioPay Face setup.
- Face enrollment -> AWS Rekognition enrollment/liveness provider.
- Face scan -> AWS Rekognition match path.
- BioPay home -> NFC Tap.
- BioPay home -> Get QR.
- BioPay home -> Scan QR.
- QR/NFC/face recipient resolution.
- Optional amount behavior.
- USSD dialer handoff.
- User-paid claim and admin confirmation boundary.
- Admin BioPay confirmations.

Backend checks:

- `biopay_profiles` RLS and ownership.
- `biopay_payment_requests` creation, visibility, status transitions, audit fields.
- `biopay-face-provider` health/enroll/match endpoints.
- AWS Rekognition collection ID and region configuration.
- No Google face-provider dependency remains in active BioPay paths.

Exit criteria:

- Face provider is AWS in app config, Supabase function behavior, and live health.
- USSD handoff is the only payment execution path.
- Admin confirmation does not pretend to be operator settlement proof.

### 5. Supabase Database UAT

Goal: prove schema, RLS, migrations, and data contracts support production behavior.

Checks:

- List local migrations and linked remote migration state.
- Dry-run remote schema push where safe.
- Run backend SQL assertion tests.
- Review RLS policies for all user-owned tables.
- Review admin-only access and audit logging.
- Verify storage buckets, realtime publications, triggers, and notification triggers.
- Verify seed/test data separation from production data.
- Verify rollback/recovery notes for each recent migration.

Tables and domains to review:

- Profiles and edit-profile fields.
- Country/phone normalization.
- Public transport, drivers, vehicles, vehicle types.
- Trips/bookings/schedules.
- Notifications and push tokens.
- BioPay profiles and payment requests.
- Admin catalogs and audit logs.

Exit criteria:

- No table with user data lacks intentional RLS.
- No privileged RPC can be called by an unauthorized user.
- Schema matches frontend model contracts.

### 6. Supabase Edge Function and API UAT

Goal: prove every deployed function is intentional, scoped, observable, and tested.

Function groups:

- Auth/OTP: `send-login-otp`, `verify-login-otp`, `send-otp`, `verify-otp`.
- BioPay: `biopay-face-provider`, `biopay-api` if still active.
- Notifications: `send-push`.
- Admin: `admin-review-transaction` if still active, admin shared helpers.
- Maps/location: `maps-gateway`.
- Marketing/content: `generate-promo-content`.
- Legacy/payment-boundary: `create-payment-intent`, `verify-payment-status`, `parse-sms`, `reconcile-momo-sms`.

Checks:

- Deno unit tests for function and `_shared` helpers.
- Live health/smoke calls for deployed functions that expose health endpoints.
- Authenticated and unauthenticated negative tests.
- Invalid payload tests.
- Rate-limit/abuse tests for OTP.
- Function logs for error noise after smoke.
- Secret dependency inventory per function.
- Explicit scope-unavailable response for functions that must not be used in the current product.

Exit criteria:

- No payment or SMS reconciliation function is reachable as an implied in-app payment path unless explicitly approved and documented.
- All production functions have clear auth, validation, logging, and failure behavior.

### 7. Admin and Operations UAT

Goal: prove operators can run supported workflows without unsafe powers or hidden failures.

Checks:

- Admin login and authorization.
- Admin-only data visibility.
- Vehicle type/catalog management.
- Subscriptions/admin broadcast surfaces if supported.
- BioPay external payment confirmation workflow.
- Audit trail visibility.
- Error handling for denied/expired admin session.

Exit criteria:

- Admin screens do not expose unsupported payment settlement claims.
- Admin actions leave auditable records.

### 8. Security, Privacy, and Compliance QA

Goal: remove release-blocking security and privacy risks.

Checks:

- Rotate exposed Supabase anon/service/platform tokens and any pasted secrets.
- Run secret scan across repository and release artifacts.
- Verify no service-role key is embedded in Flutter, web, APK, or public config.
- Verify AWS keys are server-side only.
- Verify Android permissions are minimal and explainable.
- Confirm no SMS permission is used for payment.
- Verify privacy policy, account deletion, Play Data Safety inputs, and biometric disclosure copy.
- Verify biometric data lifecycle: enrollment consent, storage boundary, deletion path, provider collection behavior.

Exit criteria:

- No known exposed credential remains valid.
- Biometric and payment boundaries are documented and visible where needed.

### 9. Web/PWA QA

Goal: prove public and PWA bundles are production-safe.

Checks:

- Landing page visual and responsive QA.
- Web build.
- PWA manifest and icons.
- Cloudflare/PWA bundle verification scripts.
- Public routes do not expose admin or service secrets.
- Browser screenshot QA for desktop and mobile viewport.

Exit criteria:

- Public web deploy is visually correct and free of leaked secrets.

### 10. Release Go/No-Go

Goal: produce a final production readiness decision.

Required artifacts:

- Fullstack UAT report.
- Frontend screenshot manifest.
- Device UAT evidence folder.
- Backend function test logs.
- Database/RLS assertion logs.
- Release build logs.
- Secret rotation proof or blocker note.
- Go/no-go checklist with P0/P1/P2 findings.

Go criteria:

- Zero unresolved P0 issues.
- P1 issues either fixed or accepted with explicit release-owner approval.
- Fresh release APK/AAB generated reproducibly.
- Physical-device smoke passes.
- Backend live smoke passes.
- BioPay USSD/AWS boundaries pass.

No-go criteria:

- Any crash on critical user journey.
- Any exposed valid secret.
- Any unauthorized data access.
- Any in-app payment claim or behavior that conflicts with the USSD-only boundary.
- Any non-reproducible release build.

## Execution Sequence

Phase 1: Inventory and static QA

- Capture current git status.
- Enumerate routes/screens/features.
- Enumerate Supabase functions, migrations, tests, RPCs, and scripts.
- Run static scans: secrets, analyze, scoped contract tests.

Phase 2: Backend UAT

- Run Supabase local/linked migration checks.
- Run SQL security assertions.
- Run Deno edge function tests.
- Smoke live function health and negative cases.
- Document function-by-function status.

Phase 3: Frontend automated QA

- Run Flutter tests.
- Add or update missing preview/widget tests where gaps block confidence.
- Generate deterministic screenshot matrix where possible.
- Review route coverage against actual app router.

Phase 4: Physical-device UAT

- Build fresh release APK from clean state.
- Install on device.
- Walk every screen.
- Capture screenshots, logs, and hardware capability proof.
- Execute BioPay, OTP, location, notification, QR, NFC, and USSD paths as far as external dependencies permit.

Phase 5: Critical analysis and remediation plan

- Classify findings P0/P1/P2.
- Separate actual production blockers from polish.
- Produce final go/no-go.
- Create targeted fix plan for unresolved issues.

## Tooling Plan

Skills applied:

- `mobile-app-development` for overall mobile production workflow.
- `integration-e2e-release-smoke` for end-to-end smoke design and release checklist.
- `golden-visual-regression-testing` for screenshot/golden coverage.
- `backend-architecture` for database, API, function, and production backend review.

Local tools:

- Flutter/Dart from `/Volumes/PRO-G40/flutter_3_44/bin/`.
- Android `adb`.
- Supabase CLI and Supabase MCP where useful.
- Deno for Supabase edge function tests.
- Repository QA scripts under `scripts/ci`, `scripts/qa`, `scripts/release`, and `scripts/web`.

External-gated items:

- Real USSD payment completion requires the phone/operator and must remain outside the app.
- Production credential rotation changes must be tracked carefully and may invalidate existing deploys.
- Play Console submission or external production release requires explicit human approval.

## First Commands to Execute

These are the first execution commands for the full UAT run:

```bash
cd /Volumes/PRO-G40/MOBI/mobi_app
/Volumes/PRO-G40/flutter_3_44/bin/flutter pub get
/Volumes/PRO-G40/flutter_3_44/bin/flutter analyze
/Volumes/PRO-G40/flutter_3_44/bin/flutter test
scripts/ci/verify_backend.sh
scripts/qa/scan_secrets.sh
scripts/qa/audit_storage_realtime.sh
scripts/qa/verify_biopay_live_readiness.sh
scripts/release/go_no_go_check.sh
```

Backend-specific execution will then run Supabase function tests and linked live smokes, with secrets redacted from reports.

Device-specific execution will rebuild, reinstall, walk all routes, capture screenshots, and scan logs.

## Current Critical Assessment

Current state is not production-ready until the full UAT above is executed and P0 findings are resolved.

The strongest current area is BioPay restoration proof: the current APK exposes BioPay entry points, uses AWS provider health server-side, has camera/NFC/dialer capability, and keeps payment outside the app through USSD handoff.

The weakest current areas are release reproducibility, full app screen coverage, backend-wide function/API validation, credential rotation after exposed secrets, and complete on-device coverage beyond BioPay.

## Immediate Next Step

Execute Phase 1 and Phase 2, then update this folder with:

- `fullstack-uat-qa-results-2026-06-13.md`
- `fullstack-uat-screen-manifest-2026-06-13.csv`
- `fullstack-backend-function-matrix-2026-06-13.md`
- `fullstack-go-no-go-2026-06-13.md`

