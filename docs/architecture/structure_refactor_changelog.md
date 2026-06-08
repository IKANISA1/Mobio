# Structure Refactor Changelog

## 2026-05-23 Scope Correction

- Current Mobio production scope is nearby discovery, scheduled trip posts,
  profiles, and communication only.
- BioPay, payments, SMS ledger, PayLedger, and ride-request lifecycle references
  in older architecture notes are historical context, not active product scope.
- Active local packages are design-system and shared-types; the prior
  `packages/payments` extraction is removed from the app package.

## 2026-05-01

- Added monorepo boundary documentation under `apps/`, `packages/`, `agents/`, `integrations/`, and `infra/`.
- Moved non-runtime inventory/audit documents from the repo root into `docs/architecture`, `docs/product`, and `docs/security`.
- Added `docs/architecture/monorepo_structure.md` with current structure, target structure, boundary mapping, and phased extraction plan.
- Added `infra/config/repo-boundaries.yaml` as a machine-readable compatibility map for future refactor planning.
- Added Supabase documentation folders for policies, tests, docs, and future split seed files without changing the active Supabase config.
- Updated root `README.md` and `CRITICAL_RULES.md` so auth documentation matches the current WhatsApp OTP production model.
- Extracted app-agnostic theme tokens into `packages/design-system` and left compatibility exports in `lib/core/theme`.
- Extracted pure Dart models and generated `freezed`/JSON files into `packages/shared-types` and left compatibility exports in `lib/models`.
- Extracted payment DTOs into `packages/payments` and added an explicit USSD instruction DTO. Legacy intent/session DTOs remain only for compatibility and back-office/manual audit paths.

## 2026-05-01 Payment Direction Correction

- Confirmed the product does not support in-app payments or payment provider APIs.
- Updated the Flutter payment service to parse local USSD instructions only and fail closed for intent creation, status verification, QR session RPCs, NFC session RPCs, and intent realtime watches.
- Updated `create-payment-intent` and `verify-payment-status` Edge Functions to return `410 Gone` with an `external_ussd_only` code.
- Kept manual/back-office payment reconciliation surfaces in place for auditable external confirmation.

No native Android/iOS, Supabase function, migration, asset, app route, or CI workflow path was moved in this phase. Runtime Dart package moves were limited to local path packages with export shims and passing analysis.
