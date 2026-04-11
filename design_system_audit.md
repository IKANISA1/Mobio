# Mobio Minimalist UI Audit

> Audit date: 2026-04-11
> Reference system: `design.md`

## Executive summary

The production app already had a reusable UI layer, but the previous visual language was too heavy for a minimalist product direction. The biggest issues were not missing components. They were over-expressive surfaces, oversized text blocks, repeated labels, and too many places where copy was doing the work that structure should do.

This audit shifts the app toward:

- shorter labels
- calmer surfaces
- stronger hierarchy
- more status chips and icon-led tiles
- fewer decorative containers

## High-priority text reduction opportunities

### Home

Problems:

- giant multiline hero text
- repeated section titles and helper copy
- quick actions explained with too many words

Replace with:

- summary card with count + metric tiles
- compact section headers
- short quick action tiles

### BioPay

Problems:

- verbose action subtitles
- oversized branded header doing too little
- region availability explained too heavily

Replace with:

- one compact identity header
- short action tiles
- badges for brand and region

### Bookings

Problems:

- oversized page headline
- all-caps labels in too many places
- dense trip cards with duplicated hierarchy

Replace with:

- compact header panel
- date pills
- structured trip cards
- concise sentence-case actions

### Profile

Problems:

- profile info as plain text instead of a recognizable member block
- settings rows without enough semantic distinction

Replace with:

- member summary card
- status badges
- reusable feature tiles

## Cross-screen issues

### 1. Too many surface styles

The app mixed glass, clay, gradient blocks, and raw containers too freely. The redesign standardizes around:

- `ClayCard` for content
- `MobiSurfacePanel` for header/group chrome
- `GlassCard` only for floating chrome

### 2. Too much uppercase

Uppercase is now reserved for exceptional metadata only. Primary actions and labels should use sentence case unless a regulated or system constraint requires otherwise.

### 3. Icons were present but under-leveraged

Icons existed, but many screens still relied on explanatory text. The redesign uses icon-led:

- action tiles
- status badges
- metric tiles
- bottom navigation

### 4. Repeated helper copy

Common phrases such as “pull down to refresh,” “tap nearby,” and repeated route descriptions were contributing noise. Most support text now compresses to one line or disappears entirely when the widget itself provides enough context.

## Implemented remediation

### Updated token layer

- `app_colors.dart`
- `app_typography.dart`
- `app_shadows.dart`
- `app_radii.dart`
- `app_spacing.dart`
- `app_theme.dart`

### Updated shared widget layer

- `ClayCard`
- `GlassCard`
- `MobiSurfacePanel`
- `MobiButton`
- `MobiToggle`
- `MobiBottomNav`
- `AiEmptyState`
- `MobiErrorState`
- `VehicleFilterChips`
- `DriverCard`
- new `MobiFeatureTile`
- new `MobiMetricTile`
- new `MobiStatusBadge`
- new `MobiSectionHeader`

### Updated feature screens

- `HomeScreen`
- `BioPayScreen`
- `ProfileScreen`
- `BookingsScreen`

## Remaining rollout targets

The next screens to normalize against the system are:

- `NearbyScreen`
- `ScheduleTripScreen`
- `TripDetailsScreen`
- `EditProfileScreen`
- `ChatScreen`
- admin screens that still carry legacy density

## Acceptance criteria for future UI work

Before shipping a UI change, confirm:

- The screen uses tokenized spacing and radii.
- Repeated metadata is in badges or compact tiles.
- There is no large text block that could be broken into widgets.
- There is one visually dominant action.
- The screen does not introduce a new card style unless it becomes shared.
