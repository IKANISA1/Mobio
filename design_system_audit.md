# Mobio Minimalist UI Audit

> Audit date: 2026-04-17
> Reference system: `design.md`

## Executive summary

Mobio already had a reusable UI foundation, but the production app still carried too much instructional copy, too many mixed card treatments, and several screens where hierarchy was being explained with words instead of built with structure.

The current redesign pass focuses on one rule:

- less text
- more widgets
- shorter decisions
- cleaner hierarchy
- calmer surfaces

## Current high-value findings

### Home

Findings:

- quick actions were still using full tiles with explanatory subtitles
- section captions repeated what the layout already implied
- empty states were still spending text on guidance that could be an action

Applied:

- quick actions converted to icon-led compact action tiles
- section captions shortened to state/count language
- scheduled empty state now exposes a direct `Schedule` action instead of helper copy

### BioPay

Findings:

- action tiles were repeating the same brand context in every subtitle
- unavailable-state messaging was a one-off card instead of a reusable pattern

Applied:

- action titles shortened to `Show QR`, `Scan QR`, `Face pay`
- brand and country remain in badges in the header
- unavailable state moved to reusable `MobiStateBanner`

### Bookings

Findings:

- the header still used a descriptive subtitle below the title
- empty/error states relied on “pull to retry” style helper copy
- trip cards used text-heavy route/time hierarchy instead of chip-led metadata
- cancellation was still using a local ad-hoc dialog

Applied:

- removed redundant header subtitle
- empty states now use direct actions: `Schedule` or `Refresh`
- time moved into an inline chip alongside status badges
- trip route casing normalized for a calmer premium look
- cancel flow now uses shared `MobiConfirmDialog`

### Profile

Findings:

- settings rows still needed subtitles to explain obvious actions
- Face ID was still described with helper copy instead of state

Applied:

- settings tiles switched to terse single-line rows
- Face ID now uses a `BioPay` badge instead of a descriptive subtitle

### Nearby

Findings:

- location permission prompt was implemented as bespoke UI
- retry copy remained verbose for a repeated pattern

Applied:

- location prompt moved to reusable `MobiStateBanner`
- error state now relies on the retry control instead of helper text

### Chat

Findings:

- the header subtitle was still sentence-driven

Applied:

- subtitle reduced to route or short inbox context only

### Admin workspace

Findings:

- admin chrome was still too loud compared with the passenger app

Applied:

- title scale reduced
- subtitle tone softened
- `ADMIN` badge normalized to `Admin`

## Reusable system decisions

### Shared surfaces

- `ClayCard` is the default content surface
- `MobiSurfacePanel` is the readable header/group surface
- `GlassCard` is reserved for floating chrome only

### Shared widget patterns

- `MobiActionRow` for quick, low-friction task entry
- `MobiFeatureTile` for navigational or settings rows
- `MobiMetricTile` for summary counts
- `MobiStatusBadge` and `MobiInfoChip` for metadata
- `MobiStateBanner` for inline state and permission messaging
- `AiEmptyState` and `MobiErrorState` for terminal states

### Text reduction rules

- if the icon, chip, or badge already communicates the state, remove the subtitle
- if the empty state can expose a direct action, remove helper copy
- if a card already has route + status, avoid a second descriptive sentence

## Remaining rollout targets

The main passenger flows now follow the updated system more consistently. Remaining cleanup should happen incrementally in:

- form helper/error copy in `ScheduleTripScreen` and `EditProfileScreen`
- verbose admin secondary descriptions where the section title already implies context
- snackbars and ephemeral feedback strings that still read like developer messages

## Acceptance criteria for future UI work

Before shipping a UI change, confirm:

- the screen uses tokenized spacing, radii, and typography
- repeated metadata is expressed as chips, badges, or tiles
- helper copy has been removed unless it changes user success
- only one surface language is dominant within a section
- any new pattern is shared, named, and reusable
