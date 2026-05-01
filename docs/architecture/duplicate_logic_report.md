# Duplicate Logic Report

## 1. User Identity & Agent Identity
- **PayLedger** uses `agent_id` (6-char) mapped to `auth.users`.
- **MOBI** uses `member_id` (6-digit numeric) mapped to `auth.users`.
- **Resolution:** MOBI's `member_id` will be used as the `agent_id` across the ledger system to ensure a unified identity. The UI must only ever show the 6-digit numeric `member_id`.

## 2. Country / Provider Configuration
- **PayLedger** uses `momo_providers` to map `country_code` and `sender_id`.
- **MOBI** uses `countries` for dialing codes and active state.
- **Resolution:** `momo_providers` is deprecated. `sender_id` and MoMo-specific USSD formats have been merged into MOBI's `countries` table.

## 3. UI and Theming
- **PayLedger** has a standalone Jetpack Compose design system ("Sovereign Architect").
- **MOBI** has a Flutter design system (`design.md`, Soft Liquid Glass).
- **Resolution:** Drop PayLedger's UI entirely. Rebuild Ledger dashboards in Flutter using `MobiSurfacePanel`, `ClayCard`, etc.

## 4. BioPay Backend API vs Supabase Edge Functions
- **BioPay** uses a FastAPI Python backend for vector matching and profile management.
- **MOBI** has Supabase Edge Functions (Deno/TypeScript) doing similar routing.
- **Resolution:** The FastAPI endpoints will be kept initially (Phase 3/4) to maintain the exact pgvector match logic, but will be integrated behind Supabase Edge Function proxies or Direct API calls from Flutter. Eventually, the vector match logic will be entirely moved to Supabase Postgres functions/RPCs if performance allows, retiring the Python backend.

## 5. Security & Authentication
- **PayLedger** uses Ktor with a manually stored Supabase Auth Token.
- **BioPay** uses Supabase Flutter Auth.
- **MOBI** uses Supabase Flutter anonymous-first Auth.
- **Resolution:** MOBI Flutter is the master auth controller. It will use a `MethodChannel` (`setLedgerCredentials`) to push the current `member_id` and Supabase JWT down to the native Android WorkManager so that background SMS syncing uses the correct auth context.
