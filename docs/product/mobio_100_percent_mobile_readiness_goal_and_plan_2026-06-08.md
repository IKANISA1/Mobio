# Mobio 100% Mobile Readiness Goal and Implementation Plan

Date: 2026-06-08
Checkout: `/Volumes/PRO-G40/MOBI/mobi_app`
Source audit: `docs/reports/mobio_flutter_mobile_screen_inventory_2026-06-07.md`
Report path: `/Volumes/PRO-G40/MOBI/mobi_app/docs/product/mobio_100_percent_mobile_readiness_goal_and_plan_2026-06-08.md`

## Robust Goal

Bring Mobio to a defensible 100% mobile UI, accessibility, adaptive-layout, product-completeness, and release-evidence standard for the approved app scope only:

- nearby discovery for drivers and passengers
- profile and vehicle-type browsing
- WhatsApp handoff and in-app chat
- scheduled trip post create, view, edit, and cancel
- basic moderation and admin operations for users, scheduled posts, chat reports, roles, audit logs, operational health, and broadcasts

The goal is not to revive in-app payments, ledgers, fare engines, automatic dispatch, trip lifecycle settlement, refunds, earnings, or route tracking. BioPay was later reactivated by `docs/product/biopay_ussd_aws_reactivation_scope_2026-06-12.md` as an external USSD handoff and AWS face-identity surface only.

## Definition of 100%

A screen, popup, sheet, wizard, or route can be marked 100% only when all of this evidence exists:

1. Product completeness: all expected actions in approved scope exist and work.
2. Native mobile behavior: navigation, sheets, dialogs, back behavior, keyboard handling, safe areas, and platform conventions are correct.
3. Accessibility: semantic labels, focus order, screen-reader output, non-color-only state, 48 dp Android and 44 pt iOS targets, contrast, and 200% text scale are verified.
4. Adaptive layout: compact phone, large phone, tablet-width, landscape/foldable where supported, and low-height states show no clipping or overlap.
5. State coverage: loading, empty, error, disabled, focused, success, destructive confirmation, offline, and permission-denied states are implemented.
6. Test coverage: unit, widget, accessibility-guideline, route, golden or screenshot, integration, and release smoke tests exist for the relevant risk.
7. Runtime evidence: Android and iOS simulator/device screenshots or videos exist for critical routes and states.
8. Release evidence: analyze, tests, secret scan, scope boundary tests, and release smoke/build gates pass with required `--dart-define` values.

No current screen is 100% under this definition until the evidence matrix proves it.

## Workstreams

### 1. Baseline, Scope, and Evidence Control

Deliverables:

- Update the audit into an implementation tracker with each route/surface mapped to owner, status, and proof required.
- Keep inactive legacy routes explicitly unavailable or remove deep-link exposure only if product approves.
- Keep the product route/state mapping aligned with the later BioPay USSD/AWS reactivation scope. The external `revolut-design` skill is the sole visual authority; product mappings and acceptance evidence live under `docs/design/`.
- Add a route inventory test that fails when new screens, dialogs, or inactive legacy routes are introduced without tracker coverage.

Acceptance gates:

- Scope boundary tests pass.
- No active imports, routes, services, prompts, or UI revive in-app payments, ledgers, fare engines, automatic dispatch, or trip settlement; BioPay remains limited to USSD handoff and AWS face identity.
- The implementation tracker covers every route, overlay, modal, sheet, wizard, and inactive fallback.

### 2. Shared Shell and Modal Foundation

Deliverables:

- Upgrade `MobiBottomNav` from raw `GestureDetector` tabs to accessible tab/button semantics with stable tap targets and focus behavior.
- Add compact and expanded shell behavior: bottom navigation for compact widths and navigation rail or equivalent for wider layouts.
- Harden `MobiConfirmDialog`, `MobiBottomSheet`, and `PermissionAccessDialog` for SafeArea, large text, reduced motion, focus order, and screen-reader labels.
- Replace raw `AlertDialog` usage in chat and admin report review with shared Mobio patterns.
- Standardize ad hoc bottom sheets where practical through `MobiBottomSheet`.

Acceptance gates:

- Shared widget tests cover semantics, 200% text scale, reduced motion, tap targets, and light/dark rendering.
- Existing screens continue to use the 3 top-level tab model.
- No text clipping in compact and tablet-width shell tests.

### 3. Missing Product Flows

Deliverables:

- Add scheduled trip edit route `/trip/:id/edit`.
- Add `TripService.updateTrip` and controller support for edit mode using the existing server RPC or direct RLS-safe update path.
- Reuse the schedule form in create/edit modes with prefilled values, review state, success state, and clear validation.
- Add first-run profile completion wizard after WhatsApp verification.
- Wire location permission education into Nearby and Schedule before location-dependent actions.
- Add notification permission and consent onboarding connected to existing profile consent settings.

Acceptance gates:

- Scheduled trip create, view, edit, and cancel work for the trip owner.
- Non-owners cannot edit or cancel.
- Profile completion, location permission, and notification consent flows can be skipped, resumed, and completed without trapping the user.
- Unit, widget, and route tests cover success and failure paths.

### 4. Chat and Admin Moderation Completion

Deliverables:

- Replace chat report/block raw dialogs with shared report/block sheets.
- Add admin report detail and audit event detail surfaces.
- Improve admin dense screens with clearer drill-in, search, sort, pagination, and empty/error states.
- Keep admin finance inactive and out of active admin navigation.

Acceptance gates:

- Report, block, unblock, admin review, audit drill-in, and copy actions have accessible labels and confirmation behavior.
- Admin report/audit details do not expose direct personal contact data beyond already permitted operational fields.
- Moderation tests cover open, reviewing, resolved, dismissed, blocked, and unblock states.

### 5. Screen-by-screen Native UI Hardening

Deliverables:

- Review and harden every active passenger and admin route from the audit table.
- Confirm each screen has a single clear primary action, concise copy, shared tokens, and no ad hoc styling where a shared component exists.
- Clean up orphaned `MobiSplashScreen` by either wiring it intentionally or deleting it if native splash is the only startup surface.
- Keep `ScopeUnavailableScreen` polished for all inactive legacy deep links.

Acceptance gates:

- Every route passes compact, large-phone, tablet-width, 200% text, reduced-motion, dark/light, loading, empty, error, and success-state checks.
- No screen uses hard-coded colors or one-off modal styling unless documented as an exception.

### 6. Test Pyramid and Visual Evidence

Deliverables:

- Add route matrix widget tests for all active routes and inactive fallbacks.
- Add accessibility-guideline tests for tappable targets, labels, contrast where supported, and large text.
- Add golden or screenshot tests for critical states.
- Add integration smoke tests for login redirect, profile completion, schedule create/edit/cancel, nearby permission, chat report/block, and admin report review.
- Capture Android and iOS runtime screenshots for the final evidence pack.

Acceptance gates:

- `dart analyze` passes on the pinned Dart SDK.
- `flutter test` passes on the pinned Flutter SDK.
- Scope, secret, release config, and release smoke scripts pass.
- Evidence files are current, non-template, and referenced from the tracker.

## Tooling and Agent Use

- Main implementation: local Codex in this repo.
- Flutter specialist agent: sequencing review and high-risk Flutter architecture checks.
- Product design skill: screen and flow audit, UX critique, and design acceptance matrix.
- Accessibility skill: semantic, focus, contrast, tap target, and large text requirements.
- Adaptive UI skill: compact, large phone, tablet, foldable, and orientation matrix.
- Design-system skill: token, component, theme, modal, and shared-surface governance.
- Clean architecture skill: keep feature modules, providers, services, and tests isolated.
- Test-pyramid skill: unit, widget, accessibility, integration, visual, and release smoke coverage.
- Dart/Flutter MCP or pinned CLI: inspect packages, run analysis, run tests, and validate route/widget behavior when runtime is responsive.
- Browser/visual tools: use screenshots for web or simulator-hosted Flutter previews only when the app can run reliably.

## Current Priority Order

1. Write this goal and tracker plan.
2. Fix shared navigation and modal accessibility foundations.
3. Implement scheduled trip edit.
4. Add first-run profile, location, and notification wizards.
5. Standardize chat/admin moderation modals and detail surfaces.
6. Add adaptive shell behavior and screen-by-screen hardening.
7. Build route/accessibility/golden/integration test matrix.
8. Capture runtime evidence and refresh the audit to mark items complete only with proof.

## Known Risks

- Flutter validation now passes when run serially. Avoid parallel Flutter test runs because native-assets output can race and produce false toolchain failures.
- Backend support for `rpc_update_trip` exists in an older migration, but live Supabase deployment still needs proof before edit can be marked production-ready.
- The app is currently portrait-locked, so adaptive readiness needs a product decision: keep portrait-only but prove large-screen portrait behavior, or support orientation changes.
- The worktree may contain unrelated existing changes. Do not revert user or generated work outside this objective.
- Some admin screens are large and dense. They may need staged hardening rather than one risky rewrite.
