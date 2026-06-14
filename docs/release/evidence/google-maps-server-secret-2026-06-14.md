# Google Maps Server Secret Evidence

Date: 2026-06-14T21:32:00Z; updated after `info@gikundiro.com` project verification
Operator: Codex local QA
Supabase project ref: `paysnhuxngsvzdpwlosv`
Google Cloud project: `affable-anagram-499421-h1`
Edge Function: `maps-gateway`
Secret name: `GOOGLE_MAPS_SERVER_API_KEY`

Validation method:

- Restored Google Cloud CLI auth for `info@ikanisa.com`.
- Enabled the APIs required by `supabase/functions/maps-gateway/index.ts`:
  `places.googleapis.com` and `geocoding-backend.googleapis.com`.
- Deleted temporary/partial MOBI maps-gateway keys created during setup and
  created a fresh key named `MOBI maps-gateway server key`.
- After owner direction, replaced the generated key with the owner-provided
  Google Maps Platform key using `supabase secrets set --project-ref
  paysnhuxngsvzdpwlosv --env-file <temporary 0600 file>` and deleted the
  temporary file immediately afterward.
- Deleted the generated `MOBI maps-gateway server key` so the Supabase
  `maps-gateway` secret uses the owner-provided key.
- Verified `supabase secrets list --project-ref paysnhuxngsvzdpwlosv --output
  json` reports `GOOGLE_MAPS_SERVER_API_KEY`.
- Reauthenticated Google Cloud CLI as `info@gikundiro.com`, switched the active
  project to `affable-anagram-499421-h1`, and set ADC quota project to
  `affable-anagram-499421-h1`.
- Verified the owner-provided key resolves to
  `projects/189685329307/locations/global/keys/19b29bba-4f47-46fb-9bd0-555006d8f4da`
  with display name `Maps Platform API Key`.
- Enabled and verified the required APIs on `affable-anagram-499421-h1`:
  `places.googleapis.com`, `geocoding-backend.googleapis.com`,
  `fcm.googleapis.com`, `firebaseinstallations.googleapis.com`,
  `firebaseremoteconfig.googleapis.com`, `firebasecrashlytics.googleapis.com`,
  `identitytoolkit.googleapis.com`, and `firebase.googleapis.com`.
- Ran non-secret live API probes with the owner-provided key:
  Places Autocomplete returned HTTP 200 with suggestions, and Geocoding returned
  HTTP 200 with status `OK`.

Validation result:

- PASS: Owner-provided Google Maps server key is configured for the linked
  Supabase `maps-gateway` function and works for Places and Geocoding.

Notes:

- No API key value, secret listing with values, access token, or credential
  JSON is stored in this evidence file.
