# Mobio Admin Design System

> Scope: existing production admin panel
> Strategy: additive redesign on top of current routes, permissions, RPCs, and operational workflows
> Primary implementation: `lib/features/admin/widgets/admin_ui.dart`

## 1. Admin objective

The admin should feel:

- calm
- operational
- minimal
- highly structured
- fast to scan
- authoritative
- reusable

This is not a new platform. The redesign must preserve:

- route structure
- role/permission checks
- current admin actions
- moderation flows
- existing service contracts and RPCs

## 2. Audit summary

Current friction observed in the existing admin:

- headers were too verbose and visually large for an operational surface
- stacked panels created too much vertical noise before the real controls
- table rows mixed metadata, actions, and explanations in the same visual weight
- quick actions were duplicated across screens instead of being structured through tabs and local action bars
- mobile layouts often fell back to sentences like `Vehicle: x` instead of reusable chips, badges, and compact metadata widgets
- tabs and screen titles were not always aligned with the actual active module

Primary conversion targets:

- long subtitles -> compact one-line operational summaries
- descriptive rows -> badges, chips, short metadata tokens
- generic panels -> explicit KPI, filter, table, queue, and audit surfaces
- stacked action noise -> short action chips and contextual toolbars

## 3. Core principles

### 3.1 Fewer words

- Use short nouns for titles.
- Keep subtitles to one line whenever possible.
- Prefer labels like `Active`, `Paused`, `Blocked`, `Seen`, `New`, `Trips`, `Plans`.

### 3.2 Widget-first structure

Default admin building blocks:

- KPI cards
- filter bars
- searchable toolbars
- table shells
- status badges
- role chips
- bulk action bars
- activity rows
- audit rows
- detail sheets

### 3.3 Operational hierarchy

Every screen should answer, in order:

1. What matters now?
2. What can I filter?
3. Which rows need action?
4. What is the next obvious action?

### 3.4 Reuse over screen-specific styling

If a pattern appears twice, it should come from shared admin primitives before adding more screen-local layout code.

## 4. Admin tokens

### 4.1 Layout

Source: `lib/features/admin/widgets/admin_ui.dart`

- `AdminLayoutTokens.maxContentWidth = 1360`
- `AdminLayoutTokens.headerRadius = 30`
- `AdminLayoutTokens.panelRadius = 24`
- `AdminLayoutTokens.pagePadding = EdgeInsets.fromLTRB(24, 8, 24, 160)`
- `AdminLayoutTokens.overlayPagePadding = EdgeInsets.fromLTRB(24, 8, 24, 40)`

### 4.2 Spacing

Source: `packages/design-system/lib/src/theme/app_spacing.dart`

- `xs = 8`
- `sm = 12`
- `md = 16`
- `lg = 20`
- `xl = 24`
- `sectionGap = 32`

### 4.3 Radius

Source: `packages/design-system/lib/src/theme/app_radii.dart`

- standard panel radius: `24`
- header radius: `30`
- pill radius: `999`

### 4.4 Typography

Source: `packages/design-system/lib/src/theme/app_typography.dart`

- page title: `headlineLg`
- section title: `titleLg`
- metric value: `headlineLg`
- body support copy: `bodySm`
- chips, table labels, dense metadata: `labelMd` / `labelSm`

Typography rules:

- sentence case only
- avoid all-caps metadata except where inherited from core badge components
- numbers should visually outrank labels
- section subtitles should never compete with table data

## 5. Component library

### 5.1 Shared primitives

Implemented in `lib/features/admin/widgets/admin_ui.dart`:

- `AdminWorkspaceFrame`
- `AdminPanel`
- `AdminSectionHeader`
- `AdminMetricCard`
- `AdminSearchField`
- `AdminFilterChip`
- `AdminActionChip`
- `AdminEmptyState`
- `AdminSortMenu`
- `AdminPaginationBar`
- `AdminFieldPair`
- `AdminTableLabel`

### 5.2 Admin usage rules

- `AdminWorkspaceFrame`: page shell, title, compact summary, top-level actions, module tabs
- `AdminPanel`: the default admin surface; avoid stacking nested decorative containers inside it
- `AdminMetricCard`: short KPI only; one number, one icon, one short support line
- `AdminSearchField`: one search input per screen; place beside filters when width allows
- `AdminFilterChip`: use for scope, role, status, market, and queue filtering
- `AdminActionChip`: use for local actions, quick jumps, bulk changes, and row actions
- `AdminSortMenu`: expose operator-controlled ordering for tables and queues
- `AdminPaginationBar`: keep large result sets scannable and avoid implying hidden rows are selected
- `AdminTableLabel`: use for table headers only

### 5.3 Screen-local reusable patterns

Implemented in screen files:

- dashboard priority tiles
- audit rows
- allowlist rows
- mobile row metadata chips on users
- trip override rows

These should remain local until two or more modules need the same pattern.

## 6. Table system rules

- Keep table headers short.
- Lead with identity, then status, then action.
- Use badges for role and state.
- Use chips for compact metadata on mobile.
- Use row tap to open detail sheet; keep destructive actions explicit.
- Keep bulk actions separate from row actions.
- Reserve the far-right column for override/edit actions only.

Recommended column priority:

- identity
- status
- type / role
- operational metadata
- action

## 7. Icon and status rules

- icons support recognition, never decoration
- one icon per action chip is enough
- use consistent icons for the same concept across screens

Status mapping:

- `brand`: admin-owned, primary operational actions
- `positive`: active, healthy, resolved, complete
- `info`: informational types, fleet, drivers, system actions
- `warning`: paused, pending, degraded
- `danger`: blocked, destructive, override, failure
- `neutral`: passive metadata, quiet state

## 8. Screen guidance

### 8.1 Dashboard

Use four layers only:

1. KPI strip
2. priority rail
3. alerts and access activity
4. allowlist / supporting control surface

Do not add long explanatory content or non-essential charts.

### 8.2 Users

The users screen should prioritize:

- search
- role filter
- bulk role changes
- live state badges
- quick detail access

Secondary user details belong in the bottom sheet, not the table.

### 8.3 Trips / moderation / queues

The trips feed should read like a queue:

- filtered feed at the top
- visible count and active count
- route + author + state in one scan line
- explicit override column

### 8.4 Fleet and plans

These are operational catalog screens, not content screens:

- concise market/status filters
- KPI summary first
- tables second
- edit / enable / rollout actions only

### 8.5 Broadcasts

Broadcasting is high-risk:

- keep type selection clear
- keep the composer sparse
- keep confirmation explicit
- do not surround the send action with excess copy

## 9. Navigation guidance

Top-level admin tabs should stay small and obvious:

- Ops
- Users
- Fleet
- Plans
- Trips
- Broadcasts
- Account

Navigation rules:

- critical daily operations belong in tabs or header actions
- lower-frequency actions stay inside local panels
- do not duplicate navigation inside every panel
- in-shell admin screens keep the compact admin bottom nav
- pushed admin screens use the same header shell but reduced bottom padding

## 10. Incremental rollout plan

### Phase 1

- standardize shared admin primitives
- update dashboard, users, trips, broadcasts
- align tabs, paddings, titles, action hierarchy

### Phase 2

- migrate subscriptions and fleet screens to the same table shell density
- convert remaining mobile metadata lines into chips/badges
- normalize sheet layouts and confirmation dialogs

### Phase 3

- add dedicated audit timeline widgets where repeated
- add shared bulk action bar if more admin modules require selection workflows
- extract any repeated queue/list row pattern into shared widgets

## 11. Definition of done

An admin screen is complete when:

- the next action is obvious
- statuses are visible without reading paragraphs
- tables are scannable in under a few seconds
- actions are short, explicit, and non-competing
- secondary detail is hidden behind detail sheets or secondary panels
- the screen still preserves the existing production workflow
