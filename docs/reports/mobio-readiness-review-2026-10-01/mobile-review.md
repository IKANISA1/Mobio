# Mobio mobile, native hosts and architecture review — 1 October 2026

## Assessment and coverage

The application has a credible feature-oriented architecture and substantial recovery/security controls. It is not sufficient evidence of a fully accepted production system. The current mobile source has specific iOS integration/configuration defects, asynchronous startup gaps and incomplete localization; release/device/provider acceptance must be established for the current artifact.

This is a read-only source review of the current dirty working tree. No Flutter build/test, device install, production API mutation or dependency upgrade was performed by this reviewer; the integration owner owns those checks. Existing user edits were preserved. `python3 scripts/ci/check_repository_structure.py` passed: **3,252 source/document files; Flutter 3.44.3**. This proves the rules implemented by that checker, not all runtime behavior.

Inventory excluded build, Pods, Gradle and symlink caches. It counted 283 Dart files under `lib/` (73,953 lines including generated localization), 51 relevant text files under `packages/` (6,189 lines), 28 Android host text files (1,998 lines), 9 iOS host text files (456 lines; the Xcode project itself was inspected separately), 35 receipt-collector text files (2,725 lines), and 192 test files (34,209 lines including generated/test fixtures). There is no root `integration_test/` directory. Inventory coverage is recursive; detailed inspection is risk-based and concentrated on startup, router, session/lease authority, client/account transitions, locations, messaging/recovery, privacy, native host adapters, dependencies and collector admission/upload/retention. It is not a claim that every line received individual human-equivalent review.

The Android host is **compileSdk/targetSdk 36**, minSdk 24, JVM 17 ([android/app/build.gradle.kts:38-50](/Volumes/PRO-G40/Projects/Recovered-G-PRO/Mobio/android/app/build.gradle.kts:38)). A current signed APK is known to the integration owner; do not replace that fact with old reports about API 35 or unconfigured builds. Whether its native dependencies, signer, configuration and acceptance evidence match the final source is a separate artifact check.

## Product authority

The limited discovery/scheduled-post marketplace retains WhatsApp identity, external Google Maps handoff and no Mobio route computation. Approved public transport and noncustodial payment expansions are supported scope, not reasons to delete features. In particular `docs/product/face-ussd-20260920/APPROVAL.md:3-5` supersedes earlier AWS/liveness/review-before-dial requirements **for the face shortcut only**. The current contract is a non-authentication, amount-free shortcut with external USSD. Deployment/provider/device acceptance remains separate. The sole visual authority is the external Revolut skill; this review makes no fidelity certification.

## Confirmed defects and implementation risks

Severity: P1 means a supported platform/important capability should be corrected before that capability is promoted; P2 means material reliability/product debt; P3 means bounded maintenance debt. Confirmed source/configuration findings are distinguished from unexecuted native effects.

### MOB-M01 — P1: iOS location permission strategy is compiled out

**Evidence:** [ios/Podfile:38-44](/Volumes/PRO-G40/Projects/Recovered-G-PRO/Mobio/ios/Podfile:38) sets the deployment target but supplies no permission-handler preprocessor definitions. [lib/core/permissions/app_permission_service.dart:41-59](/Volumes/PRO-G40/Projects/Recovered-G-PRO/Mobio/lib/core/permissions/app_permission_service.dart:41) requests `Permission.locationWhenInUse` and `Permission.locationAlways`, and [lib/core/location/location_service.dart:84-89](/Volumes/PRO-G40/Projects/Recovered-G-PRO/Mobio/lib/core/location/location_service.dart:84) stops acquiring position if this gate does not grant access. The installed locked `permission_handler_apple` 9.4.7 defaults `PERMISSION_LOCATION` to 0 (`ios/Classes/PermissionHandlerEnums.h:64-69` in the package cache); its disabled location strategy inherits `UnknownPermissionStrategy`, which returns denied/permanently denied instead of requesting Core Location (`strategies/LocationPermissionStrategy.h:9-21`, `UnknownPermissionStrategy.m:11-20`). No compensating macro was found in the repository's iOS configurations.

**Impact:** the intended native permission path cannot request iOS location through the current CocoaPods configuration, affecting nearby discovery and driver live sharing. The source configuration defect is confirmed. No iOS build/device reproduction was executed in this review, and a previously built binary may have different generated settings.

**Remediation:** enable the narrowly required `PERMISSION_LOCATION=1` definition for the locked CocoaPods plugin in the canonical Podfile, with inherited definitions retained. Avoid enabling unrelated permission families.

**Acceptance:** inspect resulting plugin build settings in a clean iOS build; on physical iPhone verify initial When In Use request, grant, denial, restricted/permanent denial, Settings return, and explicit driver Always escalation. Match build hash/signing identity and record runtime observations. [Locked package setup](https://pub.dev/packages/permission_handler/versions/11.4.0).

### MOB-M02 — P1: global NFC polling starts the iOS reader UI without an NFC action

**Evidence:** [lib/app/app.dart:65-85](/Volumes/PRO-G40/Projects/Recovered-G-PRO/Mobio/lib/app/app.dart:65) wraps every routed screen in `BioPayNfcForegroundListener`; [lib/features/biopay/presentation/biopay_nfc_foreground_listener.dart:92-95,114-120](/Volumes/PRO-G40/Projects/Recovered-G-PRO/Mobio/lib/features/biopay/presentation/biopay_nfc_foreground_listener.dart:92) starts/restarts `_ensureLoop` at first frame/resume. `_runLoop` calls `FlutterNfcKit.poll` with an iOS alert at `:285-305`, without an iOS platform exclusion or user scan action. The locked 3.6.2 plugin creates `NFCTagReaderSession` and calls `begin()` for poll (`ios/flutter_nfc_kit/Sources/flutter_nfc_kit/FlutterNfcKitPlugin.swift:60-85`). Apple documents that beginning this session displays an alert. The native Android reader and iOS modal session are different behaviors.

**Impact:** NFC-capable iPhones can receive a scan sheet on login, discovery, profile, admin or after resume. Its global lifecycle can interrupt non-NFC journeys and race explicit NFC workflows. This initiation path is confirmed in code; modal repetition and foreground transitions have not been reproduced on iPhone here. The finding does not assert that Android's passive reader has the same defect.

**Remediation:** permit iOS CoreNFC polling only inside an explicitly started NFC workflow. Retain safe Android intent/native foreground-reader handling. Make cancel/timeout release exactly one session, with no automatic iOS prompt on resume.

**Acceptance:** launch/login/browse/resume on iPhone without an NFC sheet; explicitly start, cancel, time out, scan and resume NFC; verify one modal/session and one navigation result, plus Android cold/warm intent behavior. [Apple Core NFC session UX](https://developer.apple.com/documentation/corenfc/building-an-nfc-tag-reader-app).

### MOB-M03 — P1 for iOS link-dependent journeys / P2 overall: native deep-link ownership and scene integration are unresolved

**Evidence:** [pubspec.yaml:49](/Volumes/PRO-G40/Projects/Recovered-G-PRO/Mobio/pubspec.yaml:49) / [pubspec.lock:36-43](/Volumes/PRO-G40/Projects/Recovered-G-PRO/Mobio/pubspec.lock:36) pin `app_links` 6.4.1. [ios/Runner/Info.plist:56-75](/Volumes/PRO-G40/Projects/Recovered-G-PRO/Mobio/ios/Runner/Info.plist:56) selects `FlutterSceneDelegate`, while the installed plugin registers only an application delegate and has application `open`/`continue` callbacks (locked `AppLinksIosPlugin.swift:36,76-98`), with no scene callbacks. [ios/Runner/AppDelegate.swift:20-26](/Volumes/PRO-G40/Projects/Recovered-G-PRO/Mobio/ios/Runner/AppDelegate.swift:20) does not supply a custom scene-to-plugin forwarding bridge. Both native manifests omit Flutter's third-party-handler opt-out (`FlutterDeepLinkingEnabled=false` / `flutter_deeplinking_enabled=false`). Meanwhile NFC (`biopay_nfc_foreground_listener.dart:241-281`) and referral (`referral_attribution_service.dart:27-36`) subscribe through AppLinks. The router has no `/invite/:code` entry despite Android's declared `/invite` intent (`AndroidManifest.xml:80-87`).

**Impact:** two competing link paths and the old iOS callback model can produce dropped or conflicting NFC/payment/referral arrivals under the scene lifecycle. Configuration/compatibility mismatch is confirmed; exact cold/warm-device failures require execution. Do not blindly disable Flutter's path before confirming the plugin receives scene events, because doing so can remove the currently working fallback.

**Remediation:** choose one native link owner and centralize validated arrival/deduplication. Integrate a scene-compatible app_links release or an explicit supported forwarding adapter after reviewing its migration and platform/toolchain constraints. Then apply the appropriate Flutter handler flags and resolve invite navigation intentionally.

**Acceptance:** signed Android/iOS cold, warm and resumed tests for HTTPS invite, payment token, NFC and custom scheme; revoked/expired auth, malformed/external URI and duplicate delivery; assert exactly one destination and retained referral intent. Inspect live assetlinks/AASA and signing/team identities independently. [Flutter handler guidance](https://docs.flutter.dev/ui/navigation/deep-linking), [app_links scene migration](https://pub.dev/packages/app_links/changelog), [Flutter scene migration](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate).

### MOB-M04 — P2: slow Firebase initialization permanently skips push initialization in the process

**Evidence:** [lib/app/bootstrap.dart:104-110](/Volumes/PRO-G40/Projects/Recovered-G-PRO/Mobio/lib/app/bootstrap.dart:104) gives Firebase initialization six seconds and returns immediately when that wrapper is incomplete. `runStartupTask` does not cancel the underlying initializer ([lib/core/async/startup_task.dart:7-13](/Volumes/PRO-G40/Projects/Recovered-G-PRO/Mobio/lib/core/async/startup_task.dart:7)). Firebase waits for anonymous auth, Remote Config and reporting configuration (`firebase_bootstrap_service.dart:57-75`); Remote Config alone can spend twenty seconds fetching (`firebase_remote_config_service.dart:37-50`). No other caller initializes PushNotificationService in `lib/`.

**Impact:** Firebase can become ready after six seconds while the continuation that registers foreground/opened/background push handlers never runs. Shell auth events may register a token later, but do not install those handlers. `_firebaseAvailable` also remains false, suppressing bootstrap fatal forwarding. This is a confirmed control-flow gap, not a claim that the provider is currently down.

**Remediation:** keep first render independent, but retain one underlying initialization Future and continue optional service attachment when it genuinely settles. Never start a second initializer just because the UI wait expired. Separate local SDK attachment and defaults from slow remote fetch when compatible.

**Acceptance:** deterministic startup orchestration tests for success before six seconds, late success after six seconds, network/Remote Config failure and permanent SDK failure; prove one initialization/handler set, no first-render block, no unhandled late Future and eventual working push after late success.

### MOB-M05 — P2: route screen analytics observer is captured before analytics attaches

**Evidence:** `app_router.dart:257-260` takes `FirebaseAnalyticsService.instance.observers` when the router is created; `firebase_analytics_service.dart:27-33` returns an empty list while `_analytics` is null. The main app creates/caches its router (`app.dart:29-30,95-96`) before post-frame Firebase initialization (`bootstrap.dart:71-76`), and analytics attaches later (`firebase_bootstrap_service.dart:58`). No observer-list refresh exists.

**Impact:** the custom bounded screen observer is absent for the process even when Firebase subsequently succeeds. Native automatic activity telemetry is not evidence that Flutter screen transitions are recorded. This is a confirmed initialization-order defect; live event receipts were not queried.

**Remediation:** install a stable observer immediately that can send after service attachment, or explicitly attach observers without reconstructing live navigation history.

**Acceptance:** navigate before and after delayed Firebase attachment; verify expected screen events once, same router/navigation state and bounded failure behavior.

### MOB-M06 — P2: supported French/Kinyarwanda localization is largely disconnected from app UI

**Evidence:** three localized ARB/generated locale families exist and `app.dart:59-63` advertises them. Excluding generated localization, only `payment_widgets.dart` and `biopay_nfc_foreground_listener.dart` consume AppLocalizations. Core journeys still contain English labels: `bookings_screen.dart:204-208,273-287` (TODAY/TOMORROW/LATER/Trips/Mine/Nearby), `admin_session_boundary.dart:145-149`, `privacy_request_screen.dart:219,235-240`, and navigation item constants in `app/shell.dart:250` onward. PaymentCopy localizes some payment journeys; that does not localize the rest of the app.

**Impact:** a device French/Kinyarwanda locale receives a mixed-language experience in discovery, OTP, booking, profile, privacy and admin, with English operational/recovery instructions. This is a confirmed product gap, independent of visual fidelity.

**Remediation:** move all visible app copy through the current localization source, including validation/errors, native handoff/disclosure copy and plural/date/number handling. Review Rwanda-specific terms with language reviewers. Preserve Mobio's feature semantics.

**Acceptance:** route/state coverage per EN/FR/RW including long copy, 200% text scale, consent/denial/error/unknown outcome and screen reader names. ARB parity alone is insufficient. Existing product claims should describe the implemented language coverage until accepted.

### MOB-M07 — P2: unavailable permission plugin is converted to granted

**Evidence:** `AppPermissionService._safeReadStatus` and `_safeRequestPermission` return `PermissionStatus.granted` for MissingPluginException/UnimplementedError (`app_permission_service.dart:120-145`). These helpers are used when runtime permissions are expected on Android/iOS.

**Impact:** a missing native integration is represented as permission success, masking configuration defects and sending the UI down a location-sharing path the platform cannot support. OS-level permission enforcement remains separate; this is not proof of unauthorized location access.

**Remediation:** return a distinct unavailable state or fail the permission action on a platform that requires the plugin; restrict any test/unsupported-platform fallback to explicitly injected testing/preview behavior.

**Acceptance:** missing channel and unimplemented strategy yield unavailable/retry/settings guidance rather than granted. Native grant/denial behavior still passes.

### MOB-M08 — P2: stale OS location is refreshed into the app's fresh cache

**Evidence:** `LocationService.getLastKnownOrCached` accepts any OS last-known Position and calls `_remember` (`location_service.dart:117-130`); `_remember` records DateTime.now rather than validating `position.timestamp` (`:164-167`). `hasFreshCachedPosition` only checks this local acquisition time (`:32-37`).

**Impact:** an hours-old fix may become a fresh two-minute autocomplete/discovery bias. Driver sharing explicitly requests a new fix at `driver_location_sharing_service.dart:128-130`, which reduces the live-sharing impact; do not conflate this with invented route ETA support.

**Remediation:** validate age/accuracy and reject or explicitly label stale OS fixes; keep acquisition time separate from fix time. Add bounded clock-skew handling.

**Acceptance:** old/future/recent timestamps, poor accuracy, permission loss, disabled services and new account transitions cannot silently promote stale position to fresh.

### MOB-M09 — P2: receipt upload has socket timeouts but no total request budget

**Evidence:** `apps/momobio_sms_bridge/.../UploadClient.kt:89-97` sets connect/read timeouts but performs output write and all subsequent reads synchronously; response loop at `:156-165` has byte bounds but no monotonic total deadline. `CollectorSync.kt:13-27` retains the shared OS lease during upload. README acknowledges this limitation at `:157-159`.

**Impact:** a stalled write or sufficiently slow streaming response can retain the sync owner much longer than the UI's expected request duration, delaying workers and queue drain during provider degradation. This is a confirmed missing total-budget control; no adverse production connection was induced.

**Remediation:** add an overall deadline that closes the actual connection and preserves one underlying completion/lease owner, with unknown outcomes reconciled by existing message hashes. Do not falsely acknowledge or discard pending rows.

**Acceptance:** stalled connect/write, trickled response, cancellation while worker runs, response-loss-after-commit and partial ACK preserve original receipts and permit bounded recovery. Avoid retries that outlive or overlap the leased owner.

### MOB-M10 — P3: unreachable legacy payment screens remain beside active replacements

**Evidence:** `app_router.dart:688-723,778-788` routes current request/QR/link/NFC-writing journeys to PaymentRequestEditor, PaymentLinkArrivalScreen and PaymentNfcLinkScreen. `BioPayQrScreen`, `BioPayRequestPaymentScreen`, `BioPayPaymentLinkScreen` and `BioPayNfcWriteCardScreen` have no application source consumers beyond their own definitions (full lib import/name search); tests continue exercising them. The old NFC screen and USSD data service still have active callers, so they are not wholesale deletion candidates.

**Impact:** tests can validate unreachable presentation while active successors drift; competing implementations enlarge review and refactor risk. Current user edits include legacy request-screen changes, so deletion requires preserving that work and resolving its intent.

**Remediation:** make an explicit route-to-implementation register, migrate meaningful acceptance to active route consumers and remove only confirmed orphan implementations after preserving unique behavior/evidence. Avoid deleting whole BioPay folders.

**Acceptance:** every product route has one canonical consumer; retained compatibility adapters are documented; active-route tests cover the migrated behavior; no dangling imports or lost pending edits.

### MOB-M11 — P3: dependency and screen-size maintenance debt

**Evidence:** source import scan found no direct consumers of `cupertino_icons`, `shimmer`, `cached_network_image`, `app_settings` or `device_info_plus` in lib/test/packages, although all are root dependencies. [pubspec.yaml](/Volumes/PRO-G40/Projects/Recovered-G-PRO/Mobio/pubspec.yaml) retains them. Several mixed presentation/state/side-effect files are large: wallet screen 2,044 lines, broadcasts 1,510, BioPay shared flow 1,481, chat 1,317, subscriptions 1,243, schedule trip 1,096. Router is 792 lines.

**Impact:** unnecessary plugin/native capability footprint and large change surfaces complicate dependency upgrades, targeted reviews and platform testing. File length alone is not a defect or reason for a replacement architecture.

**Remediation:** check transitive/generated/native use before pruning direct dependencies; compare lockfile and merged capabilities/artifact size. Incrementally extract operation controllers and cohesive presentation sections from the largest active screens, retaining account epochs, operation IDs and authority checks. Add feature route factories only if it preserves guards/deferred loading.

**Acceptance:** unchanged external contracts/current auth/mutation recovery, appropriate required tests and platform build, reduced direct plugin set or measured review boundaries. Do not upgrade every package to its newest major as a generic cleanup.

## Strengths to retain

- Implemented app/bootstrap/router boundaries and feature application/data/domain structure. Shared model/design packages are separate; repository structure and transitive imports are checked. Generated model ownership is explicit in `bootstrap_flutter.sh:8-11`; ignored parts must be regenerated on a clean checkout, not copied from arbitrary archives.
- `AccountContext` binds verified provider/user/session to a local accepted persistence generation (`account_context.dart:104-129`), serializes SDK mutation, fences logout and rejects stale asynchronous login completions. Anonymous Auth is bootstrap only, not product identity.
- Server-lease-aware admin routing (`app_router.dart:110-147`), monotonic idle/absolute deadlines (`admin_session_guard.dart:13-34`) and foreground/blur masking (`admin_session_boundary.dart:110-164`). A client gate still needs backend authority and deployed checks; do not remove independent server enforcement.
- Android session envelopes use Keystore AES-GCM with namespace-bound AAD, atomic writes/readback, excluded backup and bounded reads (`SecureSessionChannel.kt:38-95`, `SessionCipher.kt:23-55`). iOS uses device-only nonsync Keychain plus an excluded installation marker to avoid silently restoring surviving Keychain login after reinstall (`AppDelegate.swift:193-259`).
- Six-digit public member IDs are validated independently of backend UUIDs (`mobio_member_id.dart:1-20`, `profile_wire_record.dart:11-24`). Do not change backend UUID identity into a six-digit storage key.
- Account-owned chat delivery persists only a recovery pointer/hash, uses stable client IDs, server status/close receipts and no automatic background replay (`chat_delivery_coordinator.dart:12-151`). A successful send is not incorrectly relabeled failed when ACK cleanup fails.
- Privacy requests use captured bearer/account, schema/owner validation and unknown mutation outcomes (`privacy_service.dart:33-94`). Profile exposes an in-app initiation screen; submission honestly differs from completed erasure.
- Push bindings validate current owner/session and opaque binding before navigating, generic notification copy protects lock-screen content, local notifications clear on account change, server inbox/RLS loads content (`push_notification_service.dart:146-255`). Keep these protections when fixing startup.
- Driver sharing serializes mutation/compensation and discards superseded authority (`driver_location_sharing_service.dart:93-227`); fresh driver fix bypasses stale cache fallback.
- Camera capture bounds size/wait, disposes late initializers and deletes temporary images in underlying completion (`face_capture.dart:22-88`); face screens stop camera on account/lifecycle changes and reject stale shortcut handoff (`biopay_face_scan_screen.dart:50-178`).
- Collector is separate from consumer app. Policy fingerprint-bound notice, RECEIVE_SMS instead of historical READ_SMS, nonexportable signed device identity, SQLite durable main/overflow/refusal evidence, known ACK hashes, bounded batches and a shared uploader lease are meaningful controls. These do not authenticate the original SMS sender or SIM owner.
- Release helpers use a shared allowlisted runtime parser, Android release signing rejects absent key.properties, no-codesign iOS check is explicitly distinct from signed distribution, and public values are injected into builds. Preserve `.env` and private key exclusion.

## Unverified production gates and approved-but-incomplete journeys

| Area | Current source / existing evidence | Required acceptance before promotion |
|---|---|---|
| Android consumer binary | API 36 source and a current signed artifact exist; no build performed by this reviewer | Bind final tree/transitive config to exact APK/AAB and signer; install/update/rollback; Play track and current disclosures; validate native ELF/zip 16 KB alignment and execute a 16 KB device/emulator test. A modern SDK alone does not prove prebuilt libraries align. |
| iOS consumer | Scene registration, Keychain and entitlements implemented; RunnerTests remains empty template at `RunnerTests.swift:5-10` | Clean unsigned compile plus signed archive, team/provisioning/APNs/NFC domains, physical iPhone permission/link/NFC tests; Keychain corruption/lock/reinstall and photo-picker/save callback behavior; accepted App Store listing. |
| Authentication | Provider/session/exit fencing implemented and unit/widget tests substantial | Live WhatsApp delivery rate/latency, resend/expiry/bruteforce, account/admin switch, app kill during restore/signout, offline restart and server role/lease revoke. Store login reviewer instructions with permitted test access. |
| Public transport | Agency and booking-specific service contracts exist in `public_transport_service.dart:150-365` | Root bookings presentation remains scheduled post UI; there are no `holdSeats`, `searchSchedules` or `confirmBooking` callers in those screens. Complete approved passenger departure/seat/hold/payment/ticket/history and agency operations journeys, or document them as unavailable pilot scope. Backend receipt authority must remain server owned; the service's client confirm API is not proof of safe paid booking. |
| Face shortcut | New dated approval and guarded capture/handoff code exist | Confirm remote feature disabled until approved endpoint/model/provider/version evidence; false match/no-match/duplicates, biometric consent/retention/deletion, phone/operator USSD compatibility, physical-camera acceptance. The approved no-liveness shortcut is not login or payment authorization. |
| NFC/QR | Host reader/HCE and tag/profile request flows implemented | Cross-device physical NDEF/APDU/HCE tests, foreground/screen-lock rules, expired/cancelled token, unknown method completion, paired Android/iOS platform fallback; do not claim iOS HCE parity. |
| Push | Owner-bound client protocol implemented | Actual FCM/APNs token registration, revoke/rotate/consent transitions, terminated/background/foreground delivery, invalid/bad binding, generic lock-screen payload and provider receipt/latency alarms on current builds. |
| Privacy/deletion | In-app request/status/cancel implemented | End-to-end deletion worker and external face/provider cleanup, retained-record exceptions, export/download/auth revocation, timeframe and operation owner; completed receipt bound to exact request. In-app intake alone is not an executed deletion. |
| Background location | Explicit sharing APIs and native declarations exist | Driver consent/disclosure, approximate/precise/Always, foreground-service notification, stop/logout, revoked permission, OEM Doze/reboot/force-stop, battery/network burden and backend stale-location expiry. Play core-functionality permission acceptance is separate from a local build. |
| Collector | Portable and native-device test sources, engineering recovery procedure and private distribution/signing checks exist | Execute the exact-version matrix in `docs/operations/collector-acceptance-2026-09-28.md:21-49`; dedicated SIM/custodian/enrollment, cryptographically trusted downstream allocation evidence, retention/recovery approval and fleet drill. Missing recovery/quarantine UI is admitted at `:62-69`. No unsafe schema rollback/debug-signer replacement. |
| Performance/accessibility | Deferred routes, bounded requests, skeletons and a startup profiler script exist | Signed profile-mode low-memory/slow-network traces, first usable frame, dropped frames, memory/thermal/battery/offline recovery, TalkBack/VoiceOver plus text scaling/keyboard/focus for every active route/state. No current field/device performance certification was obtained by this review. |
| Supply chain | Locked Dart/CocoaPods and pinned toolchain; custom licensed lucide compatibility package | Current dependency/advisory/SBOM review by ecosystem, compatible controlled updates, required privacy-manifest contents in archived app and license notices. This review does not assert no vulnerabilities from a successful analyzer. |

Platform research: [Android 16 KB artifact verification](https://developer.android.com/guide/practices/page-sizes), [Google Play background location evidence](https://support.google.com/googleplay/android-developer/answer/9799150?hl=en), [Apple in-app deletion requirements](https://developer.apple.com/support/offering-account-deletion-in-your-app/). Applicable deadlines/Console-specific extensions must be checked against the actual distribution account; no generic deadline substitutes for artifact compatibility.

## Recommended order

1. Resolve native iOS permission, explicit NFC and link ownership/scene compatibility together; keep one integration owner and one current build per platform identity.
2. Correct optional startup late completion and install stable analytics observers; verify slow/offline/recovered-provider cases.
3. Reconcile current backend/device/signed artifact evidence with the above matrix before enabling financial/biometric/background capabilities.
4. Finish active EN/FR/RW route/state localization and platform accessibility acceptance.
5. Incrementally retire confirmed orphan screens/direct plugins and decompose high-risk active operation boundaries. Preserve existing recoverable state, dated approvals and historical migration/evidence records.

Memory was used to locate past priorities only; no historical pass/count/deployment status is promoted to current proof. Relevant registry references: `/Users/jeanbosco/.codex/memories/MEMORY.md:379-392`, rollouts `01a0e2fd-641b-72d0-8c69-d9da5dc77cdd` and `01a0e91e-9bc3-7690-9772-03b7383b7f8f`. Newer source approvals and current code take precedence.
