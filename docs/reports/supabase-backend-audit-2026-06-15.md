# Supabase Backend Audit - 2026-06-15

## Scope

Migrations, RLS, RPCs, Edge Functions, triggers, secrets, linked remote state, destructive-operation protections, test coverage, and live evidence for Mobio, BioPay, Mo Mobio SMS, admin, wallet/tokens/subscriptions, notifications, maps, and public transport.

## Inventory

- Migration files detected: 80.
- Edge Function areas: `_shared`, admin transaction review, BioPay API/face provider, maps gateway, Mo Mobio SMS ingest/reconcile/parse, OTP send/verify, push, payment status, legacy/scope-boundary functions.
- SQL tests: `supabase/tests/backend_security_assertions.sql`, `supabase/tests/storage_realtime_audit.sql`.

## Worklist

| Area | Required checks | Status |
| --- | --- | --- |
| RLS and RPC ownership | Tables/RPCs use authenticated/admin boundaries and no direct client writes where server-owned | Pending detailed review |
| Wallet/ledger/subscription | Ledger mutations server-owned, subscription gates server-side, MoMo duplicate/idempotency controls | Contract-covered, SQL review pending |
| Mo Mobio SMS ingest | Direct anon upload function, raw receipt storage, OpenAI parser backend-only, duplicate controls | In progress |
| BioPay | USSD/AWS bounded, no card/in-app settlement claim, admin external confirmation audited | Contract-covered, detailed SQL/function review pending |
| Maps gateway | Server key only, Rwanda bounds, rate limit, no route compute | Contract-covered |
| Notifications | Trigger/fanout, FCM v1, token pruning, audit | Contract-covered |
| Admin | Admin allowlists, audited writes, privilege escalation boundaries | Pending detailed review |
| Destructive protections | Release scripts avoid destructive Supabase operations; destructive commands documented/guarded | Pending |
| Linked remote proof | Schema lint, backend assertions, deployed function health | Passed this phase |

## Evidence Added This Phase

- `set -a; source .env; set +a; ./scripts/ci/verify_backend.sh` passed.
- Deno tests passed for BioPay API, BioPay face provider, maps gateway, OTP security, phone normalization, and WhatsApp Cloud helpers.
- Linked Supabase public schema lint returned `No schema errors found`.
- Backend security assertions returned `backend security assertions passed`.

## Findings

| ID | Severity | Finding | Status | Next action |
| --- | --- | --- | --- | --- |
| BE-001 | Fixed | Linked backend verification is current after the profile/SMS audit batch; no backend source changes were made in this phase. | Fixed | Re-run if backend files change during later remediation. |
| BE-002 | Open | Detailed migration/RPC/function review is not yet complete despite linked gate success. | Open | Continue table/RPC/function-level audit before final full-repo readiness close. |
