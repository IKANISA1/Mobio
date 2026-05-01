# Payments Package

Shared external payment data contracts and USSD-domain helpers.

## Current Contents

- USSD instruction DTOs: `lib/src/models`
- Legacy payment intent/session DTOs kept for compatibility while backend manual
  confirmation and audit tables are phased into clearer names.
- Public exports: `lib/models` and `lib/mobi_payments.dart`

Compatibility exports remain in `../../lib/features/payments/models` so existing
imports keep working during the app split.

The production product does not support in-app payments or payment provider APIs.
The mobile app may display/launch USSD instructions only. Status changes are
external/manual and must remain auditable outside the passenger payment flow.

## Still App/Backend Owned

- Flutter USSD instruction client: `../../lib/features/payments/services`
- Native ledger bridge: `../../lib/features/ledger`, `../../android/app/src/main/kotlin/com/mobi/ledger`
- Payment Edge Functions: `../../supabase/functions/create-payment-intent` and
  `../../supabase/functions/verify-payment-status` intentionally return `410`
  because in-app payment creation/status checks are unsupported.
- Back-office/manual confirmation functions: `../../supabase/functions/reconcile-momo-sms`, `../../supabase/functions/admin-review-transaction`
- Payment schema/RPCs: `../../supabase/migrations`

Payment state transitions must stay server-owned, manual/back-office driven, and
auditable.
