# Supabase Deploy Evidence - 2026-06-13

Project: `paysnhuxngsvzdpwlosv`

## Database

- `supabase db push --linked --dry-run --yes`: remote database reported up to date.
- `supabase db push --linked --dry-run --include-all --yes`: remote database reported up to date.
- `supabase migration list --linked --yes`: blocked by CLI login-role password authentication, but `db push --dry-run` connected successfully and reported no pending migrations.

## Edge Functions

Deployed with `~/.codex/bin/supabase` `2.101.0` using the Supabase project access token.

Updated live function versions:

- `send-login-otp`: version `14`, updated `2026-06-12 22:21:50 UTC`.
- `verify-login-otp`: version `11`, updated `2026-06-12 22:21:50 UTC`.
- `send-otp`: version `34`, updated `2026-06-12 22:21:50 UTC`.
- `verify-otp`: version `28`, updated `2026-06-12 22:21:50 UTC`.
- `send-push`: version `8`, updated `2026-06-12 22:21:50 UTC`.
- `biopay-face-provider`: version `2`, updated `2026-06-12 22:21:50 UTC`.

Removed stale remote function:

- `chat-assist`: deleted from the project after the app and repo tests removed the chat AI assist surface.

## Live Smoke Checks

- `POST /functions/v1/send-login-otp` with invalid Rwanda phone returned `400` and `Valid WhatsApp number required`.
- `POST /functions/v1/verify-login-otp` with invalid 2-digit code returned `400` and `Phone and 6-digit code required`.
- REST schema probe for `profiles` with `momo_number,momo_pay_code` returned `200`.
- REST schema probe for `vehicles` with `owner_id,vehicle_type_id,plate_number` returned `200`.
- REST schema probe for `biopay_payment_requests` with `payee_id,amount_minor,status` returned `200`.
- REST schema probe for `fcm_tokens` with `user_id,token,platform` returned `200`.

## Local Backend Verification

- `scripts/ci/verify_backend.sh`: passed.
- Secret-pattern scan: passed.
- Deno checks for OTP Edge Functions: passed.
- `biopay-api` Deno tests: `2 passed`.
- `biopay-face-provider` Deno tests: `1 passed`.
- OTP security Deno tests: `3 passed`.
- Phone normalization Deno tests: `5 passed`.
- WhatsApp Cloud Deno tests: `5 passed`.

## Linked Backend Verification

Reran `scripts/ci/verify_backend.sh` with `SUPABASE_PROJECT_REF=paysnhuxngsvzdpwlosv` and a project access token.

- Live schema lint for schema `public`: passed with no schema errors.
- Storage/realtime audit step: completed inside the backend script.
- `supabase/tests/backend_security_assertions.sql`: passed and returned `backend security assertions passed`.

One repo assertion was corrected before the passing rerun: `biopay_profiles` is now an in-scope BioPay AWS/USSD table and was removed from the forbidden legacy table list. The older out-of-scope BioPay wallet/transaction/face-template tables remain forbidden.

## Not Done In This Step

- No Android APK/AAB build.
- No release artifact upload.
- No positive WhatsApp OTP send/verify UAT on the physical device.
- No BioPay NFC/QR/face positive transaction UAT.
