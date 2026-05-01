# Supabase Backend

This directory is the canonical backend source for MOBI.

- `migrations/`: schema, RLS, RPCs, triggers, indexes, realtime configuration.
- `functions/`: Edge Functions and shared Deno helpers.
- `config.toml`: Supabase CLI project configuration.
- `seed.sql`: current local seed data.
- `policies/`: future extracted policy documentation or generated policy views.
- `tests/`: future database and Edge Function contract tests.
- `docs/`: backend-specific runbooks and operational notes.

Do not move Edge Function shared helpers without updating every relative import and running backend verification.
