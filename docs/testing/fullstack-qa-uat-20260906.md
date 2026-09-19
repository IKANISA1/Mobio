# Mobio full-stack QA and UAT review — 6 September 2026

**Release/UAT recommendation: NO-GO.** Four high-priority defects remain: unauthenticated SMS ingestion, unauthenticated BioPay provider work, client-authoritative face enrollment, and broken live Admin routing. The automated suite passing does not clear these defects. Live authenticated and physical-device acceptance remains unverified.

This is an executed QA review with an acceptance test record, not owner sign-off or a deployment. Product code and production data were not changed by this review.

## Scope and baseline

- Active repository: `/Volumes/PRO-G40/mobio`. The task's configured `/Volumes/PRO-G40/MOBI` contained an obsolete empty directory tree.
- Initial HEAD: `c12f881fc54844bfe5657801aa174f43feca79c9`, with an existing Trips navigation change and test. Another task committed these as `499e0069ab3fe9a06f0919bc996c22ed62a7b8e4` during this run. The recorded hashes of both files, `pubspec.lock`, and `design.md` match the final source. The other task's changes were not reverted.
- Tools: Flutter 3.44.3, Dart 3.12.2, Deno 2.9.6; Codex in-app Chromium browser. Native performance and assistive-technology behavior were not inferred from that browser.
- Reviewed surfaces: passenger/driver Flutter app, shared Flutter Admin, public website, Admin PWA packaging, Supabase functions and selected critical SQL trust boundaries, Android SMS collector source.
- Route inventory: 41 literal router paths. See [route UAT matrix](fullstack-qa-uat-20260906-routes.csv); an inventory is not 41 completed user journeys.
- Audience and tasks: passenger/driver WhatsApp login, discovery, trip management and communication; BioPay recipient identification and external USSD handoff; Admin operational access; website discovery/download/business login; private SMS collection and subscription confirmation.
- The existing Rwanda default, six-digit member identity, Mobio terminology/assets, and external USSD boundary are retained. No Revolut financial workflow was added.
- Evidence directory: `/Volumes/PRO-G40/mobio/build/qa/fullstack-uat-20260906` (ignored build output). Private reference images, credentials, actual OTPs and customer data are not embedded in this report.

## Executed checks

| Check | Observed result | Evidence / boundary |
|---|---|---|
| Repository structure | Pass; 1,866 source/document files checked | `structure.log` |
| Runtime/build helper tests | 19 passed | `build-helper-tests.log` |
| Flutter static analysis | No issues found | `flutter-analyze.log` |
| Flutter suite with coverage | **553 passed**, about 9 minutes | `flutter-tests.log`; includes widget, routing, contract, visual regression and accessibility resilience tests |
| Dart line coverage | 9,874 / 20,072 measured lines, **49.19%** | `coverage-summary.json`; not a route/UAT completion percentage or branch coverage |
| Standard backend verifier | Entrypoints/admin scripts typechecked; 29 selected tests passed; secret scan passed | `backend-verify.log`; linked SQL/security/storage/realtime gates were explicitly **skipped** |
| Complete backend suite with committed frozen lock | **Failed**: missing lockfile entries | `backend-all-tests.log`; QF-05 |
| Complete backend suite with separate diagnostic lock copy | **39 passed, 0 failed, 1 ignored** | `backend-all-tests-diagnostic.log`; repository lockfile was not changed |
| Additional negative authorization probes | **2 failed expectations**, reproducing missing authorization | `face-auth-probe.log`, `sms-auth-probe.log`; all provider/RPC calls mocked; no real writes |
| Production web build from current source | Pass | `production-web-build.log`, isolated `production-web/` output |
| Separate synthetic proof web build | Build passed; Home runtime failed | `synthetic-web-build.log`, `synthetic-home-console.json`; QF-07 |
| Public website and existing PWA packaging contracts | Pass | `public-site-contract.log`, `pwa-bundle-contract.log`; static checks only |
| Public website responsive inspection | No horizontal overflow/broken images at sampled 320, 390, 768, 1440 widths | `website-layout.json`, `website-*.png`; main content at 390 used loaded Aeonik, 48px/48px hero |
| Public menu keyboard interaction | Open state, Escape dismissal and focus return passed | Browser interaction record in `uat-results.csv`; public navigation only |
| Live website and privacy page | Rendered successfully; sampled assets 200; no sampled warning/error console entries | `live-privacy.png`, `live-browser-privacy-network.json` |
| Live Admin entry/deep routes | **Failed**; marketing page served | QF-04 and `live-admin-*.png` |
| Synthetic login browser journey | Short-number validation, code stage, rejection and Change number recovery passed | `synthetic-login-*.png`; isolated message-free fixture, no live signed-in session |
| Live public-key backend checks | Face handler accepted input validation; SMS handler returned input validation; anonymous trips read denied | `backend-live-probes.json`, `sms-live-empty-probe.json`; no valid image/SMS or payment submitted |
| Linked database/deployment inventory | **Unverified**; management requests returned 403 and configured connector listed no projects | `database-baseline.json`, `edge-inventory.json` |
| Revolut reference bundle integrity | Pass: 923 collection records; checklist and references present | Integrity only; not target fidelity or UAT acceptance |

Direct command-line probes of the public website returned 403 while the browser rendered it successfully. Those command-line responses are not classified as a production outage. The zero-row BioPay REST probe used `limit=0` and does not establish row isolation or data disclosure.

## Findings and closure tests

### QF-01 — P1 / High — SMS ingestion trusts an unauthenticated collector

**Evidence:** `supabase/functions/momobio-sms-ingest/index.ts:29` parses submitted SMS and at line 43 creates an Admin client without authenticating the caller or registered collector. `apps/momobio_sms_bridge/app/src/main/java/com/momobio/app/UploadClient.kt:61` supplies only the public anonymous app key. In the local probe, a request without authorization returned **202** after one mocked parser call and one mocked privileged ingestion RPC. The harmless live empty-array request using the public app key returned the handler's **400** input-validation response, rather than an authentication rejection.

**Impact:** caller-authored receipt text can enter the privileged confirmation path. The latest source definition in `supabase/migrations/20260614165000_driver_subscription_momo_payer_phone_matching.sql:302` confirms a matched request and calls `_activate_driver_subscription` at line 331. Parsing and duplicate checks do not establish that a trusted device received a real payment SMS. A live forged subscription was **not** attempted; deployed SQL identity could not be read.

**Owner / closure:** backend/security and Android collector owners. Authenticate an enrolled collector with a revocable, narrowly scoped identity before parsing or using service-role privileges; authenticate receipt provenance and replay boundaries. Verify missing, public-key-only, expired, revoked and replayed credentials cannot call the parser or privileged RPC. Verify a legitimate fixture activates once and duplicates cannot extend entitlement. Do not embed a shared service-role credential in the APK.

### QF-02 — P1 / High — BioPay provider actions run without user authorization

**Evidence:** `supabase/functions/biopay-face-provider/index.ts:80` passes the caller's action/body into AWS handling without verifying a user session. A local request with no authorization returned **201** and reached one mocked AWS liveness-session call. A harmless live `match_face` request with the public app key and no image reached the handler and returned `image_required` with HTTP **200**.

**Impact:** the public app credential is sufficient to reach a handler that can create liveness sessions, enroll and search faces; this creates unauthorized provider-use and identity-data risks. The live probe did not call AWS with a valid image or retrieve a person's biometric data. The health flag `production_ready: true` checks configuration presence, not actual provider readiness.

**Owner / closure:** backend/BioPay owner. Validate the signed-in user before provider actions, bind liveness/enrollment sessions to that user, enforce per-action permissions and rate limits. Repeat the negative authorization probe and require 401/403 with **zero** provider calls. Test cross-account session access using dedicated accounts.

### QF-03 — P1 / High — Face enrollment trusts client-supplied provider results

**Evidence:** the security-definer `rpc_record_biopay_face_enrollment` in `supabase/migrations/20260612133000_biopay_ussd_aws_reactivation.sql:531` checks for an authenticated user and non-empty face ID, then writes client-supplied face/collection/liveness/metadata and activates the profile. It is granted to authenticated callers at line 905. `lib/features/biopay/data/biopay_face_service.dart:140` records those results from the client. The source match lookup uses the supplied provider subject to locate an active profile.

**Impact:** authentication alone does not prove a caller owns or enrolled the submitted provider identity. A caller can assert a forged enrollment result, with resulting recipient-binding ambiguity. This is a confirmed source trust-boundary defect; a production impersonation/wrong-recipient outcome was not reproduced, and no enrollment data was written.

**Owner / closure:** backend/database and BioPay owners. Persist provider-verified enrollment on the server, bound to the authenticated subject and one-time session; deny direct caller-authored assertions of provider success. Test arbitrary IDs, another user's face/session, replay, duplicate subject association, revoked consent, and enrollment replacement. Verify corresponding grants and constraints against the deployed database.

### QF-04 — P1 / High — Live Business login and Admin routes serve the marketing website

**Evidence:** fresh browser navigation to `https://mobio.ikanisa.com/admin-auth`, `https://mobio.ikanisa.com/admin/users`, and `https://mobioadmin.ikanisa.com/` rendered the marketing homepage instead of Admin. `/admin/users` also showed unstyled content and three broken relative images. The local combined package initially rendered Admin access; the separately rebuilt production application also rendered Admin access correctly. The package router in `scripts/web/prepare_pwa_bundles.sh:44` requires Admin routes to serve `__admin_shell`, and line 70 requires the dedicated hostname's root to redirect to `/admin-auth`.

**Impact:** the website's Business login conversion and Admin operator entry fail before credentials can be entered. HTTP 200 alone would incorrectly pass this journey.

**Owner / closure:** web/release owner. Inspect the deployed artifact, worker routing and hostname bindings; publish the corrected reviewed bundle through the normal release chain. Verify remote revision/version, page identity, direct deep-link reload, protected redirect and console/assets on both hostnames, then complete allowlisted Admin sign-in. No deployment was performed in this review.

### QF-05 — P2 / Medium — Backend CI misses tests and the full frozen suite cannot run

**Evidence:** `scripts/ci/verify_backend.sh:33` enumerates selected test files. Tests such as `_shared/http_test.ts`, `_shared/momo-sms_test.ts`, and `_shared/play-integrity_test.ts` are not all included. Running the entire functions tree with the committed frozen lock fails; a separate diagnostic lock copy resolves the missing dependencies and runs 39 tests, with one ignored.

**Impact:** a green standard verifier does not cover the available backend test surface; clean CI cannot reproduce the broader suite under its frozen dependency policy.

**Owner / closure:** backend/CI owner. Include all intended test files, refresh and review the lockfile, explain the ignored test, and require the full frozen command to pass from a clean checkout. Keep linked database/security checks mandatory for a release job.

### QF-06 — P2 / Medium — Shared navigation surface differs from the selected reference

**Evidence:** the selected DESK-007 reference has a near-black floating navigation panel; Mobio's Profile golden retains the violet underlying surface throughout the navigation panel. Home, Trips and BioPay also inherit route color through `GlassCard` in `lib/shared/widgets/mobi_bottom_nav.dart:48`. The mismatch is visible in the reviewed reference/target samples even though the target's own goldens pass.

**Measurement boundary:** DESK-007 is a 408×857 desktop capture containing a phone presentation; native DPR and exact original tokens are unknown. Target is 1170×2532 pixels for a 390×844 logical fixture. Sampled navigation-region medians after converting the source's embedded HP 524sf ICC profile to sRGB were RGB **(3,2,24)** for the reference and **(72,67,139)** for the target. Regions include icons/text; these are supporting raster measurements, not native color tokens or a pixel-equivalence score. Coordinates, hashes and conversion method are in `navigation-raster-comparison.json`.

**Owner / closure:** design/mobile owner. Match the selected navigation treatment with Mobio's four destinations and selected semantics retained, or record a justified product-specific adaptation for review. Recheck all route families, light/dark themes, text enlargement and background-scroll states. No 100% fidelity claim is supported by this run.

### QF-07 — P2 / Medium — Standalone proof harness fails at Home

**Evidence:** the fresh release build of `tool/revolut_visual_proof_app.dart` loads `?screen=home_shell` as a gray error surface with a navigation bar. Console reports `ProviderException` caused by `LateInitializationError`. Its entrypoint at line 47 runs the limited preview overrides without the production initialization path. The isolated login fixture renders, so build success is not proof that all preview routes work.

**Impact:** this harness cannot currently support the planned Home-to-Trips/recipient synthetic UAT journey or prove the native app works. This is a test-harness failure, not evidence that the production native Home screen crashes.

**Owner / closure:** mobile/QA owner. Fully isolate/initialize the required Home providers in the preview harness; run a browser smoke journey from Home through every tab and require no console exceptions. Keep synthetic authentication visibly distinguishable from an actual signed-in session.

## Revolut design acceptance record

Applied the requested `revolut-design` skill, `design.md` v5, the own-app identity rule, screen-typology mapping, operational checklist and quality standard. Actual source images were inspected for login, Home, Invest, Payments, Crypto and RevPoints (DESK-001/003–007). Actual target samples inspected include Home, Trips, BioPay, Profile, login and Admin recovery, plus the browser website and production Admin access page.

| Surface / family | Comparator and adaptations | Result |
|---|---|---|
| Native login / slate-indigo | DESK-001 typology; own logo, WhatsApp and passenger/driver selection | Family retained; exact native font/geometry and keyboard behavior unverified |
| Native Home / royal blue | DESK-003; mobility discovery replaces account content | Family retained in golden; shared navigation mismatch; standalone proof runtime fails |
| BioPay / teal | DESK-004 Invest pattern; own face/NFC/QR/USSD workflow | Family retained; shared navigation mismatch; hardware/provider outcome unverified |
| Trips/Nearby / purple | DESK-005 Payments pattern; actual Mobio trip actions retained | Family retained; shared navigation mismatch; live two-account trip management unverified |
| Wallet / muted slate | DESK-006 Crypto family; own ledger/subscription meaning | Source inspected; no independent manual target Wallet comparison completed |
| Profile/Mobio Plus / vivid violet | DESK-007; own numeric member identity and actions | Profile family retained; QF-06 mismatch; Plus manual comparison unverified |
| Pushed tasks and Admin | Neutral task / Business patterns | Sampled recovery and login inspected; operational table/bulk-action acceptance unverified |
| Public website | UK public marketing cohort, separate editorial typography | Sampled responsive layout, loaded font and menu behavior passed; complete source equivalence unverified |

Brand/content substitutions are required adaptations, not defects. Four Mobio tabs, mobility terminology and external USSD behavior are retained. The source screenshot phone frame/desktop surroundings are excluded from UI judgment; no private source image is redistributed in the evidence pack. Inter in native UI remains a target adapter rather than an asserted exact Revolut font.

Five independent quality results:

| Result | Conclusion |
|---|---|
| Source fidelity | **Mismatch** in shared navigation; exact equivalence elsewhere **unverified**. Regression goldens only show consistency with Mobio baselines. |
| Task usability | Public navigation and selected fixture interactions passed; **live Admin entry failed**. Full passenger/driver/operator end-to-end acceptance **unverified**. |
| Accessibility | Tested widget resilience and public menu behavior passed. Actual VoiceOver/TalkBack, complete web names/roles/focus/contrast and OTP assistance **unverified**. Web Flutter exposed an accessibility-enablement placeholder during inspection; that observation alone is not a conformance failure. |
| Performance | Production build passed; field performance and repeatable native/browser performance budgets **unverified**. Build duration is not user-perceived performance. |
| Runtime resilience | Local resilience tests passed; security boundaries and proof harness **failed**. Installed PWA offline/update/session isolation, hardware permissions and interrupted native tasks **unverified**. |

The [34 scoped operational checks](fullstack-qa-uat-20260906-criteria.csv) include their R001–R100 crosswalk and evidence classification. F07 user research/owner task acceptance was not performed. No aggregate pass rate or fidelity percentage is asserted.

## Remaining acceptance work

1. Close QF-01–04 and verify the deployed functions, database definitions/grants and website/Admin version. The denied management read left deployed SQL/RLS/catalog/storage/realtime evidence unavailable; local source tests cannot replace it.
2. Use designated passenger, driver and allowlisted Admin test accounts for OTP success/expiry/resend, role boundaries, two-user trip creation/edit/cancel, visibility, chat, notifications, profile persistence, Admin denied access, filtering/bulk failures and concurrent changes. No outgoing WhatsApp, chat or broadcast was sent in this review.
3. Test actual Android/iOS builds on appropriate devices: software keyboard/insets, accessibility, session restore, permission denial/recovery, camera and liveness, QR, NFC write/read, external dialer return, and subscription SMS reconnect/replay. One Android emulator and two iOS simulators were observed; no physical-device acceptance or new native release build was performed by this review. Existing other-task native work is not counted.
4. Verify installed Admin PWA identity, deep-link launch, session expiry, offline/reconnect, storage loss and update during active work. The offline reload attempt entered the browser's generated disconnected page; URL policy prevented further inspection/reset, so it is **unverified**. Only that temporary QA tab's network was emulated; system networking was unchanged. Temporary QA tabs are not retained as deliverables.
5. Review cache/version behavior before release: packaging sets long-lived cache rules for stable asset URLs, while Flutter 3.44.3 generated a service worker that unregisters itself. Effective live headers and two-version update behavior were not established. Require a real update test without clearing browser data.
6. Complete measured state-matched visual comparisons, including Wallet/Plus, keyboard/scroll, light/dark and native device samples, then obtain product-owner UAT acceptance. Golden stability and this review are distinct from that decision.

The retained `/biopay/pay/:token` route returned the marketing fallback in a live invalid-token probe. Current Get Payment Link source deliberately produces an external `tel:` USSD handoff, so that legacy HTTPS observation is **not** reported as a failure of today's Get Payment Link journey. Store listing HTTP availability also does not establish native release parity or store acceptance.

## Evidence and reproduction

Use the pinned Flutter executable under `/Volumes/PRO-G40/flutter_3_44/bin/flutter`. Commands executed included:

```text
flutter analyze --no-pub
flutter test --no-pub --coverage --reporter expanded
bash scripts/ci/verify_backend.sh
deno test --frozen --lock=deno.lock --allow-env supabase/functions
deno test --frozen=false --lock=build/qa/fullstack-uat-20260906/deno-all.lock --allow-env supabase/functions
deno test --frozen --lock=deno.lock --allow-env build/qa/fullstack-uat-20260906/face-auth-probe_test.ts
deno test --frozen --lock=deno.lock --allow-env build/qa/fullstack-uat-20260906/sms-auth-probe_test.ts
```

The two authorization probes intentionally assert rejection and currently fail; do not reinterpret that as a passing security gate. Their synthetic network handlers intercept every provider/RPC call. Build logs, screenshots, route inventory, UAT criteria, source hashes and evidence hashes are retained locally. Public runtime defines were handled separately and are excluded from the report/manifest.
