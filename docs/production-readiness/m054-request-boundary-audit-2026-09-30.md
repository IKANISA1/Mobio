# M054 application request boundary audit

Reviewed: 30 September 2026. This records local source implementation and focused verification. Deployment, physical devices, providers and store acceptance remain separate release evidence.

## Result and request semantics

The active Flutter application's finite HTTP, RPC, Edge Function, native plugin and presentation handoff boundaries were reviewed by call site, including calls made directly from widgets. No remaining unbounded active transport/native observer was identified after the changes below. Long-lived subscriptions, explicit user modal choices and safety-critical real-completion queues are detailed separately.

`RequestDeadline.read` limits an observer's wait, normally to 15 seconds. `RequestDeadline.mutation` normally waits 20 seconds and reports `MutationOutcomeUnknownException` when the reply is lost. A Dart timeout does not cancel the native callback or prove that a server transaction rolled back. These adapters do not automatically retry writes.

The lost-response classifier covers timeout, socket/HTTP/client transport loss, Dio connection/send/receive timeouts, underlying native transport errors and proxy response loss. For the locked PostgREST SDK, a non-JSON proxy failure uses a numeric HTTP 500–599 fallback code; this is uncertain. Structured SQLSTATE errors such as `23505` and `42501`, and explicit `PT503`/`XX000` rejections retain their known rejection type. Structured Dio responses remain explicit responses. Tests exercise the real Supabase HTTP adapter and a real Dio adapter.

`ExternalAction` bounds clipboard, system share and external link callbacks at 60 seconds, allowing time for the OS UI. It observes fire-and-forget failures. Awaited success UI appears only after acknowledgement; uncertain mutations retain safe `AppException` copy where a result is presented.

## Requirement to implementation evidence

This final pass searched transport and native calls across `lib/`, including direct presentation calls, and inspected their enclosing adapters and actual-completion tails. The module table below records that active call-site inventory. The following tests prove representative failure behavior; they are not a claim that every service is covered by one universal integration test.

| M054 requirement | Current implementation evidence | Executable evidence |
| --- | --- | --- |
| A finite observer for each active read | `core/async/request_deadline.dart:14`; read wrappers in admin/profile/chat/bookings/notifications/privacy/BioPay services; `core/location/places_service.dart:31` also bounds connectivity before HTTP dispatch | `test/core/async/request_deadline_test.dart`; `test/core/location/places_connectivity_deadline_test.dart` |
| Lost write reply is uncertain, without automatic repeat | `core/async/request_deadline.dart:20` preserves operation identity and differentiates explicit rejection from response loss; wallet/chat retain their operation journals and status reconciliation | `test/core/async/request_deadline_test.dart`; `test/increment06/chat_delivery_test.dart`; `test/features/profile/data/wallet_service_boundary_test.dart` |
| Successful transport does not imply a usable mutation receipt | `features/biopay/data/biopay_face_service.dart:31` restricts write statuses to the current provider/SQL contract; malformed enroll/resolve success retains its operation ID as `OUTCOME_UNKNOWN`. `features/privacy/data/privacy_service.dart:9` applies the same semantics to request/cancel receipt and owner/ID correlation. Device NFC requires current-token/expiry correlation and an acknowledged disabled state after stop | `test/features/biopay/data/biopay_face_service_boundary_test.dart`; `test/features/privacy/data/privacy_service_boundary_test.dart`; `test/features/biopay/biopay_device_nfc_service_test.dart` |
| OTP send has a total HTTP deadline and no automatic resend | `features/auth/data/whatsapp_login_service.dart:88`; corresponding admin send adapter; both login screens retain cooldown and existing code entry after unconfirmed delivery. Optional display message types use safe fallbacks without relabeling a confirmed send or explicit rejection | `test/features/auth/data/otp_send_outcome_test.dart`; `test/features/auth/whatsapp_login_screen_test.dart` |
| Native/device request observers are finite | Permission, location, Face capture, NFC card/foreground/device and QR camera adapters in the table below | `test/core/permissions/app_permission_deadline_test.dart`; `test/features/biopay/biopay_nfc_service_deadline_test.dart`; `test/features/biopay/biopay_scan_recovery_test.dart` |
| A timeout cannot release authority for a still-running native/session write | Secure storage/account SDK tails; `features/biopay/data/biopay_device_nfc_service.dart:19`; foreground single-flight start; QR camera tail; analytics context tail | `test/increment08/native_session_read_deadline_test.dart`; `test/features/biopay/biopay_device_nfc_service_test.dart`; `test/features/biopay/biopay_nfc_foreground_deadline_test.dart`; `test/core/firebase/firebase_analytics_deadline_test.dart` |
| Direct presentation and external callbacks are bounded | `core/async/external_action.dart:9`, direct bounded health RPCs, payment image/phone/gallery/export callbacks and all clipboard/link/share callers in the module inventory | `test/core/async/external_action_test.dart`; `test/features/admin/admin_modal_account_guard_test.dart`; NFC/accessibility fixture cases below |
| Late replies cannot authorize old account or lifecycle work | Current-account checks at service/widget boundaries; generation checks before queued native dispatch; retained suspension lease authority for cleanup after observer expiry, invalidated by a newer lease | `test/features/biopay/data/account_callback_service_race_test.dart`; `test/features/biopay/payment_methods_account_race_test.dart`; `test/features/biopay/biopay_device_nfc_service_test.dart`; separate M055 coverage report |

## Active module coverage

Paths are relative to the repository root. Groups list the actual modules containing the boundaries, including direct presentation calls.

| Module and files | Reviewed boundary and retained behavior |
| --- | --- |
| App startup: `lib/app/bootstrap.dart`, `shell.dart`, router wrappers | Startup tasks have finite observers. Auth, push, location sharing and NFC cleanup are account/lifecycle fenced. Route and modal completion is user driven. |
| Auth: `core/auth/account_context.dart`, `session_persistence.dart`, `auth_session_storage.dart`, `supabase_session_service.dart`, `auth_storage_recovery_view.dart` | Secure native reads wait 5s and fail closed; a late read cannot establish trust. Prepare/restore/commit/abort/logout observers are finite. Native write/clear/reset and SDK transitions retain their actual-completion queues. |
| Integrity: `core/auth/play_integrity_service.dart` | Challenge HTTP and native token callbacks each wait at most 15s. OTP evidence observers also limit their wait. Unavailable evidence does not grant verification. |
| Admin lease: `core/auth/admin_session_service.dart` | Status/touch waits 8s and revoke 3s. Unconfirmed status revokes local lease; logout remains locally fenced. No optimistic lease grant. |
| OTP: `features/admin/data/otp_service.dart`, `features/auth/data/whatsapp_login_service.dart`; both login screens | Send HTTP has a total 15s observer and distinguishes unconfirmed delivery from explicit rejection; passenger integrity preflight separately waits at most 6s. The UI permits entering an already-delivered code, retains a resend cooldown and never automatically resends. Verification remains fail closed with ticket validation, finite restore/commit/abort observers and a 4s admin rejection exit observer. |
| Firebase: `core/firebase/firebase_bootstrap_service.dart`, `firebase_auth_service.dart`, `firebase_remote_config_service.dart`, `firebase_analytics_service.dart` | Initialize 8s, anonymous infrastructure auth 15s, remote configuration settings/defaults 5s and fetch 20s, collection/telemetry/Crashlytics callbacks 4s. Route observer telemetry uses the same bounded adapter. User ID/role context writes preserve actual native completion ordering and skip superseded role updates. Best-effort telemetry observes late errors and never resends automatically. |
| Permissions/location: `core/permissions/app_permission_service.dart`, `core/location/location_service.dart` | Status/service/last-location/GPS callbacks have finite Dart observers; permission prompt waits at most 60s. Settings launch is an uncertain native action. GPS keeps its native time limit as well as the Dart observer. Permission is reread on a later user action. |
| Places/maps: `core/location/places_service.dart`, `google_maps_deep_link_service.dart` | Connectivity precheck waits 4s, then bounded read-only lookup proceeds if the precheck is unavailable. Autocomplete reads use 6s attempts; details/geocoding use 10s attempts, two attempts maximum and one 800ms delay. Maps launch has a finite mutation observer. No route-computation capability was added. |
| Nearby: `features/nearby/data/driver_location_service.dart`, `driver_location_sharing_service.dart`, `nearby_discovery_service.dart` | Discovery reads and location writes are finite; periodic location sharing is an explicit ongoing stream with session checks. Start/stop preserves actual-completion ordering of the location mutation tail and finite caller observers. |
| Scheduled/public transport: `features/bookings/data/trip_service.dart`, `public_transport_service.dart` | HTTP/RPC reads and all create/update/cancel/hold/confirm writes are bounded. Transport mutation IDs/receipt correlation support reconciliation; no new dispatch, trip settlement or route tracking was introduced. |
| Chat: `features/chat/data/chat_service.dart`, `chat_delivery_coordinator.dart`, `chat_delivery_store.dart`; `presentation/chat_screen.dart` | Query and mutation wrappers bound every RPC, including get/create, block/unblock/report/read marks and delivery status/send/close. A lost send keeps its stable client-message pointer and resolves through status without another send. Realtime unsubscribe has a 3s observer. WhatsApp links use `ExternalAction`. |
| Notifications: `features/notifications/data/notification_service.dart`, `notification_consent_service.dart`, `push_notification_service.dart` | Inbox/consent writes distinguish unknown outcomes; reads are finite. Push initializes/status/token/native presentation/storage observers wait 4s, permission prompts 60s. Registration and revocation use exact owner/session/binding and finite unknown-mutation adapters. Cleanup errors do not block remote revoke. |
| Profile/catalog/countries: `features/profile/data/profile_service.dart`, `favorite_address_service.dart`, `vehicle_type_service.dart`, `subscription_plan_service.dart`, `core/localization/country_service.dart` | Catalog/profile/country reads and mutations use finite adapters and appropriate account checks; mutations are not blindly retried. Country lookup retains its approved public fallback. |
| Referrals: `features/profile/data/referral_service.dart`, `referral_attribution_service.dart` | Server reads/writes, initial app-link and install-referrer callbacks are bounded. Only opaque local attribution markers are stored; live link stream is ongoing and owner-bound signup processing rechecks its snapshot. |
| Existing wallet/Driver Plus: `features/profile/data/wallet_service.dart`, `wallet_operation_journal.dart`, `driver_plus_service.dart`; both screens | Wallet persists its operation pointer before execution, retains unknown outcomes and reconciles using the same operation ID. Driver Plus reads/write receipts and Android dial-intent callbacks are bounded. Share/copy/link actions have finite observers. No automatic financial re-execution. |
| Privacy: `features/privacy/data/privacy_service.dart`, `presentation/privacy_request_screen.dart` | Edge Function reads versus mutations are separated, bounded and account fenced. Malformed successful request/cancel replies, wrong owner/ID and unusable receipts report unconfirmed outcome with the original request ID; explicit server rejections remain known. Contact links have finite external-action observers. |
| EV chargers: `features/ev_chargers/data/ev_charger_service.dart`, `presentation/ev_charger_locator_screen.dart` | Catalog/discovery reads and admin writes are bounded. External Maps launch is bounded. |
| Admin data: `features/admin/data/admin_base_service.dart`, `admin_service.dart`, user/trip/dashboard/broadcast/compliance services | Every server read/write uses the shared finite adapter. Structured write rejections remain known; transport loss remains uncertain. Direct push/privacy operational-health widget RPCs also have finite read observers. |
| BioPay requests/discovery: `features/biopay/data/biopay_ussd_service.dart`, `biopay_admin_service.dart`, `payment_discovery_service.dart` | Request/admin/discovery reads and writes are separated and bounded. Phone/image picker callbacks wait 20s; reviewed Android dial intent 10s. Actual payment execution remains outside this adapter. |
| BioPay Face: `features/biopay/data/biopay_face_service.dart`, `face_capture.dart`; enrollment and scan screens | Edge Function reads/write uncertainty use the shared adapter. Successful mutation status must match the current provider/SQL contract; absent/unknown status and unusable enroll/resolve receipts are unconfirmed with original operation identity. Status-read parsing failures remain known unavailable reads. Camera enumeration/open/capture/stop observers wait 8s. A late open after cancellation disposes itself. Temp image cleanup stays attached to actual capture completion. |
| BioPay NFC card: `features/biopay/data/biopay_nfc_service.dart`, `biopay_nfc_card_payload.dart`; write-card screen | Availability, poll, physical write/lock, readback and cleanup all have finite observers. Lost physical write/lock replies and unreadable post-write state are unconfirmed; no repeat physical write. Readback retry budget is finite and a native read timeout stops overlapping retries. Cleanup loss does not relabel an independently verified receipt as failed. |
| BioPay device NFC: `features/biopay/data/biopay_device_nfc_service.dart`; NFC screen; `android/app/src/main/kotlin/rw/mobi/app/MainActivity.kt` and `BioPayNfcPolicy.kt` | Start/stop are bounded uncertain mutations at 6s, status is bounded read at 5s. Successful native mutation acknowledgements require boolean supported/enabled fields. Active start must retain the original token and a valid future expiry no later than the original request at millisecond precision; native five-minute clamping remains legitimate. Stop must acknowledge enabled:false. Null/scalar/list/missing/mistyped/contradictory receipts remain unconfirmed with the original request ID. Known unsupported/disabled states remain known. A shared actual-completion native queue orders start/stop across service instances. A queued start cannot dispatch after its observer expired; dispatch rechecks origin authority. A queued cleanup stop can still retire a late start after its own observer expires, unless a newer suspension lease supersedes that cleanup. |
| BioPay foreground NFC: `features/biopay/presentation/biopay_nfc_foreground_listener.dart` | Native start/stop/pending-consume and initial link observers wait 4s. Poll waits 3s; APDU/NDEF/finish waits 4s. A timed-out poll ends the loop rather than overlapping another read. Native start retains actual single-flight completion; late completion stops after suspension/background/disposal. Suspension leases prevent stale route cleanup from releasing or cancelling a newer writer. |
| BioPay QR camera: `features/biopay/presentation/biopay_flow_shared.dart` | Start/stop/torch observers wait 8s while their actual serialized tail stays locked. Pending copy disables duplicate restart/torch. Late start follows latest lifecycle, and disposal drains real work. |
| BioPay QR/export: `features/biopay/data/biopay_qr_export_io.dart`, `biopay_qr_export_web.dart`; request/library/composer/link screens | Gallery/download/share/temp-directory callbacks are bounded at their adapters; clipboard/share/link callbacks use finite external actions. Widget image rasterization is local rendering, not a transport/native reply. |
| Admin presentation: auth/reports/trips/broadcasts/users/EV/vehicle/subscriptions/transport agencies and payment provider routes/editor | Admin support link/copy callbacks are bounded. Origin account-generation tokens are retained by dialog/sheet/editor callbacks, checked before dispatch and rechecked after each awaited read/write before local success/refresh. Uncertain mutation copy is preserved. Modal choice itself is user driven. |

## Deliberate actual-completion exceptions

These are intentional and must not be replaced with a timeout on the shared tail:

1. **Secure session mutations and account SDK transitions.** `SessionPersistence`, `NativeSessionValueStore` mutation methods, `AccountContext._diskTail` and `_sdkTail` wait for real completion. Releasing a queue at a timeout could let an old token write, clear or SDK restore race a newer login. Caller observers are bounded; exit/trust fences are raised before waiting. Recovery reset keeps its button disabled until the actual secure reset finishes. This intentionally does not falsely claim a completed reset.
2. **Serialized QR camera operations.** `_cameraOperation` retains native completion, while its observer reports pending after 8s. Restart/torch remain disabled until the real operation finishes. Disposal remains behind this tail; late completion uses the latest mounted/lifecycle state.
3. **Foreground NFC start.** `_nativeStartWork` retains the actual callback as single-flight authority after its 4s observer expires. A later lifecycle event does not dispatch another start while it is unresolved, and late completion stops a reader after background/suspension/disposal.
4. **Driver location mutation ordering and operation pointer serialization.** Real-completion queues protect ordering of an old online write versus logout/offline state and persistence of wallet/chat operation identities. A timeout is applied to the caller/request observer without claiming rollback or generating a new mutation identity.
5. **Analytics user context ordering.** `_contextTail` retains real native ID/role completion while callers wait at most 4s. Newer context revisions skip queued obsolete work and prevent a late old ID reply from dispatching its obsolete role. A newer clear/set follows the actual outstanding ID write; timing out the observer cannot release this tail.
6. **Face camera cleanup.** The camera's late initialization and temporary image cleanup are still observed by the original operation. Timing out the user wait does not detach cleanup from a file/native handle that has not finished being created.
7. **Device NFC advertisement mutations.** `_nativeMutationTail` keeps real start/stop completion across service instances. A stop cannot complete before a preceding start actually finishes and allow the old advertisement to reappear. Caller observers stay at 6s; a queued start whose observer expired is suppressed, while authorized cleanup still runs after its observer expires. Cleanup uses lease generation, so its own UI release does not suppress it and a newer owner does.

## Non-request futures

- `showDialog`, `showModalBottomSheet` and route push futures wait for a user decision or route dismissal. They are not transport deadlines. Account/session generation is rechecked around the resulting callback.
- Realtime, app-link, notification and position streams are deliberately ongoing subscriptions; finite refresh/request/cleanup observers and current-account/lifecycle guards govern their events. A stream's intended lifetime is not a hung request.
- SharedPreferences/file serialization for theme choices, opaque pending IDs and local journals is local state. Actual-completion ordering is preserved where needed; it is not a network retry loop.
- Local QR rasterization and byte encoding are rendering work. Their error handling remains distinct from uncertainty about a persisted server/native side effect.

### Confirmed wallet close and native journal cleanup

The final audit found a local-state robustness seam after the server had already
confirmed a wallet acknowledgement/cancellation: the UI could wait indefinitely
for journal cleanup. `WalletService.closeOperation` now observes that cleanup for
four seconds. Cleanup timeout, false removal acknowledgement or native error
does not relabel the independently validated server closure or send another RPC.

`WalletOperationJournal` serializes its actual read/reload/save/remove completion
across owners. The caller deadline sits outside that queue. A late cleanup must
settle before a newer pointer can be written, and an obsolete clear checks the
owner and operation inside the queue before removal. This preserves recovery
identity when the UI observer expires. The locked SharedPreferences method-channel
fixtures in `wallet_service_boundary_test.dart` exercise held native reads/removes,
late success/error, newer-pointer preservation and confirmed closure behavior.

## Inactive compatibility helpers

`features/biopay/data/biopay_nfc_card_payload.dart:287` declares `readBioPayNfcCardPayloadFromActiveTag`, with a raw native NDEF read. The final repository reference search found only its declaration; all active card/foreground reads use the bounded adapters listed above. This unused helper is excluded from the active request conclusion and would need a bounded observer before activation.

`SupabaseSessionService.ensureAnonymousSession` and `AccountContext.bootstrapAnonymous` form an unused compatibility path. The final source reference search found no active startup/presentation caller. Active Firebase anonymous infrastructure authentication is separately bounded at 15s. Actual SDK account transition serialization remains deliberate, as documented above.

## Focused verification

All focused tests use the pinned Flutter 3.44/Dart 3.12 SDK and local synthetic mocks; none contacts production providers.

- Chat/NFC deadline suite: 20 passing tests, including committed-send lost reply, no duplicate send, availability/poll/write/lock/readback/cleanup loss and known preflight rejection. The final NFC service rerun passed 10/10 after replacing a CPU-sensitive 3ms cleanup fixture with phase-controlled fake time: confirmed write/read-back precede stalled cleanup, the production 8s cleanup observer returns the same verified receipt, and a late cleanup reply does not trigger another write.
- Auth/request/camera/external suite: 49 passing tests, including real Dio send loss/total deadline, resend cooldown, PostgREST proxy loss versus explicit rejection, QR camera pending/lifecycle/disposal, NFC unconfirmed UI and existing login behavior.
- Payment methods account callback suite: 4 passing tests covering late list/sharing replies, same-owner session replacement, grant dialog dismissal and old save replies.
- Final payment methods retained-callback suite: 12/12 passed (`/tmp/mobio-methods-retained-callback-tests.log`), including the four earlier races and eight stale/current cases for rendered refresh/add/edit/sharing. Each callback retains its original account snapshot and view revision before any private dispatch; invocation after a replacement session makes no new service call or editor/modal navigation. Focused analysis returned no errors or warnings (four existing informational notices).
- Final Firebase/connectivity coverage: 5 passing tests covering telemetry deadline, observed late native error/no resend, hung native connectivity followed by one real mocked HTTP lookup, and held ID callbacks across clear and same-owner context replacements.
- Foreground NFC suite: 3 passing tests proving no duplicate start after timeout, late cleanup on background/disposal, and stale suspension release and native cancellation ownership fencing.
- Native session read deadline and session persistence suites passed during the earlier combined session/chat/NFC verification; the held-read test proves late opaque replies cannot restore trust.
- Admin modal suite: 2 passing tests proving an old dialog cannot cancel a trip after account generation replacement and that unconfirmed cancellation preserves status-check copy without a success/retry claim.
- NFC widget fixture checks: nine passing targeted cases across public cold-start app-link, writer input, en/fr/rw NFC links, core mobile previews and three NFC writer accessibility variants. Fixtures acknowledge native cleanup callbacks and drain disposal work, retaining production deadlines.
- Final malformed-success Face/privacy plus account service races: 36/36 passed. Fixtures use real Supabase HTTP adapters, distinguish unusable write acknowledgements from unavailable reads/explicit rejection, retain the original operation/request identity, and assert exactly one write without automatic resend.
- Device NFC/foreground suite: 12/12 passed. Phase-controlled fake time proves late start → cleanup → new start ordering; cleanup still dispatches after both caller deadlines; queued expired/stale starts do not dispatch; released lease authority survives until superseded. Null/missing/mistyped required native mutation flags remain uncertain with no repeated write.
- Final device NFC/foreground receipt suite: 26/26 passed (`/tmp/mobio-device-nfc-receipt-final-tests.log`), retaining all twelve prior cases and adding exact/clamped expiry positives, wrong/missing/invalid/extended/expired token/expiry receipt failures, scalar/list acknowledgement failures, stop-still-active uncertainty and legitimate unsupported/disabled outcomes. Each malformed acknowledgement dispatches exactly once; no retry is introduced.
- Final OTP optional message/request receipt suite: 34/34 passed through real Dio response decoding. Valid optional messages remain usable; null/number/boolean/list/map message metadata uses fallback copy while preserving success/rejection and cooldown. Missing/mistyped required success acknowledgement remains uncertain. With the existing ten login screen cases, OTP/login verification passed 44/44 in `/tmp/mobio-request-final-otp-native-tests.log`. That run also contained the earlier twelve native/foreground cases; their final receipt extension is recorded separately as 26/26 above. These overlapping focused runs are not summed into an application-wide total.
- Focused analysis of owned core/services/presentation/tests: exit 0, no errors or warnings; 38 informational lint notices remain, including existing stylistic rules. The final admin/Firebase/location/foreground/test analysis also returned no errors or warnings (23 informational notices).
- Final OTP/native service/test analysis after receipt correlation: exit 0, no errors or warnings, 15 informational style notices (`/tmp/mobio-request-final-otp-native-analyze.log`).
- Python helpers: 405/405 passed, consisting of the existing 402 checks and three source-token regression tests. Static integration assertions now ignore formatting/comments without accepting comments as executable guards. The member-ID check explicitly requires remediation before backfill and prohibits automatic clearing/reassignment of historical IDs.
- Final shared Python helper rerun after compiled-AAB gate and current parallel changes: 446/446 passed (`/tmp/mobio-request-final-helper-tests.log`).
- Repository structure check: passed after adding the shared NFC test fixture helper.
- `git diff --check`: passed.

The integrated Flutter suite and final local release gates belong to the aggregate readiness report. Focused test success is not deployed-service or device/store acceptance.

## Remaining local request-boundary implementation gaps

None identified in the audited active boundaries. Intentional queue/modal/stream/local-state exceptions above remain in place. Full integrated verification remains aggregate readiness work; no production release assertion is made here.

## Final local storage and OTP fixture verification

The wallet service/native-journal boundary file passed all **19 cases**, including
nine new storage regressions; focused analysis found no issues. Persistent local
receipts: `build/qa/readiness-closeout-20260930/wallet-cleanup.log` and
`wallet-cleanup-analysis.log`, with exit-code files both equal to zero.

The OTP fixture batch passed all **36 cases**, including new app/admin held-
interceptor deadline cases. A controlled clock and actual Dio adapter-entry
barriers replace assumptions about dispatch within two milliseconds of real
time. Late completion preserves the published unconfirmed outcome; no second
send occurs even after the offered cooldown. Immediate metadata assertions are
preserved on the same clock. Production OTP source is unchanged. Focused analysis
found no issues; persistent `otp-deadline-fixture*` log/exit receipts are in the
same evidence directory. These focused counts overlap full Flutter integration
and are not additional distinct totals.
