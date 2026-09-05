# Mobio admin design system

Updated 5 September 2026. The current cross-product contract is [design.md](../../design.md), with source scope and comparison evidence in [the implementation report](../design/reimplementation-20260905.md).

The implementation lives in `lib/features/admin/presentation/widgets/admin_ui.dart`. Existing routes, roles, RPCs, filters, moderation actions, confirmations, audit events and recovery remain authoritative.

## Layout

At widths of at least 1000 logical pixels, a 216-wide sidebar contains all 13 modules. The workspace owns its sidebar; the app shell must not duplicate it. Content is constrained to 1360 with a compact title and local action area. Below 1000, horizontal module tabs support the complete workspace. Mobile retains its existing four-branch shell.

Panels use a flat neutral fill and radius 16. Headers are 30 at wide sizes with 600 weight. Dense values and labels avoid excessively bold hierarchy. Shared status chips distinguish selected, pending, success and error states; text remains meaningful without relying on colour alone. Search, filters, rows and details remain the primary working area.

## Interaction

Use Material-backed interactive rows for visible selected ink and keyboard focus. Keep touch targets at least 48 where practical, support long/enlarged labels, and keep bulk actions and destructive confirmation states explicit. Tables scroll or convert to existing mobile cards; never hide an action because its desktop columns do not fit. Loading, empty, failed and permission-denied states retain retry or recovery paths.

## Evidence boundary

Official Business promotional imagery informs tonal panels and hierarchy. The sidebar breakpoint, module taxonomy and table layouts are Mobio adaptations, not verified source dimensions. The capture suite exercises the real admin presentation and synthetic service fixtures; no screenshot proves authorization or successful backend mutation. Functional and authorization contract tests provide separate evidence.
