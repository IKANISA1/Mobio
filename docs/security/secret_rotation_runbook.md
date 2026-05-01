# Secret Rotation Runbook

Use this runbook whenever a Supabase access token, anon key, service-role key,
database password, or third-party API key has been exposed outside the approved
secret manager.

## Immediate Containment

1. Revoke exposed personal access tokens from the provider account that issued
   them.
2. Rotate the Supabase project API/JWT credentials from the Supabase project
   dashboard or approved platform-admin workflow.
3. Rotate the database password if it was exposed or if direct DB URLs were
   shared.
4. Rotate third-party provider keys that were in the same channel, including
   WhatsApp, Firebase, Google, OpenAI, and SMS/payment provider credentials.
5. Do not paste replacement values into chat, source files, tickets, or docs.

## Update Runtime Secrets

Update the approved secret stores only:

- CI/CD environment secrets.
- Mobile build dart-defines or release environment files.
- Supabase Edge Function secrets via `supabase secrets set`.
- Hosting provider variables for web/PWA surfaces.
- Local developer password managers or `.env` files that are excluded from git.

After updating Supabase Edge Function secrets, redeploy affected functions or
restart affected services so they read the new values.

## Validation

Run:

```bash
scripts/qa/scan_secrets.sh
supabase projects api-keys --project-ref "$SUPABASE_PROJECT_REF"
supabase secrets list --project-ref "$SUPABASE_PROJECT_REF"
```

Then verify:

- The old exposed token no longer authenticates.
- The app launches with the new anon key.
- Edge Functions can still reach Supabase and third-party providers.
- Admin-only flows still require authenticated admin sessions.
- No newly generated key appears in git diff or logs.

## Release Notes

Record the rotation date, affected secret names, old key revocation status, and
systems redeployed. Never record full secret values.
