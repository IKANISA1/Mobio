# Mobio Flutter Mobile Screen Inventory and 2026 Native UI Audit

> Historical audit evidence. The former local specification was removed on
> 30 September 2026. The external `revolut-design` skill is the sole design
> authority; the source descriptions and dated scores below are not current
> UI instructions or acceptance.

Date: 2026-06-07
Checkout: `/Volumes/PRO-G40/MOBI/mobi_app`
Report path: `/Volumes/PRO-G40/MOBI/mobi_app/docs/reports/mobio_flutter_mobile_screen_inventory_2026-06-07.md`

## Audit Standard

The audit used:

- Flutter adaptive and responsive guidance: responsive layout fits the available space; adaptive layout chooses platform-appropriate layout and input behavior.
- Flutter accessibility guidance: large text resilience, sufficient contrast, labeled controls, and 48 dp Android / 44 pt iOS tap targets.
- Flutter accessibility testing guidance: route and widget coverage should include tap target, label, and contrast guideline checks.
- Local Mobio UI system v2.2 in `design.md`.

Verdict rule: a screen is only "100% compliant" if it has code evidence plus runtime/device evidence for Android and iOS compact widths, large text, dark/light theme, accessible labels/tap targets, reduced motion, safe areas, and expected loading/error/empty/success states. This audit found no route with complete evidence for 100% compliance.

## Summary

- Current routed surfaces: 28 explicit GoRouter paths plus the GoRouter 404/error surface.
- Active passenger screens: Home, Trips, Profile, Nearby, Schedule, Trip details, Chat, Edit profile, WhatsApp login.
- Active admin screens: Admin auth, Dashboard, Users, Vehicle types, Subscriptions, Trips, Reports, Health, Audit log, Broadcasts.
- Intentionally inactive legacy surfaces: Ledger, Admin finance, BioPay root, QR, scan, face scan, enroll.
- Resolved after audit: the previously orphaned Dart `MobiSplashScreen` was deleted on 2026-06-08; startup remains native-splash based.
- Reusable system overlays: connectivity banner, fatal error fallback, confirmation dialog, permission dialog, bottom sheet wrapper.
- 100% verified native Flutter 2026 compliance: none.

## Route and Screen Inventory

| # | Route / surface | Widget | Status | 100% compliant? | Score | Main gap |
|---|---|---|---|---|---:|---|
| 1 | `/config-error` | `ConfigErrorScreen` | Active fallback | No | 70 | Developer-facing copy; no large-text/device proof. |
| 2 | `/login` | `WhatsAppLoginScreen` | Active auth | No | 76 | Inline multi-step OTP flow, but no full accessibility/golden coverage. |
| 3 | `/` | `HomeScreenWrapper` -> `HomeScreen` | Active tab | No | 84 | Strong shared UI usage; no verified tablet/large text pass. |
| 4 | `/bookings` | `BookingsScreenWrapper` -> `BookingsScreen` | Active tab | No | 86 | Strong list, empty/error, reduced-motion handling; no full a11y pass. |
| 5 | `/profile` | `ProfileScreenWrapper` -> `ProfileScreen` | Active tab | No | 82 | Good profile surface; settings/links need full label and large-text proof. |
| 6 | `/nearby` | `NearbyScreenWrapper` -> `NearbyScreen` | Active pushed screen | No | 82 | Location/empty/error states exist; permission rationale dialog is not wired. |
| 7 | `/schedule` | `ScheduleTripScreenWrapper` -> `ScheduleTripScreen` | Active create flow | No | 78 | Long form acts like a wizard but has no explicit stepper/progress model. |
| 8 | `/trip/:id` | `TripDetailsScreen` | Active detail | No | 84 | Good detail/cancel pattern; no edit flow despite product scope. |
| 9 | `/chat` | `TripChatScreen` | Active chat/list | No | 76 | Raw `AlertDialog` use for report/block; complex state lacks full widget/a11y tests. |
| 10 | `/edit-profile` | `EditProfileScreen` | Active form | No | 78 | Country sheet and form exist; no complete validation/a11y/device matrix. |
| 11 | `/admin-auth` | `AdminAuthScreenWrapper` -> `AdminAuthScreen` | Active admin auth | No | 72 | Admin support dialog exists; admin auth flow not fully tested visually. |
| 12 | `/admin` | `AdminDashboardScreen` | Active admin tab | No | 80 | Uses adaptive refresh and panels; no verified tablet/large text matrix. |
| 13 | `/admin/users` | `AdminUsersScreen` | Active admin tab | No | 78 | User sheet exists; bulk/action states not fully covered. |
| 14 | `/admin/profile` | `ProfileScreenWrapper` -> `ProfileScreen` | Active admin tab alias | No | 78 | Reuses profile; admin-specific account state is shallow. |
| 15 | `/admin/vehicle-types` | `AdminVehicleTypesScreen` | Active admin screen | No | 76 | Country editor sheet exists; long management screen needs visual/a11y coverage. |
| 16 | `/admin/subscriptions` | `AdminSubscriptionsScreen` | Active admin screen | No | 76 | Edit sheet exists; dense admin data needs breakpoint validation. |
| 17 | `/admin/trips` | `AdminTripsScreen` | Active admin screen | No | 78 | Good cancel confirmation; no admin edit/detail drill-in route. |
| 18 | `/admin/reports` | `AdminReportsScreen` | Active admin screen | No | 75 | Uses raw `AlertDialog`, dense cards, no moderation detail screen. |
| 19 | `/admin/health` | `AdminOperationalHealthScreen` | Active admin screen | No | 78 | Good operational states; no large-data/tablet validation proof. |
| 20 | `/admin/audit` | `AdminAuditLogScreen` | Active admin screen | No | 75 | Dense log table/list, no exported detail drawer/sheet proof. |
| 21 | `/admin/broadcasts` | `AdminBroadcastsScreen` | Active admin screen | No | 72 | Very large screen with mixed compose/approval/detail behavior. |
| 22 | `/ledger` | `ScopeUnavailableScreen` | Intentional inactive legacy | No | 70 | Correctly blocked, but still route-visible if deep linked. |
| 23 | `/admin/finance` | `ScopeUnavailableScreen` | Intentional inactive legacy | No | 70 | Correctly blocked; no active finance screen by design. |
| 24 | `/biopay` | `ScopeUnavailableScreen` | Intentional inactive legacy | No | 70 | Correctly blocked; design.md still lists old BioPay reference. |
| 25 | `/biopay/qr` | `ScopeUnavailableScreen` | Intentional inactive legacy | No | 70 | Correctly blocked. |
| 26 | `/biopay/scan` | `ScopeUnavailableScreen` | Intentional inactive legacy | No | 70 | Correctly blocked. |
| 27 | `/biopay/face-scan` | `ScopeUnavailableScreen` | Intentional inactive legacy | No | 70 | Correctly blocked. |
| 28 | `/biopay/enroll` | `ScopeUnavailableScreen` | Intentional inactive legacy | No | 70 | Correctly blocked. |
| 29 | GoRouter error | `NotFoundScreen` | Active 404 fallback | No | 72 | Simple fallback; no route coverage or accessibility proof. |

## Non-route Screens and System Surfaces

| Surface | Widget | Status | 100% compliant? | Main gap |
|---|---|---|---|---|
| Native splash | `flutter_native_splash` | Active at startup | Not audited | Native asset/config was not visually verified in this pass. |
| Dart splash | `MobiSplashScreen` | Deleted after audit | Closed | Native splash remains the startup surface. |
| Shell | `MobiShell` | Active app shell | No | Bottom nav uses `GestureDetector` without explicit tab semantics. |
| Offline banner | `ConnectivityOverlay` | Active app wrapper | No | Needs screen-reader and safe-area runtime proof. |
| Fatal error fallback | `MobiFatalErrorView` | Active release fallback | No | Needs release-mode smoke proof. |

## Popups, Dialogs, Sheets, and Wizards

| Surface | Type | Used by | Status | 100% compliant? | Gap |
|---|---|---|---|---|---|
| `MobiConfirmDialog` | Confirmation dialog | Trip cancel, booking cancel, admin auth contact, admin trip cancel, broadcast submit/review/send | Active | No | Custom dialog lacks explicit SafeArea and guideline tests. |
| Raw `AlertDialog` report form | Dialog | `TripChatScreen` | Active | No | Should use shared dialog/sheet pattern; needs label/large-text validation. |
| Raw `AlertDialog` block user | Dialog | `TripChatScreen` | Active | No | Should use `MobiConfirmDialog`; destructive state should be standardized. |
| Raw `AlertDialog` report moderation | Dialog | `AdminReportsScreen` | Active | No | Should use shared confirm pattern. |
| `PermissionAccessDialog` | General dialog | None found | Implemented unused | No | Location permission rationale is not wired into nearby/schedule flow. |
| `MobiBottomSheet` | Shared bottom sheet wrapper | No direct use found | Implemented mostly unused | No | Screens use ad hoc `showModalBottomSheet` instead of the shared wrapper. |
| WhatsApp country picker | Bottom sheet | `WhatsAppInput` | Active | No | Needs route/form coverage and large-text proof. |
| Edit profile country picker | Bottom sheet | `EditProfileScreen` | Active | No | Ad hoc sheet, not shared bottom sheet wrapper. |
| Similar scheduled posts | Bottom sheet | `ScheduleTripScreen` | Active | No | Useful assistive sheet; no explicit wizard/progress semantics. |
| Favorite address picker | Bottom sheet | `TripRouteForm` | Active | No | Needs keyboard/focus and large text proof. |
| Admin WhatsApp number sheet | Bottom sheet | `AdminDashboardScreen` | Active | No | Good focused sheet; no tests found. |
| Admin user sheet | Bottom sheet | `AdminUsersScreen` | Active | No | Good focused sheet; no tests found. |
| Vehicle country editor | Bottom sheet | `AdminVehicleTypesScreen` | Active | No | Dense wrap content needs large-text validation. |
| Subscription edit sheet | Bottom sheet | `AdminSubscriptionsScreen` | Active | No | Form needs keyboard, focus, and overflow validation. |
| Campaign detail sheet | Bottom sheet | `AdminBroadcastsScreen` | Active | No | Dense detail/timeline sheet needs breakpoint validation. |
| App wizard | Multi-step wizard | None | Missing | No | OTP and scheduling are inline flows, not explicit wizards with progress/review steps. |

## Missing or Incomplete Screens

Priority order:

1. Scheduled trip edit screen. Product scope says scheduled trip create/view/edit/cancel, but code shows create and cancel, not an edit route or `updateTrip` service path.
2. First-run profile completion wizard after WhatsApp verification. The app can authenticate and show profile/edit profile, but no guided setup exists for role, country, vehicle, consent, and first trip.
3. Location permission education screen/sheet wired into Nearby and Schedule. `PermissionAccessDialog.location()` exists but no usage was found.
4. Notification permission and consent onboarding. Profile consent controls exist, but there is no first-run notification permission wizard.
5. Report/block shared moderation sheet. Chat report/block and admin report review use raw dialogs instead of shared Mobio modal patterns.
6. Admin moderation detail screen or sheet for reports/audit events. Current admin reports and audit are dense lists/cards without a dedicated deep detail surface.
7. Tablet/large-screen navigation variant. The app is portrait-locked and uses a 3-tab bottom nav only; no navigation rail or expanded layout proof exists.
8. Accessibility/golden test suite for every route. Current tests cover selected widgets and scope boundaries, not all screens across dark/light, large text, and tap-target/contrast guidelines.
9. Native splash decision cleanup. Closed 2026-06-08 by deleting the unused Dart splash screen.
10. Design system cleanup for inactive BioPay references. Closed 2026-06-08 by removing the stale active BioPay benchmark from `design.md`.

## Cross-cutting Compliance Findings

- Accessibility: partial. Several shared controls expose semantics, but bottom navigation tabs use raw `GestureDetector`; no full `meetsGuideline` route tests were found.
- Adaptive/responsive: partial. Some admin screens use `LayoutBuilder`, several lists use `RefreshIndicator.adaptive`, but the app is locked to portrait and lacks tablet/foldable navigation proof.
- Platform-native UI: partial. Material widgets and adaptive refresh/switch controls are used, but iOS modal/sheet conventions are inconsistent.
- Design system: partial to strong. Tokens, typography, badges, panels, buttons, and empty/error components exist; some screens still use ad hoc dialogs/sheets.
- Test pyramid: partial. There are model/service/release-boundary tests and selected widget tests, but no full screen, golden, accessibility-guideline, or integration route matrix.
- Product completeness: partial. Active scope is correctly narrowed away from payments/BioPay, but scheduled trip editing and first-run setup/permission wizards are missing.

## Verification Notes

Attempted runtime validation:

- `./scripts/ci/verify_flutter.sh` with `FLUTTER_BIN=/Volumes/PRO-G40/flutter_3_44/bin/flutter` was started but produced no output and had to be stopped.
- `/Volumes/PRO-G40/flutter_3_44/bin/flutter --version` also produced no output and had to be stopped.

Because Flutter runtime validation did not complete, this report is a code-grounded inventory and design/a11y audit, not a visual device-certified pass.

## Progress Log

2026-06-08:

- Added `docs/product/mobio_100_percent_mobile_readiness_goal_and_plan_2026-06-08.md`.
- Hardened `MobiBottomNav` with explicit tab semantics, stable minimum tap targets, tooltips, and reduced-motion behavior.
- Added `test/shared/widgets/mobi_bottom_nav_test.dart`.
- Removed the unused Dart `MobiSplashScreen`; native splash remains the startup surface.
- Removed the stale active BioPay benchmark reference from `design.md`.
- Targeted verification passed: `/Volumes/PRO-G40/flutter_3_44/bin/flutter test test/shared/widgets/mobi_bottom_nav_test.dart`.
- Added scheduled trip edit foundation: `TripService.updateTrip`, `/trip/:id/edit`, edit-mode schedule state prefill, owner-only edit action on trip details, and route/state tests.
- Targeted verification passed: `/Volumes/PRO-G40/flutter_3_44/bin/flutter test test/shared/widgets/mobi_bottom_nav_test.dart test/core/router/app_router_test.dart test/features/bookings/models/schedule_trip_state_test.dart`.
- Analyzer passed: `/Volumes/PRO-G40/flutter_3_44/bin/dart analyze`.
