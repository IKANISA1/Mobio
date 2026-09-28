# Mobio production hardening — Increment 02 (28 September 2026)

This package contains the exact source changes currently implemented against the supplied Mobio baseline, plus a unified patch, validation evidence and a task-status ledger. It is **not** a production-deployment receipt.

## Implemented locally in this increment

- Canonical server-managed unique six-digit member IDs and removal of client pseudo-ID/hash fallbacks.
- Ordinary account sign-out with fail-safe cleanup; owner-bound FCM registration/unregistration.
- Idempotent public-transport holds, durable expired-hold release, and one-receipt/one-booking binding.
- Bounded nearby-driver discovery: verified session, 2-minute freshness, 10 km radius, 50-row hard cap, and no global direct online-location read.
- Face enrollment status distinguishes service unavailability from not-enrolled.
- Expanded database post-install assertions for identity, transport and discovery invariants.

The package also includes Increment 01 hardening still present in the working tree: verified-phone login authority, booking write containment, strict SMS receipt eligibility, OTP dry-run safety, legacy SMS endpoint retirement, bounded external calls, target API 36 source setting, NFC expiry/APDU checks, inference HTTP bounds, release-gate truthfulness, migration preparation and CI/toolchain hardening.

## Verification

187 targeted local scenarios pass at this source state. This includes Python source/fixture tests, Node Edge-module/handler fixtures, HTTP server tests and JVM NFC policy tests. `git diff --check` and the repository Actions-pin check pass.

Not run: PostgreSQL/PostgREST/Auth concurrency, real Deno staging, Flutter full/golden suite at this source state, signed Android/iOS devices, NFC hardware, live Rwanda operator journeys, real face-model/Vectorize accuracy/load, or production deployment. The connected Supabase plugin returned no projects, therefore none of the six forward SQL bodies was applied.

## Integration

Review `MOBIO_HARDENING_INCREMENT02.patch`, `CHANGE_MANIFEST.json`, and `VALIDATION_RESULTS.json`. The `changed-files/` tree contains every revised source file in this package. Generate actual Supabase migration filenames with the repository preparer and an installed Supabase CLI, then rehearse the complete migration chain and `post_install_assertions.sql` on an isolated target before any deployment.

Do not mark the overall production backlog complete from this package; task status distinguishes locally implemented work from deployment/device/organizational evidence that remains open.
