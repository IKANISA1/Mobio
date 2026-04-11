# Mobio UI System

> Version: 2.0
> Last updated: 2026-04-11
> Source of truth: `lib/core/theme/`, `lib/shared/widgets/`

## 1. Product framing

Mobio is an existing production mobility app. The UI system must work additively on top of the current flows, service contracts, routing, and business logic.

Non-negotiable constraints:

- Keep the 3-tab shell and current route structure.
- Preserve the core feature groupings: Home, BioPay, Profile, Nearby, Bookings, Schedule, Trip Details, Chat, Admin.
- Simplify the interface without inventing new product concepts.
- Prefer reusable widgets, chips, cards, segmented controls, badges, and bottom-sheet patterns over explanatory copy.

## 2. Design objective

The Mobio UI should feel:

- clean
- calm
- premium
- fast
- mobile-native
- component-driven
- visually light

The system should remove noise, shorten labels, and make every screen immediately scannable.

## 3. Audit summary

### 3.1 Current friction

The previous system leaned too heavily on:

- large hero text blocks
- repeated headings and subtitles
- glass/clay depth on too many surfaces
- uppercase metadata competing with primary content
- duplicate containers doing the same job
- long empty/error helper copy

### 3.2 Screen-level correction

| Screen | Main clutter | Replace with |
| --- | --- | --- |
| `HomeScreen` | Multiline hero text, repeated section chrome, verbose quick actions | summary card, metric tiles, icon-led action tiles, compact section headers |
| `BioPayScreen` | Repeated descriptive subtitles and heavy header block | one compact product header + 3 action tiles |
| `BookingsScreen` | Oversized page title, all-caps action labels, dense trip cards | compact header, date pills, structured trip card, status badges |
| `ProfileScreen` | Generic settings list, duplicated profile text | member card, badges, feature tiles |
| Shared empty/error states | Too much vertical space and copy | concise title + optional one-line support text + single action |

### 3.3 Systemic rules from the audit

- One primary surface style per screen section.
- One primary action per card.
- One compact caption line is enough in most places.
- Use icons to support recognition, not decoration.
- Use uppercase sparingly. Default to sentence case.

## 4. Design principles

### 4.1 Fewer words

- Titles should usually be 1-2 words.
- Helper text should be optional, not mandatory.
- Empty states should say what happened and what to do next in one short line.

### 4.2 Widget-first structure

Prefer:

- summary cards
- metric tiles
- feature/action tiles
- status badges
- segmented controls
- floating nav
- compact list cards

Avoid:

- free-floating explanatory paragraphs
- stacked headings saying the same thing
- decorative containers with no semantic role

### 4.3 Strong hierarchy

Every screen should clearly separate:

- primary content
- primary action
- secondary metadata
- tertiary support detail

### 4.4 Surface restraint

- Use soft elevation only when it helps orientation.
- Border and spacing should do more work than shadow.
- Keep gradients subtle and localized.

### 4.5 Reuse over novelty

If a pattern appears more than once, it should be a shared widget.

## 5. Design tokens

### 5.1 Token files

- Colors: `lib/core/theme/app_colors.dart`
- Typography: `lib/core/theme/app_typography.dart`
- Shadows: `lib/core/theme/app_shadows.dart`
- Radii: `lib/core/theme/app_radii.dart`
- Spacing: `lib/core/theme/app_spacing.dart`
- Theme wiring: `lib/core/theme/app_theme.dart`

### 5.2 Color direction

Brand:

- Primary stays Mobio green.
- Secondary and tertiary stay muted and semantic.

Neutrals:

- Dark mode uses graphite/charcoal surfaces.
- Light mode uses warm light-gray neutrals rather than flat white everywhere.

Semantic usage:

- `primary`: primary CTA, selection, live state
- `primaryContainer`: brand-tinted surfaces and secure actions
- `secondaryContainer`: filters, transport badges, supporting chips
- `tertiaryContainer`: secondary info accents
- `errorContainer`: destructive status and warnings
- `surfaceContainer*`: all layout and widget surfaces

### 5.3 Typography

Font families:

- Headline/display: Manrope
- Body/labels: Inter

Rules:

- Small controlled scale only.
- Use `displayLg` and `heroNumber` sparingly.
- Most cards should rely on `titleLg`, `titleMd`, `bodySm`, and `labelMd`.
- Sentence case by default.

### 5.4 Spacing

Base grid: 4px

Core tokens:

- `screenPadding = 24`
- `sectionGap = 32`
- `cardGap = 20`
- `compactGap = 12`

### 5.5 Radii

Core tokens:

- `sm = 12`
- `md = 16`
- `lg = 20`
- `xl = 24`
- `xxl = 28`
- `hero = 32`
- `pill = 999`

### 5.6 Elevation

Use:

- subtle surface shadow for cards
- subtle floating shadow for nav and primary buttons

Do not use:

- strong layered shadows on every card
- hard glow effects

### 5.7 Motion

Interaction motion should stay short and quiet:

- press scale: very small
- opacity feedback: subtle
- section entrance: fade/slide only where already present

## 6. Component library

### 6.1 Base surfaces

`ClayCard`

- now functions as the default minimal surface card
- restrained elevation
- medium/large radius
- subtle press feedback

`MobiSurfacePanel`

- used for screen headers and grouped foreground chrome
- one clean readable surface on top of the background

`GlassCard`

- only for persistent floating chrome like bottom navigation
- not for general content cards

### 6.2 Reusable shared widgets

`MobiFeatureTile`

- icon-led horizontal list/action tile
- used for settings, BioPay actions, quick navigation rows

`MobiMetricTile`

- compact stat block
- used inside summary areas

`MobiStatusBadge`

- short metadata chip
- supports `neutral`, `brand`, `positive`, `info`, `warning`, `danger`

`MobiToggle`

- segmented control for binary or short multi-state switching
- sentence-case labels

`MobiButton`

- primary, ghost, danger, success, WhatsApp variants
- stadium shape
- light border, minimal elevation

`MobiBottomNav`

- short labels
- active item shows icon + label
- inactive items show icon only

`AiEmptyState` and `MobiErrorState`

- concise title
- optional one-line explanation
- optional single action

### 6.3 Standard mobile patterns

Use these patterns consistently:

- action tile list for navigational tasks
- badge row for metadata
- summary card for totals and state
- sticky floating action for creation
- bottom sheet for secondary actions and confirmations

## 7. Icon rules

Mobio uses Lucide icons.

Rules:

- Every icon must have a semantic job.
- Default icon sizes:
  - 16 for small metadata
  - 18-20 for compact actions
  - 24 for primary tile icons
- Keep icon containers simple and aligned to the spacing grid.
- Prefer one icon over repeated explanatory labels when the meaning is obvious.
- Avoid mixing icon families.

## 8. Screen guidance

### 8.1 Home

- Keep one compact header panel.
- Use one summary card instead of a multiline hero statement.
- Surface counts through metric tiles, not giant stacked text.
- Use short quick actions.
- Use compact section headers with optional trailing action only.

### 8.2 BioPay

- Keep one clear identity header.
- Show only the 3 primary actions.
- Use product-region metadata as badges.
- Move any long explanation to a secondary layer or support flow.

### 8.3 Bookings

- Header should state scope, not shout.
- Use date pills for grouping.
- Trip cards should show route, time, badges, and one clear action row.
- Avoid all-caps buttons where sentence case works.

### 8.4 Profile

- Member identity first.
- Use badges for status and tenure.
- Settings should be a clean list of feature tiles.
- Theme switch should stay inline and obvious.

### 8.5 Forms and detail screens

- One primary title, one supporting line at most.
- Inputs should rely on shape and spacing, not extra wrapper cards unless necessary.
- Secondary guidance belongs in bottom sheets or inline validation only when needed.

## 9. Navigation guidance

Keep the current navigation architecture.

Guidelines:

- 3 top-level tabs only.
- Use short tab labels.
- Secondary routes push over the root shell.
- Avoid adding new top-level navigation destinations unless product logic changes.
- Prefer contextual entry points from cards and tiles over extra menu layers.

## 10. Incremental rollout plan

### Phase 1

- tokens
- shared surfaces
- buttons
- segmented controls
- nav
- empty/error states

### Phase 2

- Home
- BioPay
- Profile
- Bookings

### Phase 3

- Nearby
- Schedule Trip
- Trip Details
- Edit Profile
- Chat

### Phase 4

- admin screens
- edge-case dialogs
- system overlays

## 11. Implementation checklist

Every new or refactored screen should pass this checklist:

- Is the title shorter?
- Did raw text get replaced by tiles, chips, badges, or stat blocks where appropriate?
- Is there only one primary action visible at a time?
- Are card radii and padding using tokens?
- Are icons Lucide and semantically meaningful?
- Is helper text reduced to the minimum necessary?
- Is the same component reused instead of restyled locally?

## 12. Current reference components

The current minimalist system is implemented first in:

- `lib/features/home/home_screen.dart`
- `lib/features/biopay/biopay_screen.dart`
- `lib/features/profile/profile_screen.dart`
- `lib/features/bookings/bookings_screen.dart`

These screens are the benchmark for future rollouts.
