# Supabase Tests

Database and Edge Function contract tests should live here once added.

Current backend verification is run by `../../scripts/ci/verify_backend.sh`, which type-checks Edge Functions, runs existing Deno tests, and lints the linked app-owned `public` schema when credentials are present.
