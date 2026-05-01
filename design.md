# Mobio UI System

> Version: 2.2
> Last updated: 2026-04-17
> Source of truth: `lib/core/theme/`, `lib/shared/widgets/`

## 1. Product framing

Mobio is an existing production mobility app. The system must refine the current product, not replace it.

Non-negotiable constraints:

- keep the 3-tab shell and current route structure
- preserve the current core flows: Home, BioPay, Profile, Nearby, Bookings, Schedule, Trip Details, Chat, Admin
- work additively on top of current business logic and data contracts
- make screens lighter and faster without inventing new product concepts

## 2. Core design principles

- fewer words
- fewer competing actions
- more meaning through widgets
- stronger hierarchy through spacing and grouping
- one reusable pattern for each repeated job
- sentence case by default
- calm surfaces over decorative depth

Practical rule:

- if a badge, chip, icon, or tile can communicate the state, remove the sentence

## 3. Audit summary

The main UI problems were:

- explanatory subtitles on obvious actions
- mixed surface styles within the same screen
- headers that described scope instead of simply showing it
- empty/error states that relied on helper copy instead of direct actions
- route and status information expressed as raw text instead of chips and badges

## 4. Design tokens

### 4.1 Token files

- colors: `lib/core/theme/app_colors.dart`
- typography: `lib/core/theme/app_typography.dart`
- spacing: `lib/core/theme/app_spacing.dart`
- radii: `lib/core/theme/app_radii.dart`
- shadows: `lib/core/theme/app_shadows.dart`
- theme wiring: `lib/core/theme/app_theme.dart`

### 4.2 Color direction

Brand:

- primary remains Mobio green
- secondary and tertiary stay muted and functional

Neutrals:

- dark mode uses graphite and charcoal surfaces
- light mode uses soft warm neutrals instead of flat white everywhere

Semantic usage:

- `primary`: selection, CTA, live state
- `primaryContainer`: secure and brand-tinted surfaces
- `secondaryContainer`: supporting info and neutral transport metadata
- `tertiaryContainer`: secondary highlight surfaces
- `errorContainer`: destructive or warning states
- `surfaceContainer*`: general layout surfaces and cards

### 4.3 Typography rules

Families:

- Manrope for headlines
- Inter for body and labels

Rules:

- keep the scale tight
- reserve `display*` and `heroNumber` for rare moments
- default to `titleLg`, `titleMd`, `bodySm`, `labelMd`
- keep titles short
- avoid paragraph-style support text unless it directly prevents user failure

### 4.4 Spacing rules

Grid: 4px

Core tokens:

- `screenPadding = 24`
- `sectionGap = 32`
- `cardGap = 20`
- `compactGap = 12`

Spacing usage:

- use padding and grouping to create hierarchy before adding labels
- keep repeated list items visually rhythmic
- separate sections with space, not decorative dividers

### 4.5 Radii rules

Core tokens:

- `sm = 12`
- `md = 16`
- `lg = 20`
- `xl = 24`
- `xxl = 28`
- `hero = 32`
- `pill = 999`

Usage:

- `hero` for major cards and headers
- `xl` and `xxl` for standard cards
- `pill` for badges, chips, toggles, and compact actions

### 4.6 Elevation rules

- use subtle elevation only when it helps orientation
- prefer borders and surface contrast over strong shadows
- keep floating chrome distinct from content chrome

## 5. Component library

### 5.1 Base surfaces

`ClayCard`

- default content surface
- restrained elevation
- subtle press feedback

`MobiSurfacePanel`

- readable header and grouping surface
- use when content must sit clearly above the background layer

`GlassCard`

- floating chrome only
- bottom navigation and persistent overlay treatment

### 5.2 Reusable components

`MobiPageHeader`

- pushed-screen header
- compact title, optional subtitle, optional trailing action

`MobiActionRow`

- 2-4 icon-led quick actions
- use when actions should feel lighter than full tiles

`MobiFeatureTile`

- icon-led navigation or settings row
- use optional subtitle only when it changes user success

`MobiMetricTile`

- compact stat tile for counts and summary metrics

`MobiStatusBadge`

- strong semantic badge
- use for state, identity, and mode

`MobiInfoChip`

- lighter inline metadata chip
- use for time, date, compact route metadata, and filters

`MobiStateBanner`

- inline status, permission, or availability banner
- replaces bespoke notice cards

`MobiToggle`

- segmented control for short state switching

`MobiButton`

- primary, ghost, danger, success, WhatsApp
- minimal fill, subtle shadow, restrained typography

`AiEmptyState` and `MobiErrorState`

- concise title
- optional one-line support text
- direct action when one exists

### 5.3 Reusable widget patterns

Prefer these patterns:

- summary card + metric tiles
- compact quick-action strip
- badge row under primary content
- terse settings list
- sticky primary action
- bottom sheet for secondary actions
- inline state banner for permission/availability issues

Avoid:

- free-floating helper paragraphs
- stacked titles plus subtitles that repeat each other
- one-off banners and dialogs when a shared pattern already exists

## 6. Icon usage rules

Mobio uses Lucide icons.

Rules:

- every icon must communicate action, category, or state
- no decorative icons without a semantic job
- standard sizes:
  - `12-14` for micro metadata
  - `16-20` for compact controls and chips
  - `22-24` for primary action tiles
- keep icon containers aligned to the spacing grid
- never mix icon families inside the same system

## 7. Screen-level redesign guidance

### 7.1 Home

- one compact header panel
- one summary card for live state
- one quick-action strip
- compact sections with count-led captions
- empty states should expose direct actions when possible

### 7.2 BioPay

- one identity header with brand and region badges
- only the 3 primary actions visible
- no repeated brand subtitles inside every action tile
- use state banners for availability constraints

### 7.3 Bookings

- header should show scope, not explain it
- use date pills and metadata chips
- route should be primary, time/status should be structured metadata
- use shared confirm patterns for destructive actions

### 7.4 Profile

- member identity first
- use badges for trust and tenure
- settings should read as a terse list, not a paragraph list
- inline controls should replace explanatory subtitles

### 7.5 Nearby

- location and permission issues belong in a reusable banner
- filters stay compact and horizontal
- browsing content should stay list-first

### 7.6 Chat

- header context should be a route or short mode label only
- conversation chrome stays minimal so the thread remains primary

### 7.7 Admin

- keep the same information architecture
- reduce headline intensity to match the core app
- use the same chip and spacing language as passenger screens

## 8. Navigation simplification guidance

Keep the current navigation architecture.

Rules:

- 3 top-level tabs only
- use short labels and icon-led scanning
- push secondary flows over the shell
- prefer contextual entry points from cards, tiles, and FABs
- do not add new top-level destinations unless the product model changes

## 9. Incremental implementation guidance

Roll out in this order:

1. tokens and shared surfaces
2. shared action, tile, badge, empty, and banner components
3. top-traffic passenger screens
4. forms and detail screens
5. admin workspace alignment
6. snackbars, dialogs, and remaining edge states

When touching an existing screen:

1. remove repeated headings and subtitles first
2. collapse repeated metadata into chips or badges
3. replace one-off notice UI with shared banners or empty states
4. normalize padding, radii, and icon sizing
5. only then consider deeper layout changes

## 10. Implementation checklist

Every new or refactored screen should pass this checklist:

- is the title shorter and clearer?
- did raw text become tiles, chips, badges, or stat blocks where appropriate?
- is there a single primary action?
- are surfaces consistent inside the section?
- are icons Lucide and semantically meaningful?
- is helper text only present when it materially improves success?
- is the pattern shared instead of restyled locally?

## 11. Reference screens

The current benchmark screens for the minimalist system are:

- `lib/features/home/home_screen.dart`
- `lib/features/biopay/biopay_screen.dart`
- `lib/features/bookings/bookings_screen.dart`
- `lib/features/profile/profile_screen.dart`
- `lib/features/nearby/nearby_screen.dart`
- `lib/features/chat/chat_screen.dart`
- `lib/features/admin/widgets/admin_ui.dart`
