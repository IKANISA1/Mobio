# BioPay release follow-up — 10 September 2026

The 24 recommendations remain implemented. The earlier implementation completion did not close release acceptance. This follow-up records additional database, installed-app and hosting work; physical devices, release signing, provider evidence, independent visual review and owner acceptance remain open.

## Database reconciliation and live application

The linked Mobio project is `paysnhuxngsvzdpwlosv`. Its initial history contained 92 migrations, including three 6 September security migrations missing from this isolated checkout. Their stored SQL statements were recovered from `supabase_migrations.schema_migrations` and restored to Git:

- `20260906143000_biopay_provider_authority.sql`
- `20260906144000_momobio_collector_authority.sql`
- `20260906145000_subscription_receipt_integrity.sql`

These recover existing database authority; they do not recover or replace uncommitted frontend work on the unavailable external drive. The live timestamp helper `public.set_updated_at()` also predates the tracked migration history. Its verified definition is an explicit replay prerequisite in `supabase/tests/fixtures/replay_prerequisites.sql`.

`scripts/qa/test_biopay_full_schema.sh` now recreates all 96 migrations plus that prerequisite in a disposable Supabase PostgreSQL instance. The BioPay authorization/behavior fixture and the existing backend security assertions pass against that complete migration history. The fast PostgreSQL fixture also passes. Synthetic users are seeded only in local test transactions; tests were not run as live customer mutations.

A schema-only backup was taken before applying exactly the four additive 8 September migrations. Backup SHA-256: `91008dee9bc7a7e9f17ae99df56ffc2f38c8e53ca07415dfa3378b94627450c1`. The backup stays in ignored local QA storage. Live readback confirms all four versions and a total of 96 registered migrations. All nine new private tables have RLS enabled and deny direct SELECT to `anon` and `authenticated`; access goes through the scoped RPCs. Existing backend security assertions also pass live inside a read-only transaction.

The public preview RPC returns HTTP 200 with `available: false` for a synthetic nonexistent link. The anonymous private discovery call returns HTTP 401, permission denied. There are **zero provider routes**. The seven provider evidence roots are research entries, not approved adapters. No provider was activated and no payment or payment attempt was created during these checks.

Supabase security advisors report no ERROR-level findings. Informational RLS-without-policy notices on the nine new tables reflect their intentional RPC-only access; existing project warnings still require their own review. These checks do not certify the whole application's security. See the [Supabase RLS advisor explanation](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy).

## Installed Android and app-link corrections

The full Flutter/native debug APK compiles with the required public runtime defines. It is installed in a new isolated Android emulator, without clearing or replacing the existing Mobio QA emulator's differently signed installation. Actual installed-app checks confirm WhatsApp sign-in, native resolution of `/biopay/pay/<token>`, an unavailable-request arrival screen and the manual-details action returning to sign-in. No OTP was sent.

The Android intent filter and Apple AASA now include `/biopay/pay/*`. A misleading NFC-only arrival message was replaced with the existing localized review label for shared link/NFC entry. The nine-table live authorization readback and installed arrival checks complement, rather than replace, the synthetic widget and domain tests.

The physical iPhone is unavailable and the external drive containing the original release context is unmounted. Android release signing configuration is absent from this checkout. Debug installation and unsigned iOS builds do not prove production certificate association, physical NFC/SIM behavior, contacts/gallery permissions on real devices, or signed store readiness.

## Hosting correction

Live HTTP inspection found that both `mobio.ikanisa.com/biopay/send` and `mobioadmin.ikanisa.com/admin-auth` served marketing HTML. The existing Cloudflare Pages project `mobio` owned both domains but had an empty build command and `landing` as its output directory. The earlier automatic deployment success therefore did not publish the Flutter feature.

The same Pages project is now configured to run `bash scripts/web/build_cloudflare_pages.sh` and publish `build/pwa/site`. The script pins Flutter 3.44.3 and its verified official Git revision, then builds the existing combined consumer/admin/landing bundle. Four verified public runtime values were configured for production and preview, without adding private credentials. Existing domains, Git source and deployment settings are preserved. Mutable `main.dart.js` and app assets now revalidate instead of receiving one-year immutable caching.

Publishing and deployed URL readback are recorded in the subsequent deployment evidence below. Configuration changes and local builds alone are not public availability proof.

## Validation and remaining acceptance

The final Dart analysis reports no issues and all **604 Flutter tests pass** after the localized arrival fix. Worker routing tests, public-site validation, workflow lint, repository structure and secret-pattern checks pass. Full-schema replay and backend checks are described above. Local logs are under `build/qa/biopay-release-20260910`; they remain ignored.

GitHub run [34456043645](https://github.com/IKANISA1/Mobio/actions/runs/34456043645), explicitly dispatched against the valid CI workflow, completed with `startup_failure` and zero jobs before checkout. Earlier implementation and baseline main runs failed the same way. Workflow ID `252559772` has empty name, path `BuildFailed` and state `deleted`; the actual CI workflow is `252559748`. Actionlint 1.7.12 validates the repository workflows, but cannot certify GitHub's dispatcher. A support-ready evidence draft is included separately; no support message has been sent and no workflow permissions were weakened.

Open acceptance: successful remote CI execution; existing production signing material; physical Android/iOS and provider/SIM tests; current approved provider instructions/tariffs and independent administrator approval; independent source-parity review and owner acceptance. These remain open even after web hosting and the additive database contracts are live.
