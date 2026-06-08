# Supabase Backend Security Audit - 2026-05-01

> Historical snapshot: this audit predates the 2026-05-24 Mobio
> limited-scope cleanup. Treat BioPay, payment, SMS ledger, finance-review, and
> ride-request lifecycle references below as historical findings only. Current
> scope and release status are tracked in `docs/product/scope.md`,
> `docs/architecture/schema_inventory.md`,
> `docs/reports/production-readiness-audit.md`, and
> `docs/release/go-no-go.md`.

## Scope Inspected

- Migrations under `supabase/migrations`.
- Edge Functions under `supabase/functions`.
- RLS policies for profiles, trips, driver locations, payment sessions, payment intents, payment events, risk flags, chat, admin audit logs, catalog, entitlements, saved places, and intelligence tables.
- Flutter callers for profiles, trips, driver locations, ledger sync, BioPay profile management, and admin finance review.

## Entity Map

- Identity: `profiles`, WhatsApp OTP tables, admin WhatsApp allowlist tables.
- Mobility: `trips`, `driver_locations`, vehicle type catalog, trip entitlement usage, saved places, demand/pool suggestion tables and RPCs.
- Messaging: `chat_conversations`, `chat_messages`.
- External payment review: `transactions`, `payment_intents`, `payment_events`, `risk_flags`, `admin_audit_log`, QR/NFC instruction session tables.
- Legacy BioPay wallet tables: `biopay_wallets`, `biopay_transactions`; retained for history but client transfer RPCs are disabled.
- Operations: admin list RPCs, audit-log RPCs, risk-flag review Edge Function, SMS reconciliation Edge Function.

## Findings

- P0: Legacy BioPay wallet RPCs still implemented in-app QR generation and scan-and-charge transfers, conflicting with the product rule that payments are external USSD/manual confirmation only.
- P1: `profiles_select_authenticated` exposed full profile rows, including contact/payment handle fields, to every authenticated user.
- P1: `trips_select_active_public` allowed anonymous active-trip reads after WhatsApp login became mandatory.
- P1: `driver_locations` had broad online-driver reads and a `FOR ALL` owner policy without explicit insert/update/delete separation or driver-role checks.
- P1: `payment_intents` and `payment_events` allowed client inserts; payment events did not consistently carry source, amount, currency, method, or metadata.
- P2: QR/NFC payment-session tables still needed explicit grant hardening so scan flows rely on resolver RPCs instead of direct table reads.
- P2: Finance Edge Functions used legacy `completed`/`failed` states instead of explicit external/manual statuses.

## Implemented

- Added `20260501080000_backend_security_payment_rls_hardening.sql`.
- Added `20260501090000_tenant_permissions_storage_realtime_hardening.sql`.
- Added `20260501100000_admin_whatsapp_permission_rpc_fix.sql`.
- Replaced full-table profile peer reads with `rpc_get_public_profile(uuid)`.
- Removed anonymous trip directory reads.
- Rebuilt driver-location policies for authenticated reads and driver/admin writes.
- Expanded payment status constraints for external USSD/manual-review states.
- Added payment-event provenance columns and constraints.
- Removed client write grants/policies from payment intents/events.
- Disabled legacy BioPay wallet transfer RPC execution for clients.
- Added `organizations`, `organization_members`, `platform_permissions`, and
  `profile_platform_permissions` as the tenant/permission foundation.
- Backfilled a legacy default tenant and added nullable `organization_id` keys
  across high-risk operational tables without breaking existing app writes.
- Recreated active admin RPCs to use `has_platform_permission(...)` instead of
  direct `role = 'admin'` checks.
- Replaced the remaining admin WhatsApp list RPC role check with
  `has_platform_permission('admin.whatsapp.manage')`.
- Hardened storage policies for avatar ownership and promo media service-role
  writes, with bucket MIME/size constraints.
- Removed payment/session tables from `supabase_realtime`; direct realtime
  remains for chat, driver locations, and ledger transactions where the app has
  active subscriptions.
- Updated `reconcile-momo-sms` to mark verified external SMS matches as `paid` and mismatches as `manual_review_required`.
- Updated `admin-review-transaction` to mark approved risk reviews as `manually_confirmed` and rejected reviews as `disputed`.
- Added `supabase/tests/backend_security_assertions.sql`.

## Verification

Run after applying migrations:

```sh
supabase db lint --linked
psql "$SUPABASE_DB_URL" -f supabase/tests/backend_security_assertions.sql
deno check supabase/functions/reconcile-momo-sms/index.ts
deno check supabase/functions/admin-review-transaction/index.ts
flutter analyze
flutter test
```

The SQL assertion file is expected to return zero rows for every query.

## Remaining Risks

- Tenant keys are now present, but several product domains still need a second
  pass to make `organization_id` mandatory once creation paths populate it
  intentionally.
- The permission table is now available, but the legacy `profiles.role = admin`
  bootstrap fallback remains inside `has_platform_permission` until production
  admins are fully granted explicit permissions and the rollout is verified.
- Realtime publication membership is now narrower, but ledger transaction
  realtime remains enabled because the mobile ledger currently subscribes to it.
- Storage policy scope is tightened for existing buckets; any future bucket must
  be added through a migration with explicit MIME, size, read, write, and audit
  decisions.
