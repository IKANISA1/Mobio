# Revolut Comparative UI/UX Audit: Flutter App and Admin Panel

> Historical comparison evidence. References to the former local specification
> below record the audited source, deleted on 30 September 2026. The external
> `revolut-design` skill is the sole design authority; the dated scores and
> recommendations do not establish current fidelity or acceptance.

Date: 2026-06-13
Checkout: `/Volumes/PRO-G40/MOBI/mobi_app`
Report scope: full routed Flutter app, BioPay surfaces, admin panel/PWA, shared design system, visual evidence, and route-level test evidence.

## Executive Verdict

Mobio has a credible Revolut-reference design system for the main dark shell, but the full repo is not uniformly Revolut-aligned. The passenger Home, Nearby, Bookings, Schedule, Profile, Chat, and Admin preview surfaces share the correct grammar: saturated gradient-to-black shell, black chrome, circular actions, large centered hero moments, floating navigation, badge/chip metadata, and dark translucent panels.

The full-app parity claim breaks at BioPay. BioPay is now active and golden-covered, but its root surface is a separate white/blue hard-coded experience, not the dark tokenized Revolut-reference system defined in `design.md`. The admin panel is directionally aligned but remains operationally dense and only partially comparable to consumer Revolut surfaces.

Current critical score:

| Area | Score | Status |
| --- | ---: | --- |
| Main passenger dark-shell screens excluding BioPay | 88/100 | Strong visual grammar; still denser than Revolut and missing current native proof for every route/state. |
| BioPay consumer/payment-adjacent surfaces | 48/100 | Functional and golden-covered, but visually separate from the Revolut-reference design contract. |
| Admin panel/PWA | 78/100 | Good dark operational shell; density, tab overflow, and sheet consistency reduce parity. |
| Evidence maturity | 82/100 | Analyzer and focused tests pass; worktree is dirty and native evidence is older than this report. |
| Full repo Revolut UI/UX parity | 76/100 | Not ready for a "Revolut-level across the entire repo" claim. |

## Reference Basis

External/current references checked:

- Apple App Store listing for Revolut current public app state: screenshots are present, current version history shows `10.134` updated 2 days before this audit, and the listing declares support for VoiceOver, Voice Control, Larger Text, Dark Interface, Differentiate Without Color Alone, Sufficient Contrast, and Reduced Motion: <https://apps.apple.com/us/app/revolut-send-spend-and-save/id932493382>.
- Revolut official mobile banking page confirms the product breadth that drives its information architecture: transfers, account management, borrowing, exchange, save/invest, and rewards/cashback: <https://www.revolut.com/en-IE/ways-to-bank/mobile-banking/>.
- Google Play listing checked for current Android listing continuity: <https://play.google.com/store/apps/details?hl=en_US&id=com.revolut.revolut>.
- User-supplied Revolut reference folder still exists at `/Users/jeanbosco/Downloads/Revolut10` with 12 PNG captures, each `1170x2532`.

Local sources and proof:

- Design contract: `design.md` says the repo must keep current routes, make screens darker/immersive, use Revolut-reference command bars, circular actions, and floating black navigation, and keep copy short (`design.md:11-31`).
- Route inventory: `lib/core/router/app_router.dart` currently exposes 33 explicit routed surfaces plus error handling, including active BioPay routes and admin workspaces (`app_router.dart:29-61`, `app_router.dart:232-456`).
- Shell implementation: `lib/app.dart` uses bottom nav on compact screens and a `NavigationRail` at width `>= 720` (`app.dart:121-228`).
- Visual evidence: `test/features/preview/goldens/revolut/` contains 26 golden PNGs across `390x844` and `430x932`.
- Focused validation passed on this audit date:
  - `/Volumes/PRO-G40/flutter_3_44/bin/dart analyze`
  - `FLUTTER_BIN=/Volumes/PRO-G40/flutter_3_44/bin/flutter /Volumes/PRO-G40/flutter_3_44/bin/flutter test test/release/mobile_readiness_contract_test.dart test/release/admin_panel_production_readiness_contract_test.dart test/features/preview/revolut_reference_golden_test.dart`
  - Result: `38` tests passed. Flutter emitted a current iOS warning that `permission_handler_apple` does not yet support Swift Package Manager; this is a future compatibility risk, not a failed test.

Worktree caveat: the checkout was already dirty before this audit, including release/build files, iOS package files, BioPay evidence docs, deleted old BioPay activity goldens, and scanner test helper changes. This report does not revert or normalize those existing changes.

## Comparative Design Criteria

Revolut-reference target for Mobio should mean:

1. Full-screen dark immersive shell, not generic Material pages.
2. Top avatar/search/circular-action command chrome where useful.
3. One dominant hero value or identity moment per primary screen.
4. Four or fewer circular actions with terse labels.
5. Full-width dark translucent panels with restrained borders.
6. White/black pill CTAs rather than saturated rectangular buttons.
7. Floating black navigation with clear active capsule.
8. Low-copy rows where icons, chips, badges, and status labels do the work.
9. Accessibility parity: large text, dark interface, non-color-only state, contrast, and reduced motion.

Mobio should not copy Revolut product content: banking, crypto, invest, RevPoints, cards, rewards, or financial claims are not part of the approved mobility scope.

## Screen-by-Screen Findings

| Route / surface | Current state | Revolut comparison | Gap | Recommendation |
| --- | --- | --- | --- | --- |
| `/login` WhatsApp OTP | Modern dark auth flow with country picker and OTP states. | Good enough if treated like Revolut onboarding/security. | Needs fresh native large-text, keyboard, and country-sheet proof. | Add golden/native evidence for country picker, OTP entry, error, resend, locked/resume states. |
| `/` Home | Strongest aligned screen: dark gradient, circular command/action grammar, large hero, chip filters, list panels. | Close to supplied Revolut home capture. | Uses 3 actions instead of Revolut-like 4; Home command bar hides search. | Either add a real fourth action or document 3-action transport constraint; add search only if it opens a real discovery function. |
| Home mode toggle | Passenger/Driver toggle is visually polished. | Revolut uses account/product switching but less explicit mode switching. | Product density appears earlier than Revolut. | Keep it, but ensure the toggle remains visually secondary to the hero. |
| `/nearby` | Uses `MobiTopCommandBar`, centered hero, count badge, compact permission banner, filter chips. | Strong Revolut-like command/hero pattern. | Map action appears presentational unless linked to an actual map handoff; state proof is limited. | Wire/disable map action explicitly; capture permission denied, no drivers, active drivers, and error states. |
| `/bookings` | Uses dark list grammar, badges, status chips, and cancel confirmation. | Good list-panel adaptation of Revolut transaction/activity lists. | Still operationally wordier than Revolut. | Reduce secondary text to chips; add visual proof for empty/error/loading and long route names. |
| `/schedule` | Edit/create form exists and is constrained to max width. | Less Revolut-like because it is a long form, not a sparse product page. | Uses ad hoc `showModalBottomSheet` for suggestions; no step/progress model. | Move suggestions into `MobiBottomSheet`; consider a 3-step review flow: route, timing, confirm. |
| `/trip/:id` | Good detail surface with badges/chips and owner actions. | Comparable to a Revolut transaction detail page if copy stays tight. | Needs current golden/native coverage for owner/non-owner, cancelled, bus, and private states. | Add route-specific golden matrix and evidence snapshots. |
| `/trip/:id/edit` | First-class route now exists. | Acceptable as a pushed form. | No separate Revolut-reference golden case. | Add edit-mode golden and validation/error-state tests. |
| `/chat` | Dark shell with private badge and route context; block uses shared confirm. | Good direction, but chat is not central in Revolut references. | Needs proof for report sheet, blocked state, empty conversation, keyboard overlap. | Add golden/native captures for moderation and keyboard states. |
| `/notifications` | Uses shared page header. | Fine utility route, but not currently in Revolut golden matrix. | Missing comparative evidence. | Add to golden and native proof set. |
| `/profile` | Uses terse feature tiles and settings list. | Directionally aligned with account/settings areas. | Profile surfaces are more settings-heavy and less visual/identity-led. | Put member identity/trust/role badges first; push secondary settings lower. |
| `/profile/setup` | Dedicated first-run setup route now exists. | Comparable to onboarding, not to home screens. | Needs step/progress semantics and evidence. | Add setup wizard proof for passenger, driver, notification, and skipped states. |
| `/edit-profile` | Form exists with country and bus fields. | Less aligned due form density. | Ad hoc country sheet; needs large-text/keyboard proof. | Standardize bottom sheets and add focus-order tests. |
| `/config-error` | Active fallback. | Not comparable to Revolut consumer UI. | Developer-facing copy and no visual proof. | Make it a polished fatal state with one action and no technical noise. |
| GoRouter 404 | Active fallback. | Not comparable. | Missing route/golden evidence. | Add visual proof and concise recovery action. |
| `/ledger` | Scope unavailable. | Correctly avoids unsupported finance surface. | Route still exists by deep link. | Keep blocked unless product scope changes; style as dark Mobio unavailable state. |
| `/biopay` | White/blue "Pay & Get Paid Instantly" grid with hard-coded colors and local light theme. | Major mismatch against dark Revolut-reference shell. | P0 visual inconsistency: separate product language, hard-coded palette, no floating black nav feel inside root surface. | Redesign BioPay root into dark shell: identity hero, 3-4 circular actions, black command chrome, white pill CTA, tokenized colors only. |
| `/biopay/qr` | Golden-covered BioPay subflow. | Likely functionally clear, but visually belongs to BioPay's separate system. | Needs token unification and native proof. | Re-skin under `SoftGradientTone.success` or `shell`, keep QR legibility in a high-contrast panel. |
| `/biopay/scan` | Golden-covered scanner route. | Scanner utility can be full-screen, but surrounding chrome should match app. | Camera/scanner states are high risk for permission/blank-frame UX. | Add permission denied, unavailable camera, successful scan, invalid QR captures. |
| `/biopay/face-scan` | Golden-covered. | Security/identity is a natural Revolut-like pattern. | Hard-coded status colors and custom painter details diverge. | Tokenize face scan rings/states; add reduced-motion behavior. |
| `/biopay/enroll` | Golden-covered. | Comparable to identity verification. | Copy and step flow need current native proof. | Treat as a verification flow: clear progress, single primary action, concise failure recovery. |
| `/biopay/nfc` | Golden-covered. | Comparable to tap/payment/security utility. | Hard-coded status colors and platform state proof gaps. | Add NFC unavailable, waiting, success, timeout, and error states to evidence. |
| `/admin-auth` | Dark admin auth with status banners. | Admin auth is not consumer Revolut, but uses shared grammar. | Operational copy and support states need visual proof. | Keep concise; add auth error/locked/out-of-role screenshots. |
| `/admin` dashboard | Strong dark admin frame, tabs, metric cards. | Similar visual language, but operational density is higher than Revolut. | Header tab strip can overflow/clip on compact widths; admin preview only proves a shallow state. | Use horizontally scrollable tabs with stronger active affordance; add real dashboard data-state proof. |
| `/admin/users` | Dense user management with sheet, filters, metrics, bulk actions. | More SaaS/ops than Revolut; acceptable if intentionally admin. | High density, sheet consistency, and bulk-selection cognitive load. | Keep data controls, but compress chrome and add row detail drawer/sheet evidence. |
| `/admin/profile` | Reuses profile. | Aligned enough visually. | Admin account state is shallow. | Add admin-specific identity, permissions, session, and audit summary cards. |
| `/admin/vehicle-types` | Catalog management with responsive panels. | Not comparable to Revolut consumer flows. | Dense catalog forms, ad hoc sheets, large-text risk. | Add server-backed pagination if catalog grows; capture edit/country sheet at 200% text. |
| `/admin/subscriptions` | Catalog management. | Operational admin, not consumer. | Similar density and sheet proof gaps. | Add compact table/list toggle for web admin; capture create/edit/disabled states. |
| `/admin/trips` | Moderation list with cancel confirmation. | Comparable to admin transaction monitoring. | No dedicated trip drill-in route; table/list proof gaps. | Add trip detail sheet/route with audit trail and concise operator actions. |
| `/admin/reports` | Report detail sheet now exists; status badges and actions present. | Good admin adaptation. | Still dense; moderation decisions need stronger visual hierarchy. | Make report detail the primary review surface; keep list rows summary-only. |
| `/admin/finance` | Routes to `BioPayAdminConsoleScreen`, despite older docs saying inactive. | Not Revolut-like as a consumer surface; admin reconciliation can exist. | Scope naming conflict: route constant says finance, active screen is BioPay admin console. | Rename/document as BioPay operations if active; avoid generic finance language unless scope approves. |
| `/admin/health` | Operational health cards/events. | Acceptable admin analytics pattern. | Needs large-data and degraded-state evidence. | Capture healthy, degraded, incident, empty, and stale-data states. |
| `/admin/audit` | Audit detail sheet exists with formatted JSON. | Good admin compliance utility. | Dense logs and JSON can overwhelm compact screens. | Use summary-first detail sheet with collapsible raw JSON. |
| `/admin/broadcasts` | Large compose/approval/send surface. | Least Revolut-like among admin pages due workflow complexity. | Mixed compose, timeline, approval, and metrics create heavy first screen. | Split into list, compose, approval detail, and send confirmation surfaces. |
| Admin PWA boundary | `apps/admin` is a boundary only; runtime still comes from root Flutter app. | Acceptable if build/deploy scripts are clear. | No separate admin frontend exists. | Continue treating admin as Flutter route/PWA until package migration is explicitly planned. |

## Critical Findings

### P0: BioPay breaks full-repo Revolut parity

Evidence: `lib/features/biopay/biopay_screen.dart` defines a standalone BioPay palette (`_bioPayBlue`, `_bioPayCanvas`, `_bioPayPanel`, etc.) and wraps the root screen in a custom light theme (`biopay_screen.dart:26-55`). The root BioPay screen renders a white page and a 2x2 tile grid (`biopay_screen.dart:72-149`). This is the opposite of the dark immersive system in `design.md`.

This is not just a cosmetic preference. The design contract says dark mode is the primary shell, command/nav chrome should use black tokenized overlay, support colors should not compete as brand colors, and primary CTAs should stay white pills on dark surfaces unless a semantic state requires otherwise (`design.md:63-94`).

### P1: Main shell is close, but not uniformly applied

Home and Nearby are close to the supplied Revolut reference. Home uses `SoftGradient`, `HomeHeader`, a segmented mode toggle, a large hero, `MobiActionRow`, filter chips, and content panels (`home_screen.dart:261-380`). Nearby uses `MobiTopCommandBar`, centered hero type, badges, permission banner, and filter chips (`nearby_screen.dart:249-380`).

The gap is consistency. Some pushed screens use `MobiPageHeader`, some shell screens use `MobiTopCommandBar`, and BioPay uses neither. A user moving through the app will feel two design systems.

### P1: Admin is visually coherent but operationally too dense for a Revolut claim

Admin uses a shared dark `AdminWorkspaceFrame`, max content width, tokenized panels, tabs, metric cards, and badges (`admin_ui.dart:45-218`). This is good. But the dashboard, reports, audit, broadcasts, and catalog screens are work surfaces; they require more controls than Revolut's consumer pages.

The recommendation is not to make admin "look consumer." It is to preserve admin density while applying the same primitives: concise headers, one primary task per screen, compact chips, clear detail sheets, and fewer mixed responsibilities per viewport.

### P1: Evidence is good for static Flutter preview, incomplete for release-quality UI parity

The current golden suite covers 13 screen cases at two phone sizes and passed during this audit. It proves the local preview baselines are stable. It does not prove:

- current physical Android or iOS route rendering for every route;
- 200% text scale;
- keyboard overlap;
- motion/reduced motion parity;
- camera/NFC/QR permission states;
- real Supabase data density;
- web admin at desktop breakpoints.

### P2: The route count is larger than the visible navigation model

The shell has four passenger/admin branches now: Home/Ops, Trips/Users, BioPay, Profile/Account (`app.dart:215-227`). The design contract still says "3-tab shell" (`design.md:11-14`). The code and design document should be reconciled so future audits do not treat BioPay as either an exception or an accidental new top-level tab.

### P2: Modal/sheet standardization is still partial

The repo has `MobiBottomSheet`, but many screens still call `showModalBottomSheet` directly: schedule suggestions, profile vehicle, edit profile, admin users, admin reports, admin audit, admin dashboard, admin broadcasts, vehicle types, subscriptions, and WhatsApp input. Some direct usage is fine, but the current spread weakens focus, safe-area, large-text, and visual consistency guarantees.

## Admin Panel Status

There is no separate runnable React/Next/admin frontend under `apps/admin`. `apps/admin/README.md` says the admin source of truth is `lib/features/admin`, `lib/core/router`, and admin services, with generated output under `build/pwa/admin`. `apps/pwa` similarly documents that passenger/driver web output is generated from the root Flutter app.

Current admin status:

- Route guard exists and client-gates admin routes while server RPCs still enforce authorization (`app_router.dart:64-113`).
- Admin panel routes are first-class Flutter routes (`app_router.dart:377-424`).
- Admin PWA contracts passed in this audit.
- Visual admin golden is preview-level only. It does not cover every actual admin route.

Admin recommendation: treat this as one Flutter app with an admin PWA deployment target, not as a separate admin codebase. Do not create a separate admin frontend unless the migration plan includes routing, auth, CI, deploy, and visual regression continuity.

## Recommended Roadmap

1. Redesign BioPay into the tokenized dark system.
   - Replace the white root with `SoftGradient`.
   - Use `MobiTopCommandBar` or a compact `MobiPageHeader`.
   - Convert the 2x2 large cards into circular action row plus one primary identity/payment panel.
   - Remove hard-coded `_bioPay*` colors except where needed for scanner/QR legibility, and move semantic color into tokens.

2. Refresh native visual evidence.
   - Capture Android and iOS screenshots for Home, Nearby, Bookings, Schedule, Trip Detail, Trip Edit, Chat, Login, Profile, Profile Setup, Edit Profile, all BioPay subflows, and every admin route.
   - Include 200% text, keyboard, permission denied, loading, empty, error, and success states.

3. Finish admin route-level visual coverage.
   - Add golden cases for admin auth, users, vehicle types, subscriptions, trips, reports, finance/BioPay ops, health, audit, and broadcasts.
   - Add desktop web screenshots for admin at `1280`, `1440`, and compact tablet widths.

4. Reconcile design documentation.
   - Record the supported shell destinations in the product route/state mapping under the external `revolut-design` skill; a local specification cannot govern subsequent changes.
   - Clarify BioPay as active scope and specify whether it must follow the same dark shell.
   - Rename `/admin/finance` if it is actually BioPay operations.

5. Standardize sheets and high-risk modal flows.
   - Route direct `showModalBottomSheet` calls through `MobiBottomSheet` or document exceptions.
   - Prioritize WhatsApp country picker, edit profile country picker, schedule suggestions, admin detail sheets, and BioPay permission/device sheets.

6. Reduce density selectively.
   - Do not remove operational controls from admin.
   - Do remove repeated subtitles, long helper paragraphs, and multi-purpose first screens where a detail sheet or second route would be clearer.

## Bottom Line

Mobio is no longer a generic Flutter app visually. The main mobility shell has a serious Revolut-reference foundation and the golden suite is passing. But the whole repo cannot be described as Revolut-aligned while BioPay ships as a separate light/blue design system and admin remains only partially covered by route-specific visual evidence.

The right next move is not another broad redesign. It is a focused BioPay visual unification pass, followed by complete route-level native/admin evidence.
