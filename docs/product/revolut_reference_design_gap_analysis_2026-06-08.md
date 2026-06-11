# Revolut Reference Design Gap Analysis

Date: 2026-06-08

Reference inputs:

- Attached Revolut screenshots for Home, Invest, Crypto, RevPoints, Analytics, Profile, Contact, and Payments surfaces.
- New MOBI/Collect node colors:
  - `#8885F0` Periwinkle
  - `#D38B96` Dusty rose
  - `#FF5E43` Vibrant orange-red
  - `#3CD070` Mint green

## Executive Finding

The current MOBI design system is coherent, but it is not close to the attached
Revolut reference. It currently reads as a premium minimalist mobility app with
green brand tokens, warm/light surfaces, 3-tab navigation, compact clay cards,
and operational widgets.

The Revolut reference reads as an immersive fintech shell: dark gradient-first
screens, black pill search, circular command buttons, central hero balances or
product statements, translucent rounded cards, circular quick actions, and a
floating black multi-item bottom bar.

Current Revolut-reference correlation score: `34/100`.

Target after implementation: `90-95/100` reference grammar match while keeping
MOBI content, MOBI routing, and MOBI legal/product boundaries. Exact 100 percent
visual copying of Revolut logos, product names, proprietary card imagery, and
financial/crypto/payment claims should not be shipped. The correct target is:
same interaction grammar, hierarchy, rhythm, density, and material feel, with
MOBI-owned content and the four provided colors.

## Current MOBI Design System

Current source of truth:

- Product spec: `design.md`
- Flutter tokens: `packages/design-system/lib/src/theme/`
- App compatibility exports: `lib/core/theme/`
- Shared widgets: `lib/shared/widgets/`

Current strengths:

- Centralized theme package and compatibility exports already exist.
- Shared components already cover panels, buttons, bottom navigation, badges,
  chips, action rows, toggles, loading states, dialogs, and empty/error states.
- Current app routes are isolated behind a `StatefulShellRoute`, so shell and
  visual system work can be done without rewriting business logic.
- Existing visual audit already pushes toward shorter copy and reusable widgets.

Current dominant visual language:

- Primary color is `#006D2F` green.
- Dark palette uses graphite/charcoal surfaces.
- Light palette uses soft warm neutral surfaces.
- Typography uses Manrope headlines and Inter body.
- Screen padding is 24, section gaps are 32, and card radii are 24-32.
- Bottom navigation is a 3-item floating glass card: Home, Trips, Profile.
- Home is a mobility dashboard with a header panel, mode toggle, metric hero
  card, rectangular action row, vehicle filters, and scheduled trip lists.

## Revolut Reference System

The attached Revolut screenshots consistently show these rules:

1. Backgrounds are full-screen dark gradients, not card-first pages.
2. Top chrome is avatar plus black pill search plus two circular command buttons.
3. Primary screen content is centered and large: amount, product statement, or
   product invitation.
4. Quick actions are circular icon buttons with labels below.
5. Cards are dark translucent rounded rectangles with minimal borders and no
   heavy decorative shadows.
6. CTAs are often white or translucent pills on dark backgrounds.
7. Bottom navigation is a floating black rounded pill with 5 visible sections
   and a larger active capsule.
8. Profile and detail screens use black background, large identity typography,
   circular close/back controls, and simple dark list panels.
9. Dense operational copy is suppressed. Most surfaces use title, one support
   line, and direct action.
10. The reference relies on depth through opacity, blur, gradient, and spatial
    hierarchy rather than bright card colors.

## Critical Gap Matrix

| Area | Current MOBI | Revolut Reference | Gap | Severity |
| --- | --- | --- | --- | --- |
| Brand color | Green-first `#006D2F` with muted secondary/tertiary | Blue, teal, purple, black, white, and high-contrast accent nodes | Replace brand system with four supplied colors and dark gradient neutrals | P0 |
| Background | Soft neutral gradient plus top decorative orb | Full-screen immersive dark gradient | Replace `SoftGradient`; remove decorative orb | P0 |
| Theme mode | Light and dark both supported; light is first-class | Reference is predominantly dark | Make dark visual system default for shell; retain accessible light mode as secondary | P0 |
| Typography | Manrope/Inter with negative display tracking | System-like, clean, large white type, no cramped labels | Set letter spacing to 0 and increase hero/display scale | P0 |
| Top chrome | MOBI logo/title inside surface panel | Avatar, black pill search, circular command buttons | Create shared `MobiTopCommandBar` | P0 |
| Navigation | 3-tab glass nav, active icon plus text | 5-item black pill nav, active capsule | Restyle immediately; decide whether to expand to 5 product-owned tabs | P0/P1 |
| Home hierarchy | Header card, toggle, hero metrics, filters | Centered hero statement/amount, circular actions, cards below | Rebuild Home composition | P1 |
| Actions | Rectangular action tiles | Circular icon buttons with labels below | Replace `MobiActionRow` visual treatment | P1 |
| Cards | Clay/glass/panel mix, visible borders, surface shadows | One family of translucent dark rounded cards | Normalize `ClayCard`, `MobiSurfacePanel`, `GlassCard` | P1 |
| Buttons | Filled green primary, ghost/danger/success variants | Large white/translucent pills | Retokenize `MobiButton` variants | P1 |
| Profile | Compact profile card and feature tiles | Large centered avatar/name, black surface, list panel rows | Rebuild Profile composition | P1 |
| Bookings/Payments analog | Trip list with header/toggle; no Revolut command bar | Payments list has top command bar and large list panel | Restyle bookings/contact-like lists into Revolut list grammar | P1 |
| Analytics/details | Admin/metrics are operational panels | Analytics is black, cards in metric grid | Restyle metrics panels and admin detail surfaces | P2 |
| Motion | Fade/scale/slide animations | Subtle movement, mostly static material | Reduce animation amplitude | P2 |
| Test coverage | Widget tests exist for nav and shared states | Needs visual regression/golden proof | Add route screenshot/golden matrix | P2 |

## Four-Color Token Map

Use the attached colors as the new brand nodes, not as flat one-color theming.

| Token | Color | Usage |
| --- | --- | --- |
| `brandPeriwinkle` | `#8885F0` | Primary gradient node, selected nav highlight, focus ring, premium surfaces |
| `brandDustyRose` | `#D38B96` | Warm promo surfaces, profile/identity accents, secondary gradient node |
| `brandOrangeRed` | `#FF5E43` | Urgent states, notification dots, destructive/warning accents, live alerts |
| `brandMintGreen` | `#3CD070` | Positive/live states, success, confirmed transport state, safe CTA accents |

Recommended neutral system:

- `appBlack`: `#02030A`
- `surfaceBlack`: `#070812`
- `surfaceRaised`: `#151627`
- `surfaceRaisedHigh`: `#22243A`
- `surfaceStroke`: `rgba(255,255,255,0.14)`
- `onSurface`: `#F7F7FF`
- `onSurfaceMuted`: `#B9BBCD`
- `onSurfaceSubtle`: `#85889F`

Recommended gradients:

- Home: `#8885F0 -> #111A46 -> #02030A`
- Mobility/live: `#3CD070 -> #0C3F3B -> #02030A`
- Rewards/promos: `#D38B96 -> #8885F0 -> #211148`
- Warning/action required: `#FF5E43 -> #3A1112 -> #02030A`

## Compatibility Constraints

1. `design.md` currently says to keep the 3-tab shell and current route
   structure. The Revolut reference strongly implies 5 visible bottom tabs.
   This is the biggest product/design conflict.
2. MOBI has removed or constrained legacy payment/BioPay behavior in prior
   scope boundaries. Do not introduce unsupported payment, crypto, invest, or
   rewards promises just to mimic Revolut labels.
3. A direct Revolut clone would create brand/IP and product-truth risks. Use
   Revolut as the UI grammar reference, not as copied content.
4. Current shared components can be retokenized and restyled. A full rewrite is
   unnecessary and would risk business logic.

Recommended resolution:

- Keep current product-owned route meanings.
- Use a Revolut-style 5-slot shell only if each slot maps to a real MOBI
  feature. Suggested MOBI mapping:
  - Home
  - Trips
  - Nearby
  - Chat
  - Profile
- If route expansion is not approved, keep 3 tabs but make the bar, active
  capsule, icon scale, black material, and safe-area positioning match the
  Revolut reference.

## Implementation Plan

### Phase 0: Token and Contract Reset

Files to change:

- `packages/design-system/lib/src/theme/app_colors.dart`
- `packages/design-system/lib/src/theme/app_theme.dart`
- `packages/design-system/lib/src/theme/mobi_theme_extension.dart`
- `packages/design-system/lib/src/theme/app_typography.dart`
- `packages/design-system/lib/src/theme/app_radii.dart`
- `design.md`

Actions:

1. Replace green-first brand tokens with the four supplied brand nodes.
2. Add gradient and glass-material tokens to `MobiThemeExtension`.
3. Set display/headline letter spacing to `0`.
4. Preserve accessibility contrast by mapping white text to dark surfaces.
5. Update `design.md` to define the Revolut-inspired MOBI shell contract.

Acceptance criteria:

- No feature screen should hard-code old green accents.
- Theme still compiles in light and dark modes.
- Text contrast stays accessible on dark surfaces.

### Phase 1: Shell and Shared Components

Files to change:

- `lib/shared/widgets/soft_gradient.dart`
- `lib/shared/widgets/glass_container.dart`
- `lib/shared/widgets/mobi_surface_panel.dart`
- `lib/shared/widgets/mobi_bottom_nav.dart`
- `lib/shared/widgets/mobi_action_row.dart`
- `lib/shared/widgets/mobi_button.dart`
- New: `lib/shared/widgets/mobi_top_command_bar.dart`

Actions:

1. Replace `SoftGradient` with a full-screen dark gradient layer using the four
   brand colors as screen-specific nodes.
2. Remove the decorative orb from the background.
3. Convert surface panels to translucent dark cards with white border alpha.
4. Convert action rows to circular icon controls with labels below.
5. Convert primary buttons to large white/translucent pills.
6. Rebuild bottom nav as a black floating pill with larger active capsule.
7. Add a shared top command bar: avatar, search pill, and circular command
   buttons.

Acceptance criteria:

- Home, Trips, and Profile share the same top command bar grammar.
- Bottom nav visually matches the reference material and spacing.
- Touch targets remain at least 48 logical pixels.

### Phase 2: Main Passenger Screen Conversion

Files to change:

- `lib/features/home/home_screen.dart`
- `lib/features/home/widgets/home_header.dart`
- `lib/features/home/widgets/home_hero_card.dart`
- `lib/features/bookings/bookings_screen.dart`
- `lib/features/nearby/nearby_screen.dart`
- `lib/features/chat/chat_screen.dart`
- `lib/features/profile/profile_screen.dart`

Actions:

1. Rebuild Home around a centered hero and circular action strip.
2. Restyle bookings into a Revolut payments/contact-list grammar: command bar,
   dark list panel, avatar/route icons, date/status right alignment.
3. Restyle Nearby as the mobility equivalent of a product discovery page with
   dark promo cards and compact action chips.
4. Restyle Chat list/details into black detail surfaces with large identity
   headers and list cards.
5. Rebuild Profile with centered avatar/name, top close/upgrade-style action
   slot, dark plan card, and simple list rows.

Acceptance criteria:

- No screen still looks like the old green clay-card system.
- Every primary route has the same top chrome, nav, card radius, and button
  material.
- Product copy remains MOBI-specific and does not promise unsupported financial
  services.

### Phase 3: Secondary and Admin Surfaces

Files to change:

- `lib/features/bookings/trip_details_screen.dart`
- `lib/features/bookings/schedule_trip_screen.dart`
- `lib/features/profile/edit_profile_screen.dart`
- `lib/features/admin/*`
- `lib/shared/widgets/mobi_metric_tile.dart`
- `lib/shared/widgets/mobi_feature_tile.dart`

Actions:

1. Convert detail pages to black profile/contact/analytics-style layouts.
2. Convert metrics into dark rounded analytics cards.
3. Keep admin operational density, but retokenize surfaces and typography.
4. Replace remaining feature tiles that still use the old rectangular language.

Acceptance criteria:

- Pushed routes feel like Revolut detail sheets/pages.
- Admin remains usable and scannable, not a consumer marketing surface.

### Phase 4: Validation

Run:

- `flutter analyze`
- `flutter test`
- Existing route/accessibility matrix tests
- New screenshot/golden route matrix for compact mobile viewport

Recommended new tests:

- Bottom nav has stable 5-slot or approved 3-slot layout.
- Top command bar controls have semantic labels.
- Text scale does not clip hero text, buttons, or nav labels.
- Theme tokens expose all four supplied colors.
- No old `#006D2F` brand usage remains except migration comments or historical
  docs.

## Immediate Edit Order

1. Update token package and docs.
2. Rebuild `SoftGradient`, `MobiSurfacePanel`, `GlassCard`, `MobiButton`,
   `MobiActionRow`, and `MobiBottomNav`.
3. Add `MobiTopCommandBar`.
4. Convert Home.
5. Convert Bookings and Profile.
6. Convert Nearby, Chat, and pushed detail routes.
7. Run analyzer/tests and produce screenshots.

## Go/No-Go for Visual Parity

Go if:

- User approves Revolut-style 5-slot navigation or confirms 3-slot route
  preservation.
- The four new colors replace old green as the brand nodes.
- Business-scope labels remain MOBI-owned.

No-go if:

- The target is literal Revolut cloning including brand marks, product names,
  crypto/invest/payment promises, or proprietary imagery.
- Unsupported payment/crypto/rewards workflows are added only for appearance.

Recommended next implementation target:

- Proceed with Phase 0 and Phase 1 immediately.
- Keep route count at 3 for the first implementation unless explicit approval
  is given to expand the shell to 5 MOBI-owned tabs.

## Implementation Status

2026-06-08 pass:

- Phase 0 complete: token package now uses the four supplied brand nodes,
  dark-first surface tokens, gradient background extension tokens, and zero
  letter spacing.
- Phase 1 complete: shared background, panels, cards, buttons, circular actions,
  bottom navigation, and top command bar now follow the Revolut-reference
  material grammar while preserving MOBI route contracts.
- Phase 2 primary-pass complete: Home, Trips/Bookings, Nearby, Chat list rows,
  and Profile now use centered hero content, black command bars, circular
  action/list affordances, and dark translucent row surfaces.
- Pushed-route/admin pass complete: Trip Details, Schedule, Edit Profile, and
  core admin panels now use the same black detail-page, hero, circular icon,
  dark panel, and metric-card grammar.

Residual gaps before claiming full visual parity:

- A screenshot/golden matrix is still needed to prove visual parity across
  compact and large mobile viewports.
- Real device or browser visual QA is still needed to catch overlap, clipping,
  and hero/list density issues that static analyzer and widget tests cannot
  prove.
