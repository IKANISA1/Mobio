# BioPay Live Supabase Deployment Evidence

Date: 2026-06-12
Project ref: `paysnhuxngsvzdpwlosv`

## Completed

- Deployed edge function `biopay-face-provider`.
- Pushed pending migrations through `supabase db push --linked --yes`:
  - `20260612133000_biopay_ussd_aws_reactivation.sql`
  - `20260612143000_biopay_qr_optional_amount.sql`
  - `20260612203130_driver_vehicle_records.sql`
  - `20260612204806_profile_momo_receiver_fields.sql`
- Confirmed remote migration list includes all four pushed versions.
- Confirmed remote BioPay tables/RPCs exist, including:
  - `public.biopay_profiles`
  - `public.biopay_payment_requests`
  - `public.rpc_create_biopay_ussd_request`
  - `public.rpc_record_biopay_face_enrollment`
  - `public.rpc_admin_biopay_system_status`

## Live Health Result

`https://paysnhuxngsvzdpwlosv.supabase.co/functions/v1/biopay-face-provider/health`
returned HTTP 200 after deployment, with:

- `provider`: `not_configured`
- `production_ready`: `false`
- `payment_boundary`: `USSD dialer handoff only; no in-app settlement.`

## Remaining External Configuration

Supabase function secrets currently do not include the required AWS Rekognition
provider variables:

- `FACE_PROVIDER=aws_rekognition`
- `AWS_REGION`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REKOGNITION_COLLECTION_ID`

Until those secrets are set, live AWS face enrollment/matching cannot be marked
production-ready even though the function and database schema are deployed.
