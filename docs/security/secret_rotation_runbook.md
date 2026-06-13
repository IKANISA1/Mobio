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

For Google Play upload credentials, revoke the exposed service-account key in
Google Cloud IAM first, create a replacement key only in the approved secret
manager, and update `PLAY_STORE_SERVICE_ACCOUNT_JSON` in CI. Do not recreate
`android/fastlane/play-store-service-account.json`; `scripts/qa/scan_secrets.sh`
fails if that path reappears.

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

## Git History Purge

Only run history rewriting after the replacement credentials are active and all
collaborators are ready to rebase or reclone. Work from a clean clone or clean
working tree. Before rewriting history, run the non-destructive preflight:

```bash
scripts/qa/preflight_secret_history_purge.sh
```

If it passes, remove the historical Google Play service-account file:

```bash
git filter-repo --path android/fastlane/play-store-service-account.json --invert-paths --force
git log --all --full-history -- android/fastlane/play-store-service-account.json
scripts/qa/check_secret_history.sh
scripts/qa/scan_secrets.sh
```

If `git filter-repo` is unavailable, install it through the approved developer
tooling channel first. After reviewing the rewritten history, push with lease:

```bash
git push --force-with-lease=main:<old-remote-main-hash> origin main
```

Then confirm the old key cannot be used, CI has the replacement
`PLAY_STORE_SERVICE_ACCOUNT_JSON`, and no protected branch or release tag still
references the purged object.

## Release Notes

Record the rotation date, affected secret names, old key revocation status, and
systems redeployed. Never record full secret values.

## MOBI 2026-06-13 Release Blocker Checklist

This checklist applies to the current MOBI production-readiness blocker opened
after Supabase and project tokens were pasted into the working session. Treat
the listed credentials as exposed even if repository scans pass.

### Supabase

Rotate or revoke:

- Supabase personal/project access tokens.
- Supabase anon key if it was pasted or used in generated release builds.
- Supabase service-role key if it was pasted or used outside the approved secret
  store.
- Supabase database password if it was shared or used outside the approved
  password manager.

Required proof:

- Old personal/project access token no longer authenticates.
- New anon key is stored only in approved `.env`/CI secret storage.
- New service-role key is stored only in server-side/Supabase/CI secret storage.
- `supabase db push --linked --dry-run --yes` passes with the new database
  password.
- `REQUIRE_LINKED_SUPABASE=true scripts/ci/verify_backend.sh` passes.
- Fresh APK is rebuilt after anon-key rotation and its SHA-256 is recorded.

### AWS Rekognition for BioPay Face

Create or rotate:

- `FACE_PROVIDER=aws_rekognition`
- `AWS_REGION`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REKOGNITION_COLLECTION_ID`
- `BIOPAY_FACE_HEALTH_URL`

Required proof:

- AWS IAM key is least-privilege for the required Rekognition collection.
- Supabase Edge Function secrets are set without printing values.
- `REQUIRE_BIOPAY_LIVE=true scripts/qa/verify_biopay_live_readiness.sh` passes.

### Android and Play Release

Confirm or rotate:

- `KEYSTORE_BASE64`
- `KEY_ALIAS`
- `KEY_PASSWORD`
- `STORE_PASSWORD`
- `PLAY_STORE_SERVICE_ACCOUNT_JSON`

Required proof:

- `scripts/ci/verify_release_config.sh` passes with
  `REQUIRE_ANDROID_SIGNING=true`.
- Play service-account key is either rotated/revoked with evidence, or retained
  only with owner-approved evidence.
- Play Console internal/closed-track upload validation evidence exists and is
  not an example template.

### Post-Rotation Gates

Run after every affected secret is rotated:

```bash
scripts/qa/scan_secrets.sh
scripts/qa/check_secret_history.sh
REQUIRE_LINKED_SUPABASE=true scripts/ci/verify_backend.sh
REQUIRE_BIOPAY_LIVE=true scripts/qa/verify_biopay_live_readiness.sh
scripts/release/build_android_release.sh apk
adb -s 13111JEC215558 install -r build/app/outputs/flutter-apk/app-release.apk
```

Then complete unlocked physical-device UAT and update the final go/no-go report.
