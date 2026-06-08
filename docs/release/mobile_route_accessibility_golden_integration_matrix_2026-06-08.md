# Mobio Mobile Route Accessibility, Golden, Integration, and Evidence Matrix

Date: 2026-06-08

Scope: current Flutter mobile route surface after scheduled-trip edit, permission onboarding, shared moderation sheets, admin detail drill-ins, and adaptive shell work.

## Evidence Legend

- Accessibility: semantics labels, button roles, tap target sizing, focus path, large-text resilience, and no color-only state.
- Golden: compact phone, large phone, tablet width, dark mode, empty/loading/error/disabled states where applicable.
- Integration: route opens, critical happy path, failure/permission path, auth/admin guard behavior where applicable.
- Android evidence: analyze/test/build/smoke output and screenshots captured under `docs/release/evidence/`.
- iOS evidence: analyze/test/build/smoke output and screenshots captured under `docs/release/evidence/`.

## Current Route Matrix

| Route | Surface | Accessibility | Golden | Integration | Android evidence | iOS evidence | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `/config-error` | Configuration error gate | Required | Required | Required | Pending capture | Pending capture | Must stay reachable when public Supabase defines are missing. |
| `/login` | WhatsApp OTP login | Required | Required | Required | Pending capture | Pending capture | Includes redirect preservation and admin OTP handoff. |
| `/` | Discover/home shell | Required | Required | Required | Pending capture | Pending capture | Bottom nav on compact widths, navigation rail at tablet widths. |
| `/nearby` | Nearby driver/passenger discovery | Required | Required | Required | Pending capture | Pending capture | Location permission education now precedes OS prompt/retry. |
| `/bookings` | Scheduled trip list | Required | Required | Required | Pending capture | Pending capture | Empty/loading/error and trip post cards are in scope. |
| `/schedule` | Create scheduled trip post | Required | Required | Required | Pending capture | Pending capture | Location education and submit validation required. |
| `/trip/:id` | Trip post details | Required | Required | Required | Pending capture | Pending capture | Owner-only edit entry is required. |
| `/trip/:id/edit` | Edit scheduled trip post | Required | Required | Required | Pending capture | Pending capture | Edit mode must prefill route/time/role/vehicle/note and save via owner-scoped update. |
| `/chat` | Trip chat | Required | Required | Required | Pending capture | Pending capture | Report sheet and block confirmation use shared Mobio modal surfaces. |
| `/profile` | Profile and consent | Required | Required | Required | Pending capture | Pending capture | Notification permission education required before promotional push enablement. |
| `/profile/setup` | First-run profile completion wizard | Required | Required | Required | Pending capture | Pending capture | Dedicated setup route using profile contact, notification, driver, vehicle, and save sections. |
| `/edit-profile` | Edit profile | Required | Required | Required | Pending capture | Pending capture | Standard profile update route. First-run setup uses `/profile/setup`. |
| `/admin-auth` | Admin OTP login | Required | Required | Required | Pending capture | Pending capture | Admin guard redirects here for unauthenticated admin access. |
| `/admin` | Admin dashboard | Required | Required | Required | Pending capture | Pending capture | Operational overview. |
| `/admin/users` | Admin users | Required | Required | Required | Pending capture | Pending capture | User sheet/detail workflow remains required. |
| `/admin/profile` | Admin profile alias | Required | Required | Required | Pending capture | Pending capture | Same profile screen under admin shell route. |
| `/admin/vehicle-types` | Admin fleet | Required | Required | Required | Pending capture | Pending capture | Vehicle type management. |
| `/admin/subscriptions` | Admin subscriptions/plans | Required | Required | Required | Pending capture | Pending capture | Plan management surface. |
| `/admin/trips` | Admin trip posts | Required | Required | Required | Pending capture | Pending capture | Scheduled trip post ops only, no completed ride lifecycle. |
| `/admin/reports` | Admin report moderation | Required | Required | Required | Pending capture | Pending capture | Report detail sheet, review sheet, resolve/dismiss actions. |
| `/admin/finance` | Scope-unavailable legacy finance route | Required | Required | Required | Pending capture | Pending capture | Intentionally inactive boundary route. |
| `/admin/health` | Admin operational health | Required | Required | Required | Pending capture | Pending capture | Operational event detail handling required. |
| `/admin/audit` | Admin audit log | Required | Required | Required | Pending capture | Pending capture | Audit detail sheet with selectable payload. |
| `/admin/broadcasts` | Admin broadcasts | Required | Required | Required | Pending capture | Pending capture | Broadcast compose/list states. |
| `/ledger` | Scope-unavailable legacy ledger route | Required | Required | Required | Pending capture | Pending capture | Intentionally inactive boundary route. |
| `/biopay` | Scope-unavailable legacy BioPay route | Required | Required | Required | Pending capture | Pending capture | Intentionally inactive boundary route. |
| `/biopay/qr` | Scope-unavailable legacy QR route | Required | Required | Required | Pending capture | Pending capture | Intentionally inactive boundary route. |
| `/biopay/scan` | Scope-unavailable legacy scan route | Required | Required | Required | Pending capture | Pending capture | Intentionally inactive boundary route. |
| `/biopay/face-scan` | Scope-unavailable legacy face scan route | Required | Required | Required | Pending capture | Pending capture | Intentionally inactive boundary route. |
| `/biopay/enroll` | Scope-unavailable legacy enroll route | Required | Required | Required | Pending capture | Pending capture | Intentionally inactive boundary route. |

## Popups, Sheets, and Wizards

| Surface | Accessibility | Golden | Integration | Android evidence | iOS evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Location permission education dialog | Required | Required | Required | Pending capture | Pending capture | Implemented in nearby discovery and route picker. |
| Notification permission education dialog | Required | Required | Required | Pending capture | Pending capture | Implemented in profile notification consent. |
| Chat report sheet | Required | Required | Required | Pending capture | Pending capture | Implemented with category chips and details input. |
| Chat block/unblock confirmation | Required | Required | Required | Pending capture | Pending capture | Implemented with shared confirmation dialog. |
| Admin report review sheet | Required | Required | Required | Pending capture | Pending capture | Implemented with resolution notes. |
| Admin report detail sheet | Required | Required | Required | Pending capture | Pending capture | Implemented with full IDs/details/resolution notes. |
| Admin audit detail sheet | Required | Required | Required | Pending capture | Pending capture | Implemented with full selectable JSON payload. |
| First-run profile completion wizard | Required | Required | Required | Pending capture | Pending capture | Implemented at `/profile/setup` with setup-specific copy and shared save logic. |
| Adaptive tablet/large-screen shell | Required | Required | Required | Pending capture | Pending capture | Implemented with navigation rail at `>=720` logical pixels. |

## Final Evidence Gate

Completion requires current artifacts for:

1. `dart analyze`.
2. Focused and full Flutter test pass, including `test/release/mobile_readiness_contract_test.dart`.
3. Android debug/profile or release build plus screenshot/smoke evidence.
4. iOS simulator or archive build plus screenshot/smoke evidence.
5. Screenshot set for compact phone, large phone, and tablet widths covering routes and modal states above.
