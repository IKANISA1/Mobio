# M055 / M057 — Account callbacks and truthful Face state audit

Date: 2026-09-30

## Scope and result

This audit covers the active routes and shared modules affected by M055, plus
M057 enrollment-state semantics. The source sweep includes Profile/edit profile,
Wallet/Driver Plus/favorites/referral, shell/Home/nearby, scheduled-trip forms and
rendered post callbacks, consent/push, chat/inbox, approved BioPay
Face/discovery/Device NFC and administrative reads, mutations and root modals.
Completed fixes and their regression evidence are listed below. The integration
review subsequently found additional retained-callback dispatch gaps; their
current status is recorded in the final section, rather than treating earlier
late-response tests as proof of every rendered callback.

The earlier final owned run passed **96 tests across 12 files**, the two existing
Face enrollment goldens passed, and focused analysis of **21 files** found no
issues. The subsequent Wallet continuation passed **27 actual-widget tests**;
analysis of its production screen and test found **no issues**.
Earlier and parallel receipts are retained separately; their overlapping counts
are not added together. Source inspection establishes which callbacks were
reviewed; focused tests prove the named controlled races and positive cases.
Neither is a claim of whole-application acceptance.

This report records local source and controlled service/widget/native-channel
evidence. The aggregate readiness report owns repository-wide tests, secret
scan, release-script outcome and external gates. It does not claim deployed SQL,
provider recognition, physical NFC/camera/dialer, or store acceptance.

## Authority carried by asynchronous work

- `AccountSnapshot` carries user ID, verified session ID and account generation.
  `AccountContext.isCurrent` compares all three; signing in again as the same
  user does not restore an old ticket.
- `AccountContext.changes` invalidates cached private views and active forms.
  Each result still checks its captured snapshot after an awaited operation, so
  correctness does not depend only on the timing of the UI notification.
- View/load/operation revisions reject superseded work within one account.
  Selection identity, draft revision, instruction evidence and expiry are
  checked where a callback can change its target.
- `AccountActionToken` binds delayed modal/editor callbacks to their originating
  snapshot and notifier revision. It does not grant server authorization.
- NFC suspension leases bind cleanup to the operation that suspended the reader.
  An older operation cannot release or cancel a newer lease. Native operation
  step callbacks recheck account and lease before subsequent physical dispatch.
  Device NFC start/stop also share the actual native completion queue. Queued
  cleanup retains its generation lease after its own observer expires; acquiring
  a newer lease invalidates that old cleanup before native dispatch.

## Reviewed callback coverage

| Surface | Captured authority and result handling | Evidence |
| --- | --- | --- |
| Profile and edit profile | Profile loads carry snapshot plus load revision and check before the private Face follow-up; account notifications clear private state. Each rendered action retains its origin token. Edit fields and save retain the form-origin token, including while `AsyncLoading` retains old data. Post-save navigation and feedback require the same ticket. | `profile_screen.dart`, `edit_profile_provider.dart`, `edit_profile_screen.dart`; 8 Profile rendered/follow-up/external tests (13 stale actions plus positive actions), edit-profile generation regression and existing provider suite |
| Wallet and invite callbacks | Each rendered refresh/retry/pull, transfer/redeem, pending-review, share/copy, invite and back action retains the view origin. Loads check account plus revision before summary → ledger → active-operation dispatch. Modal fields hide after replacement; retained inner confirmations and receipt acknowledgements retain the same origin. Private/native follow-up and success feedback recheck the original authority. The original operation ID and cancel versus acknowledge intent survive all confirmation/receipt steps. Form controllers live until actual route unmount. | `wallet_screen.dart`; **27 actual-widget races and positive cases**, including same-owner and A-to-B replacement, both sequential read seams, delayed lookup/write/close/native/invite responses, current transfer/redemption/review and unknown-outcome reconciliation without retry |
| Favorites and referral services | Favorite service reads/writes and rendered retry/add/delete dispatch retain the originating snapshot and token; referral/invite follow-up checks reject stale results. Open address sheets clear private fields after replacement and retained place/save callbacks cannot dispatch. | favorite/referral services and favorite section; existing service account races plus **6 actual-widget cases** for stale dispatch, late reads, sheet clearing and positive retry/delete/save |
| Driver Plus | Snapshot/load revision fence profile → status → plans → wallet follow-up reads. Start, preferences, clipboard, dialer record and pending-key cleanup recheck the original ticket. The persisted request key includes user/session identity, plan and method; a late completion clears only its matching key. Toolbar refresh, pull refresh and retry retain the rendered account. | `driver_plus_screen.dart`; 6 actual-widget tests, including all three retained refresh races and a positive refresh; receipt/deadline tests in the associated boundary reports |
| App shell and Home | Account changes reset role/private trips/unread/online state. Role/profile, unread and own-post replies carry account plus revision; notification events correlate owner. Rendered Home refresh, mode/online controls, filters, chat/detail and navigation actions retain their origin token. Sharing controls recheck after permission/start/stop. Analytics user-context writes preserve actual native ordering and skip superseded role writes. | `shell.dart`, `home_screen.dart`, `firebase_analytics_service.dart`; Home preview/identity tests, **2 actual-widget retained/current callback cases**, and 2 held native context races |
| Nearby driver sharing | Start/stop invalidation happens before subscription cancellation. Publishes/offline compensation are ordered; each queued event retains the captured authority, revision and vehicle type. Failed replacement retires the earlier sharing. Old-account cleanup cannot take the new account offline. | `driver_location_sharing_service.dart`; 10 lifecycle/concurrency tests |
| Nearby people and scheduled posts | Public person cards use `DiscoveryPerson` and carry peer identity to downstream authenticated chat. Own-post loads and rendered detail/cancel/chat/edit callbacks retain snapshot/revision or origin token. Scheduled-trip service results correlate owner/entity. | Home/Nearby/booking screens, trip service; service account and typed boundary tests |
| Scheduled-trip draft and current location | Initial pickup, permission, cached/fresh GPS and reverse geocoding carry draft account/build/location revisions. Manual origin supersedes a late GPS result. Favorite save/delete follow-up cannot mutate a replaced draft. Form fields, date/favorite choices, initial post-frame location and retained permission/submit callbacks retain an immutable form-origin token. | schedule provider/screen, Bookings and TripDetails; 5 controller races plus **8 rendered callback/permission cases**, including retained/current empty-state Schedule actions |
| Admin dashboard navigation | Toolbar Users/Health and both responsive quick-action Users/Trips closures retain the rendered account token before GoRouter dispatch. Replaced-session callbacks cannot navigate, while current toolbar and pushed-route actions remain usable. | `admin_dashboard_screen.dart`; **16 actual-widget tests** at 900/1440 px for retained/current toolbar and quick actions |
| Consent and push preferences | Read/save service calls capture verified authority. Controller serializes saves, accepts only latest current revision and restores confirmed state after latest failure. Permission check/dialog/request, push registration and save feedback retain the originating snapshot. | consent service/controller/section and push service; 4 controller races, 3 permission-widget races, existing section test and 2 HTTP-backed consent races |
| Face scan | Scan authority includes actual snapshot identity/generation, local lifecycle revision and handoff ticket/expiry. Account change clears shortcut and stops camera. A late capture/resolve/dial/record cannot create a handoff; captured bytes are cleared. Clipboard and retained primary/manual/QR callbacks carry their rendered ticket. | Face service/scan screen; service reply races, same-owner capture/resolve races, retained primary callback, leave/background cases and successful localized widgets |
| Face enrollment | Status/method loads, polling, consent, capture/enroll and management-navigation return retain snapshot plus revision. Account change clears methods/consent/status and stops camera/poll. Rendered choice/consent/camera/pause/remove/refresh callbacks retain the original ticket. Late enrollment acknowledgement cannot restore prior-account state. Current-account confirmed cache supports recovery during an outage; confirmed enrollment and management acknowledgements advance that cache before refresh, and unknown outcomes leave current status unavailable without automatic recapture. Public health read remains public. | Face service/enrollment screen; same-owner delayed enrollment, retained consent/method/action widget and HTTP-backed service races |
| Discovery service and composer controller | Private gateway calls, native instruction dispatch and remembered draft pointers retain captured snapshot. Controller edits/resume/quote/prepare/record reject stale tickets. Typed quote/prepared/record parsing rejects incomplete evidence or revision before promoting UI state, including injected gateways. | discovery service/domain, composer controller; strict boundary tests, same-owner quote race, 4 malformed controller reply cases and HTTP-backed workspace/removal races |
| Composer presentation | Workspace/draft/entry/contact follow-up retains view snapshot and load revision. Manual/source/support modals hide private content after invalidation. Controller identity and account ticket guard returning modal choices and external handoff. | `payment_composer_screen.dart`; old workspace, late contact and open manual-modal widget races |
| Library, recent actions and request editor | Library reads/actions and pay-again navigation retain view snapshot/revision. Request editor clears fields/methods on invalidation; create-link acknowledgement and navigation/date-picker return retain origin ticket. Open share sheet clears token/methods and guards clipboard/share/gallery follow-up. | `payment_library_screen.dart`; library/request late reply, pay-again and open share-sheet widget races |
| Payment methods and sharing | List/sharing replies retain originating snapshot; invalidation clears private rows. Rendered refresh/add/edit/sharing actions retain snapshot plus view revision before private dispatch or navigation. Grant dialog closes; editor hides and clears inputs. Delayed save cannot navigate or dispatch again. | `payment_methods_screen.dart`; **12 actual-widget tests**, including 8 retained-callback/current-positive cases plus the existing 4 list/sharing/dialog/save races |
| Saved-link NFC writer | Workspace, selected link, public-preview continuation, write/lock receipt and Requests return retain view snapshot/revision. Account change clears links/selection/receipts. Delayed lock confirmation is masked. Write/lock step callbacks require the original account and foreground lease. | `payment_nfc_link_screen.dart`; delayed workspace/preview/write, lock modal, lease replacement and navigation-return tests |
| Receiver NFC writer | Receiver form and write/lock confirmations retain snapshot/revision; invalidation clears receiver/payload/receipt. Cancellation and native availability follow-up recheck authority. Old cleanup cannot resume another foreground lease. | `biopay_nfc_write_card_screen.dart`; raw confirmation/cancel/write/lock races plus actual native-channel delayed availability regression |
| Device NFC advertisement | Active `/biopay/nfc` captures the original snapshot/revision before profile hydration, request creation and native start; account change clears receiver/amount/request immediately. Retained activation and late receipts cannot start/show A work as B. Owned cleanup uses generation-only queued-stop authority and cannot release a newer lease. | `biopay_nfc_screen.dart`; 5 widget tests including delayed profile/request/start, retained activation and positive current start/clear; device/foreground queue tests separately cover native real completion |
| NFC foreground lifecycle | Reader start retains real native completion authority across observer timeout; late starts stop after background/suspension/disposal. Suspension acquire/release/ownership is generation scoped. | foreground listener; stale-lease unit test and native lifecycle/deadline tests |
| Chat and inbox | Chat request/watch lifecycle retains `ChatAuthority`; private responses correlate participants/conversation/owner. Inbox screen clears cached FutureBuilder rows, observes discarded futures and uses rendered tickets even for already-read rows. Late read/mark-all acknowledgement cannot navigate/refresh the next session. | chat/notification services and screens; typed/service/realtime run plus 5 actual inbox widget regressions |
| Admin boundary and delayed actions | Boundary masks protected child immediately on session invalidation. Trips/reports/broadcasts/users/EV/vehicle/subscriptions/transport agencies/provider routes and editor retain immutable view-origin tokens before modal service/ref access and after awaited work before refresh/success. | `admin_session_boundary.dart`, admin/provider screens; 3 boundary tests and old-trip-confirmation regression (zero calls after replacement) |
| Admin dashboard | Dashboard loads and notification refreshes carry origin token plus revision; invalidation clears cached state before provider reload. Platform settings capture one authority across both writes and check between them. Allowlist/settings root sheets mask private inputs and reject old saves. | dashboard controller/screen; 3 generation tests for second-write suppression, A-to-B late load and retained root-sheet save; existing recovery test |
| BioPay operations console | Immutable view-origin token fences snapshot/search/selection and evidence confirmation. Invalidation clears payees and selected state. Root evidence dialog masks its reference and both modal result and service reply retain the original ticket. | `biopay_admin_console_screen.dart`; 2 actual-widget delayed-load/dialog regressions |
| Admin audit and runtime reads | Audit/health reads carry immutable origin token and load revision. Invalidation clears rows/search/error state; retained refresh/filter/detail callbacks cannot dispatch a new private read. Audit root detail sheet masks cached payload on replacement. | audit/operational-health screens; 3 late-read/root-modal widget regressions |
| Admin privacy/push health cards | Each card retains its immutable view-origin token before private RPC dispatch and after response. Invalidation clears counts, and old refresh callbacks remain invalid even when the same owner signs in again. | health cards; 6 actual-widget tests for retained callbacks, late replies and positive current refresh |
| Privacy requests | The route retains an explicit account snapshot. Account/lifecycle invalidation clears policy/request state; load/submit follow-up checks snapshot and foreground revision. | privacy request screen/service and existing account/lifecycle tests |

Source basenames in the table refer to their feature paths under `lib/`; named
regressions live under `test/features/`. The final command below gives exact
test paths.
Preserved functionality includes the approved dated BioPay/public-transport
scope; this audit adds no routing, settlement or ride lifecycle feature.

## M057 requirement-to-evidence mapping

| Required distinction | Implemented source behavior | Local evidence |
| --- | --- | --- |
| Unavailable differs from confirmed no enrollment | Default/unconfigured status is unavailable. Only a valid SQL `not_started` projection is confirmed setup absence. Missing/unknown status, missing/malformed `has_face`, or missing nullable method/vector keys throws a format error; UI shows unavailable. Declared SQL `rejected` remains unavailable and preserves its face flag. | `BioPayEnrollmentStatus.fromJson`; 14 projection/negative tests in `face_enrollment_status_boundary_test.dart`, including intentional null SQL values; widget outage/refresh test |
| Loading does not claim absence | Initial pending status displays working copy; it shows neither setup absence nor a failed status before the read finishes. | Actual enrollment-widget held-status regression |
| Preserve safe recovery from verified prior state | A failed refresh shows current unavailable status and disables new capture. A previously confirmed same-session face still permits pause/resume/remove; the cache is never displayed as current readiness. | Active and paused outage widget cases verify available recovery, unavailable copy and disabled camera |
| Advance only from confirmed enrollment and management evidence | A confirmed active first enrollment and successful pause/resume/remove acknowledgements update confirmed cache before refresh. A failed refresh after removal cannot restore older active recovery controls. Unknown enrollment or management outcome marks current status unavailable, keeps only prior confirmed recovery, blocks a new capture until status refresh and never advances unconfirmed state. | Actual first-enrollment/refresh-outage, not-started/active unknown-enrollment and active/paused management transition cases; service acknowledgement tests complement injected widget fixtures |
| Never carry cache into a replaced session | The cache stores its `AccountSnapshot`; generation invalidation clears it and retained recovery callbacks cannot dispatch. | Same-owner replacement during outage regression, retained action/choice/capture tests and HTTP-backed Face reply races |

The SQL projection inspected is
`supabase/migrations/20260920150000_biopay_face_shortcut.sql`,
`rpc_biopay_face_authority` status branch. It intentionally emits nullable
`receiving_method_id` and `pending_vector_id`, including for `not_started`.
Tests do not treat a raw legacy profile row as this status projection.

## Pending operation rules

Wallet/chat journals retain stable operation identities and reconcile an
uncertain result without creating another mutation identity. Driver Plus keeps
its persisted pending key until a matching, current confirmed completion can
clear it. Composer/Face record callbacks require the original draft/instruction
evidence and current authority. Account invalidation prevents old callbacks from
reporting success or initiating a follow-up under the next session.

Timeouts do not revoke an operation already dispatched to a server or native
writer. Unknown results remain unknown. The actual-completion ordering adapters
and deadline behavior are documented in
[`m054-request-boundary-audit-2026-09-30.md`](m054-request-boundary-audit-2026-09-30.md).
Strict owner/entity/state/receipt validation is documented in
[`m063-typed-boundary-audit-2026-09-30.md`](m063-typed-boundary-audit-2026-09-30.md).

## Account-neutral exceptions reviewed

- Place search/geocoding and country/vehicle/charger/public-transport catalog
  reads return public or account-neutral information. Their caller still uses
  its own operation revision when applying a result to a private draft.
- Face readiness/health is a public availability read. It does not establish
  enrollment, payer identity or permission to hand off.
- Public payment-link arrival and preview use the opaque public token. They do
  not enumerate the signed-in user's saved links. Private composer entry and a
  saved-link NFC preview continuation separately capture account authority.
- Nearby lookup, the map's device-location permission workflow, EV locator and
  insurance-agent public contact setting are account-neutral discovery/catalog
  surfaces. They do not enumerate the signed-in user's private workspace.
  Private downstream chat/form/write work independently captures authority.
- `/ledger` renders the scope-unavailable screen. `/trip/:id/edit` uses the same
  guarded scheduled-trip form. Active `/biopay/qr` and `/biopay/request-payment`
  use `PaymentRequestEditor`; `/biopay/pay/:token` uses `PaymentLinkArrivalScreen`.
  The old QR/request/payment-link classes retained for visual fixtures are not
  those active route implementations. The receiver card writer is also tested
  as a preserved component; the active write-card route uses `PaymentNfcLinkScreen`.
- Public launch links, ongoing native reader lifecycle and telemetry events are
  not private server mutations. User context writes and private downstream
  actions still use the ordering/authority rules above.
- Local UI preview fixtures may omit a real account. These allowances are
  explicit preview/test paths, and production private service calls require a
  verified snapshot.

## Final focused verification

Runtime: Flutter 3.44.3 / Dart 3.12 from
`/Volumes/PRO-G40/Development/Flutter/flutter_3_44_codex/bin`.

The final owned command was:

```sh
flutter test --no-pub \
  test/features/admin/admin_dashboard_account_race_test.dart \
  test/features/admin/admin_dashboard_recovery_test.dart \
  test/features/admin/admin_private_read_account_race_test.dart \
  test/features/admin/admin_health_refresh_account_race_test.dart \
  test/features/biopay/biopay_admin_account_race_test.dart \
  test/features/biopay/biopay_device_nfc_account_race_test.dart \
  test/features/biopay/face_shortcut_widgets_test.dart \
  test/features/biopay/models/face_enrollment_status_boundary_test.dart \
  test/features/biopay/models/biopay_admin_test.dart \
  test/features/profile/presentation/driver_plus_account_race_test.dart \
  test/features/biopay/data/biopay_face_service_boundary_test.dart \
  test/features/biopay/data/account_callback_service_race_test.dart \
  --reporter expanded
```

Result: **96 passed, 0 failed**, recorded in
`/tmp/mobio-account-final-owned.log`. The command used the pinned absolute
Flutter path. Controlled widgets inject synthetic verified snapshots and held
service replies. HTTP-backed tests exercise the actual Supabase adapter with
mock transport; they complement widgets without claiming live authorization.

Final Face enrollment visual command selected only the two existing enrollment
baseline cases:

```sh
flutter test --no-pub test/features/preview/revolut_reference_golden_test.dart \
  --name '^Revolut-reference golden .* biopay_face_enroll$' \
  --reporter expanded
```

Result: **2 passed**, 390 and 430 px, against stored baselines with no regeneration
(`/tmp/mobio-face-enrollment-final-goldens.log`). Final focused analyzer:
**21 production/test files, no issues**. `git diff --check` passed.

### Wallet continuation receipt

```sh
/Volumes/PRO-G40/Development/Flutter/flutter_3_44_codex/bin/flutter test --no-pub \
  test/features/profile/presentation/wallet_rendered_callback_race_test.dart \
  --reporter expanded
```

Result: **27 passed, 0 failed**
(`/tmp/mobio-wallet-rendered-races-final.log`). The controlled fixture supplies
synthetic snapshots but uses the actual screen, account notifier, rendered
callbacks, root dialogs, service calls and native share/clipboard channels. It
proves the named same-owner-session and A-to-B races; production private services
continue enforcing the actual `AccountContext` and server authority.

The suite exercises all three retained refresh paths; nine retained rendered
private/navigation actions; transfer/redeem/invite form callbacks; transfer,
redemption and pending-review confirmations; late summary and ledger responses;
late recipient lookup, mutation receipt, request-close, native share/copy and
invite-apply responses. Positive current callbacks exercise refresh, retry,
share/copy, invitation application, transfer/redemption receipt closing and both
pending-request close intents. The uncertain transfer case sends one operation,
shows reconciliation copy, and neither invents success nor retries automatically.

Focused analysis of `wallet_screen.dart` and this test: **no issues**
(`/tmp/mobio-wallet-focused-analyze.log`). Scoped `git diff --check` passed. The
positive cases also exposed and now cover controller disposal during bottom-sheet
exit and the pending-request row's missing Material ancestor. Wallet model,
server contract and operation journal semantics were preserved.

### Earlier and parallel receipts

The earlier combined callback command was:

```sh
flutter test --no-pub \
  test/features/nearby/data/driver_location_sharing_service_test.dart \
  test/features/bookings/application/schedule_trip_account_race_test.dart \
  test/features/profile/presentation/driver_plus_account_race_test.dart \
  test/features/profile/application_notification_consent_race_test.dart \
  test/features/profile/widgets/profile_notification_consent_account_race_test.dart \
  test/features/profile/widgets/profile_notification_consent_section_test.dart \
  test/features/biopay/face_shortcut_test.dart \
  test/features/biopay/face_shortcut_widgets_test.dart \
  test/features/biopay/data/biopay_face_service_boundary_test.dart \
  test/features/biopay/payment_discovery_test.dart \
  test/features/biopay/payment_account_callback_race_test.dart \
  test/features/biopay/payment_methods_account_race_test.dart \
  test/features/biopay/data/account_callback_service_race_test.dart \
  test/features/biopay/payment_nfc_account_race_test.dart \
  test/features/biopay/biopay_nfc_unknown_outcome_screen_test.dart \
  --reporter expanded
```

Earlier result: **113 passed, 0 failed**. The command used the pinned absolute Flutter
path. It includes successful localized flows and unknown-outcome behavior as
well as negative generation tests. Test HTTP/native boundaries use controlled
mock replies; they are not live provider/device tests.

Subsequent and parallel evidence, without adding overlapping totals:

- Face controller/service/widget rerun after retained callback fencing:
  **36 passed across 3 files**, including 3 added regressions. Old primary scan,
  consent/method choice and pause callbacks cannot operate after replacement.
- Face enrollment visual fixture: **2 passed** at 390 and 430 px against the
  existing stored baselines, with no baseline regeneration. The explicit
  `not_started` status and snapshot are synthetic test authority; production
  unavailable handling is preserved.
- Profile rendered/follow-up/native callbacks: **8 passed**, including 13 stale
  rendered actions and positive current actions, late profile → Face suppression,
  stale/current enrollment return and native fallback handling.
- Scheduled-trip form/Bookings/TripDetails rendered callbacks: **8 passed**;
  related earlier controller/preview selection: **10 passed**. These screen
  fixtures exercise notifier generation; service/controller snapshot races
  separately prove private authority checks.
- Edit-profile provider generation race plus existing suite: **3 passed**.
- Immediate admin boundary masking: **3 passed**; delayed admin confirmation
  suite: **2 passed**. Old-session confirmation dispatched **0** service calls;
  lost cancellation acknowledgement made exactly **1** call and showed
  reconciliation copy without success or automatic retry.
- Typed service/model/UI run: **227 passed across 28 files**, including the
  5 actual notification widget races; see M063 report.
- Firebase context/deadline suite: **4 passed**, including 2 held-ID
  replacement/clear races; late old ID completion could not publish its obsolete
  role. Connectivity companion: **1 passed**; foreground NFC suite: **3 passed**,
  including stale suspension ownership and real-completion lifecycle cleanup.
  Later device plus foreground queue run: **9 passed**, including timeout then
  late actual start/stop ordering, stale queued start suppression and cleanup
  authority remaining valid after own lease release but not after a new lease.
- Payment-method generation suite: earlier **4 passed**, also included in the
  113-test command above. The final retained callback continuation passed
  **12 tests** (`/tmp/mobio-methods-retained-callback-tests.log`), covering refresh,
  add, edit and sharing dispatch plus positive current actions. Its focused
  analysis found zero errors/warnings and 4 existing informational lints.
- Earlier owned static analysis: **28 files, no issues**. Aggregate validation
  records the repository-wide analysis/build and structure/secret checks. The
  subsequent analysis of the 5 Face/visual-fixture files also found no issues.

## Final root callback batch

`/tmp/mobio-final-root-rendered-callbacks.log`: **38 passed**, covering Home 2,
favorite addresses 6, responsive AdminDashboard navigation 16, Bookings 8 and
release contracts 6. These counts overlap other focused evidence and are not
added into a distinct suite total. The tests retain actual rendered closures,
replace account generation, invoke the old closures and assert no dispatch or
navigation; current-action positive fixtures prevent a blanket-disable fix.
Final repository-wide analysis and tests are recorded in the aggregate report.

## Completion evidence and limits

The Wallet, PaymentMethods, Composer/Library, favorite-address, Home, Bookings,
AdminDashboard and Face follow-ups named in the earlier integration review are
implemented in the current source. Actual retained-callback tests distinguish
old-session rejection from current-session positive behavior, including callbacks
held through a new account reload. Face regression cases cover confirmed first
enrollment followed by a refresh outage and unconfirmed enrollment from both
not-started and prior-active states. The current authoritative aggregate results
are recorded in `docs/reports/mobio-local-readiness-goal-2026-09-30.md`; older
focused counts above overlap and do not replace that integration result.

A separate user-owned chat published readiness and concurrent design work in
`9aa98e8cf5173fe7e3565f52cae37b14b9560785`. Final verification/corrections use an
isolated checkout of that source to avoid edits arriving during tests. Unaccepted
golden comparisons, physical-device/provider acceptance and rollout dependencies
retain their separate status. No visual baseline was regenerated for this goal.
