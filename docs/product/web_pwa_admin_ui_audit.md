# Web, PWA, and Admin UI Audit

Date: 2026-05-01

## Surfaces Inspected

- Flutter web/PWA host: `web/index.html`, `web/manifest.json`.
- App route shell and admin route guards: `lib/core/router`, `lib/app.dart`.
- Embedded platform admin: `lib/features/admin`.
- Shared UI/design system: `lib/shared/widgets`, `lib/core/theme`, `packages/design-system`.
- Boundary folders: `apps/pwa`, `apps/admin`, `apps/website`, `apps/venue-dashboard`, `apps/agent-console`.

No separate React, Next, Vite, Angular, or static website app was found. The web/PWA, admin panel, and operational console currently ship through the Flutter app.

## Findings

- PWA metadata still contained Flutter starter copy and generic blue theme colors.
- The web viewport disabled user scaling, which is not accessibility-safe.
- Admin support escalation used a hardcoded WhatsApp number.
- Admin user and trip tables had search/filter coverage but lacked explicit pagination controls.
- Admin trip moderation lacked local search and operator-controlled sorting.
- Admin fleet and subscription catalog tables lacked search/sort/pagination for larger production catalogs.
- Audit log and finance review existed in backend state, but had no first-class admin pages.
- Shared admin chips and empty states needed stronger semantic metadata for assistive technology.
- Venue dashboard, agent console, and public website folders are boundary placeholders only; they do not contain runnable frontend surfaces yet.

## Refactors Completed

- Replaced generic PWA description/theme metadata with Mobio production metadata.
- Restored browser zoom/user scaling support through a safer viewport declaration.
- Added reusable admin table controls: `AdminSortMenu`, `AdminSortOption`, and `AdminPaginationBar`.
- Added semantics for admin action chips, filter chips, empty states, and user rows.
- Added table pagination and sort state to the admin users workspace.
- Added visible-row bulk selection behavior so page-level selection does not accidentally imply hidden rows.
- Added search, sort, and pagination to the admin trips workspace.
- Added search, sort, status filters, and pagination to fleet and subscription catalog workspaces.
- Added an admin finance review workspace for external USSD reconciliation risk flags. Review actions call the existing `admin-review-transaction` Edge Function and do not create or charge in-app payments.
- Added an admin audit workspace backed by the canonical `admin_audit_log` table through the new `rpc_admin_list_audit_logs` RPC.
- Added Supabase RPC contracts for audit listing and finance risk-flag listing.
- Aligned transaction-review audit writes with the existing `admin_audit_log` table.
- Removed the hardcoded admin support WhatsApp number; support escalation now depends on `--dart-define=ADMIN_SUPPORT_WHATSAPP=...`.

## Permission and Backend Notes

- Admin route access remains client-gated and server-enforced through Supabase RPCs.
- Admin trip cancellation still requires the audited `rpc_admin_cancel_trip` path.
- User role changes still go through `rpc_admin_update_user_role`.
- Broadcast actions still go through admin RPCs and retain confirmation before queueing.
- Finance review actions remain external-payment-only and are server-authorized by `admin-review-transaction`.
- Audit log reads are exposed only through an admin-only security-definer RPC; the underlying canonical table remains service-role-only for direct client access.

## Remaining Risks

- Public website, venue dashboard, and agent console are not implemented as separate runnable frontend apps.
- Campaign/promotion approval still has no finalized backend state machine; the existing broadcast workflow sends through admin RPCs and should not grow a fake approval page until campaign states exist.
- Fleet/subscription pagination is client-side over the loaded catalog. If catalogs exceed hundreds of rows, add counted server pagination RPCs.
- Browser-level accessibility testing with screen readers and keyboard-only navigation should be added before release.
