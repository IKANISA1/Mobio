# FCM HTTP v1 Secret Evidence

Date: 2026-06-14T15:24:10Z
Operator: Codex local QA
Supabase project ref: `paysnhuxngsvzdpwlosv`
Edge Function: `send-push`
Firebase project id: not recorded in this evidence file
Secret names validated:

- `FCM_SERVICE_ACCOUNT_JSON`

Validation method:

- Ran `supabase secrets list --project-ref paysnhuxngsvzdpwlosv --output json`
  through a redacting filter that printed only the expected secret names.
- Ran `supabase functions list --project-ref paysnhuxngsvzdpwlosv` and confirmed
  `send-push` is ACTIVE at version `15`, updated `2026-06-12 22:21:50 UTC`.
- Re-ran the linked backend gate as part of
  `RELEASE_TARGET=android ./scripts/release/go_no_go_check.sh`; the gate passed
  Supabase Deno tests, schema lint, storage/realtime audit, and backend security
  assertions.

Validation result:

- PASS: FCM HTTP v1 service-account secret name is configured in the linked
  Supabase project and `send-push` is deployed.

Notes:

- No service-account JSON, private key, access token, refresh token, or secret
  value is stored in this file.
