# Mobio production-readiness execution — 30 September 2026

This continues the [M001–M095 register](mobio-production-readiness-remaining-tasks-2026-09-29.md) and the [29 September execution record](mobio-production-readiness-execution-2026-09-29.md). Results below are local evidence for this branch, not hosted deployment or release acceptance. The applicable G01–G10 gates remain open.

## Changes and why

| Files | Reason |
| --- | --- |
| Twelve `supabase/migrations/2026092921543*_mobio_hardening_*.sql` through `20260929215442_mobio_hardening_privacy_request_workflow.sql` | Installed the twelve ordered, reviewed hardening bodies as timestamped source migrations using the pinned Supabase CLI 2.84.2. This makes a clean checkout capable of replaying the fixes; it does not apply them to a hosted database. |
| `supabase/hardening/2026-09-28/05_transport_hold_receipt_integrity.sql`, matching generated migration and `manifest.json` | Changed the seat-hold RPC from raw `auth.uid()` to `verified_app_user_id()`. Its service-only confirm/expiry paths now use the existing service-role helper, which accepts the supported JWT claim layouts. Updated the body digest. |
| `supabase/hardening/2026-09-28/06_bounded_driver_discovery.sql`, matching generated migration and `manifest.json` | Replaced flat-role-only checks with the existing service-role helper so authorized server discovery works with JSON JWT claims. Updated the body digest. |
| `scripts/qa/test_booking_authority_postgrest.py`, `.github/workflows/ci.yml` | Added a real PostgreSQL 17/PostgREST direct-write regression for M015 and made it a CI backend step. The test reproduces an owner write before body 01, then denies direct passenger mutation of six authority columns, insert and delete while retaining read and trusted RPC access. Its table, Auth tokens and RPC are synthetic. |
| `supabase/tests/notification_dispatch_behavior.sql`, `scripts/qa/test_biopay_full_schema.sh` | Replaced the obsolete immediate-HTTP notification test with durable-outbox assertions. A rolled-back pg_net override fails on any direct network send. |
| `supabase/tests/biopay_discovery_behavior.sql`, `admin_login_authority.sql`, `permission_expiry_behavior.sql`, `driver_discovery_authority.sql`, `provider_authority_assertions.sql` | Updated synthetic tests for the new Admin lease, reviewed-route and bounded discovery rules; checked actual invoice amount/currency/merchant comparisons. These are test corrections, not weaker production authorization. |
| `supabase/functions/_shared/sms-collector_test.ts`, `otp-verification_test.ts` | Updated stale Deno fixtures for durable SMS admission and mandatory Admin lease registration. OTP tests still assert single use and one issued session. |

## Verification

| Check | Result | Limit |
| --- | --- | --- |
| Clean disposable Supabase/PostgreSQL 17 full-schema replay | **Pass**: 119 migrations, including all twelve new bodies; BioPay, security, schema, provider, notification, realtime, permission expiry, live identity, Admin login, discovery and OTP rate-limit SQL assertions passed. | No sanitized representative forward-upgrade, hosted database, provider or real Auth JWT acceptance. |
| Booking authority through isolated PostgreSQL 17 and PostgREST | **Pass**: 16 assertions. | Body 01 plus synthetic table/RPC/JWT, not the complete Mobio schema or hosted endpoint. |
| `scripts/ci/verify_backend.sh` | **Pass**: 116 local Deno tests passed, none failed, one ignored. | Linked Supabase security gates were skipped because project reference and credential are unavailable. |
| `dart analyze` on pinned Flutter 3.44.3/Dart 3.12 | Exit 0 with 92 info-level lint findings. | No release or device acceptance. |
| Full `flutter test` on pinned Flutter 3.44.3 | Exit 1: 969 passed, 152 reference-golden failures. | M076 remains open; no baseline was silently approved. |
| Android appbundle release script with pinned Flutter | Stopped before compilation: `.env` and all four mandatory public build values absent. | No signed artifact or G06 acceptance. |
| Migration hash/order check, repository structure, secret-pattern scan, GitHub Actions pin check | Passed. | Not a historical secret audit, CI-hosted result or signed release check. |

The disposable database and PostgREST containers were removed after testing. No hosted migration was applied, provider call was made, or signing secret was added to the repository.

## External and remaining gates

- Drive folder `120JIOTyeNX6nHaHPDqS3UgbaTWyJAE57`: current permission readback shows **anyone with the link = reader**, owner `info@ikanisa.com`, named writer `bosco@ikanisa.com`. The public writer permission was removed, but M001 requires removing or explicitly approving remaining public reader access, checking inherited/child permissions, and retaining the access review/incident decision.
- M078 still needs a representative sanitized forward-upgrade rehearsal and migration provenance/rollback plan. M079 needs real hosted Auth/PostgREST, privileges and transactional concurrency evidence. M015's synthetic boundary test does not close its complete paid-transport acceptance criterion.
- M076 needs review of the 152 golden differences against approved designs, then a full passing suite. M077/G06 need the four public build values through the approved private path and a trusted signed artifact with device/store checks. Do not commit `.env`.
- The complete [task register](mobio-production-readiness-remaining-tasks-2026-09-29.md), including M002 credential provenance, the SMS queue saturation and private Storage race findings, provider/device/operations checks and the applicable G01–G10 acceptance gates, remains the controlling backlog. Paid transport, institutional SMS and Face-USSD stay disabled pending their separate gates.
