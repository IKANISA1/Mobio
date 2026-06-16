# Supabase Seed Files

Current local replay seed data is `../seed.sql`.

Split seed files into this folder only after updating `../config.toml`
`db.seed.sql_paths` and verifying local reset behavior.

`kigali_ev_chargers.json` is the launch catalog for the EV charger locator.
Production gets the same rows through migration
`../migrations/20260616120000_seed_kigali_ev_chargers.sql`.

For later catalog refreshes, validate first:

```bash
deno run --allow-env --allow-net --allow-read scripts/admin/import_ev_chargers.ts
```

Apply only with explicit production credentials and human approval:

```bash
export SUPABASE_URL
export SUPABASE_SERVICE_ROLE_KEY
deno run --allow-env --allow-net --allow-read \
  scripts/admin/import_ev_chargers.ts --apply
```
