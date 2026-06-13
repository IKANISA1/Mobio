# Supabase Deploy Evidence

Date: 2026-06-12
Project ref: `paysnhuxngsvzdpwlosv`

## Database Push

Command:

```bash
supabase db push --linked --yes
```

Result: succeeded. The remote database reported `Remote database is up to date`.

Current remote migration history includes all June 12 migrations:

- `20260612100000_bus_driver_profile_onboarding`
- `20260612103000_full_stack_notification_delivery`
- `20260612104500_notification_trigger_vault_secret`
- `20260612120000_admin_catalog_rpc_audit_hardening`

Live schema checks confirmed:

- `public.fcm_tokens`: present.
- `public.notification_type_catalog`: present.
- `public.notification_delivery_attempts`: present.
- `public.profiles.bus_agency_name`: present.
- `public.fn_send_push_on_notification()`: present.
- Vault secret `mobio_send_push_service_role_key`: present.

## Edge Function Deployment

Deployed the functions that bundle the changed shared HTTP helper plus the new
push sender:

- `maps-gateway`: ACTIVE version `19`, updated `2026-06-12 15:26:28 UTC`.
- `chat-assist`: ACTIVE version `5`, updated `2026-06-12 15:26:31 UTC`.
- `send-otp`: ACTIVE version `28`, updated `2026-06-12 15:26:33 UTC`.
- `generate-promo-content`: ACTIVE version `24`, updated `2026-06-12 15:26:36 UTC`.
- `send-login-otp`: ACTIVE version `9`, updated `2026-06-12 15:26:38 UTC`.
- `verify-otp`: ACTIVE version `23`, updated `2026-06-12 15:26:41 UTC`.
- `send-push`: ACTIVE version `4`, updated `2026-06-12 15:26:43 UTC`.
- `verify-login-otp`: ACTIVE version `6`, updated `2026-06-12 15:26:46 UTC`.

## Runtime Secret Names

`supabase secrets list` confirmed required secret names are configured by
digest, including:

- `FCM_SERVICE_ACCOUNT_JSON`
- `SUPABASE_SERVICE_ROLE_KEY`
- `WABA_ACCESS_TOKEN`
- `WABA_PHONE_NUMBER_ID`
- `WABA_OTP_TEMPLATE_NAME`
- `WHATSAPP_CLOUD_ACCESS_TOKEN`

No secret values are stored in this evidence file.

## Linked Backend Gate

Command:

```bash
SUPABASE_PROJECT_REF=paysnhuxngsvzdpwlosv \
REQUIRE_LINKED_SUPABASE=true \
scripts/ci/verify_backend.sh
```

Result: passed.

- Secret-pattern scan passed.
- Edge Function Deno tests passed:
  - `supabase/functions/biopay-api/index_test.ts`: `2/2`.
  - `supabase/functions/_shared/otp-security_test.ts`: `2/2`.
  - `supabase/functions/_shared/whatsapp-cloud_test.ts`: `3/3`.
- Linked remote schema lint on `public` passed with no schema errors.
- Storage/realtime audit completed.
- Backend security assertions returned `backend security assertions passed`.
