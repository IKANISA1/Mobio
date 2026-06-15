# Admin Panel Audit - 2026-06-15

## Scope

Admin auth, allowlists/OTP, reports/blocks, subscriptions, transport/catalog management, BioPay ops, notifications, operational health, deployment/PWA proof, and privilege boundaries.

## Worklist

| Area | Source paths | Required evidence | Status |
| --- | --- | --- | --- |
| Admin auth/session guard | `lib/features/admin/admin_auth_screen.dart`, `lib/core/auth/admin_session_guard.dart`, router guards | Allowlist/OTP denial and success paths, stale session behavior | Pending |
| Users workspace | `lib/features/admin/admin_users_screen.dart`, providers | Pagination/search/error/permission denial | Pending |
| Reports/blocks | `admin_reports_screen.dart`, report/block services/RPCs | Moderation actions, audit trail, denied access | Contract-covered, screen audit pending |
| Subscriptions | `admin_subscriptions_screen.dart`, subscription RPCs | Plan CRUD validation and audited writes | Contract-covered, screen audit pending |
| Vehicle/transport catalog | `admin_vehicle_types_screen.dart`, `admin_transport_agencies_screen.dart` | Catalog writes behind RPCs, empty/error states | Contract-covered, screen audit pending |
| BioPay ops | `biopay_admin_console_screen.dart` | External confirmation, audit events, denied access | Contract-covered, screen audit pending |
| Notifications/broadcasts | `admin_broadcasts_screen.dart`, `send-push` | FCM fanout, failure states, audit | Contract-covered, screen audit pending |
| Operational health/audit | `admin_operational_health_screen.dart`, `admin_audit_log_screen.dart` | Health event visibility, search/paging, denial | Contract-covered, screen audit pending |
| PWA deployment | `scripts/web/*`, Cloudflare docs/evidence | Build, headers, redirects, browser proof | Passed bundle verification |

## Current Open Items

- Historical admin client-side row caps/pagination risk is now narrowed. Users, reports, audit logs, and operational health now fetch `rowsPerPage + 1` with backend `offset`, and pass search/filter parameters to the RPCs where supported. `admin_trips_screen.dart` still uses a capped feed because `rpc_admin_list_trips` does not currently support global text search; changing that UI to server page only would make trip search misleading.
- Refresh admin PWA/web proof after current code changes.

## Evidence Added This Phase

- `./scripts/web/prepare_pwa_bundles.sh` passed and produced `build/pwa/site`.
- `./scripts/web/verify_pwa_bundles.sh build/pwa` passed.
- `./scripts/web/verify_public_site.sh` passed.

## Findings

| ID | Severity | Finding | Status | Next action |
| --- | --- | --- | --- | --- |
| ADM-001 | Medium risk | Admin users, reports, audit logs, and operational health now use backend pagination. Trips still needs search-capable backend pagination before the capped local feed can be safely removed. | Partially fixed | Add `p_search` support to `rpc_admin_list_trips`, update `AdminTripService.listTrips`, and convert `admin_trips_screen.dart` to backend pagination. |
| ADM-002 | Fixed | Admin/PWA bundle generation and static verification had not been refreshed after the current audit batch. | Fixed | Keep `prepare_pwa_bundles.sh` and `verify_pwa_bundles.sh` in release gate evidence. |
