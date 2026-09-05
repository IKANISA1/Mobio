# Structure Refactor Changelog

## 2026-09-05 Canonical root renamed to mobio

- Relocated the full source tree and existing `.git` directory directly to
  `/Volumes/PRO-G40/mobio`, removing the outer `MOBI` and nested `mobi_app` layout.
- Moved all local recovery and output material into ignored `output/` under the
  same folder. No duplicate working checkout or compatibility symlink remains.
- Preserved HEAD, branch, Git index and uncommitted changes exactly during the
  move; verified all 1,771 source/document files by SHA-256 before updating paths.
- Excluded recovery archives from Dart analysis, editor search and file watching.
- Updated current repository documentation and generated local iOS path settings.
  The internal Dart package name and native application identities are unchanged.

Canonical command: `git -C /Volumes/PRO-G40/mobio status`.

Post-move validation passed: Dart analysis, 338 functional tests, nine Python
helper tests, architecture/import checks and `git diff HEAD --check`. Evidence:
`output/repository-relocation-20260905/after-move.json`.

## 2026-09-05 Repository consolidation

- Kept one canonical Git and Flutter root at `MOBI/mobi_app`; consolidated the
  useful parent-level editor configuration, release evidence and Dependabot
  configuration. Superseded parent workflows referenced obsolete roots and SDKs
  and were preserved with hashes (now under the ignored `output/` directory).
- Moved application startup, root widget, shell, router and app state into
  `lib/app/`, leaving a three-line `lib/main.dart` entry point.
- Organized each implemented feature into application, data, domain and
  presentation layers. Moved all 42 services out of the shared service directory
  into their feature or core infrastructure owner, preserving their method bodies.
- Split the service provider container into 15 modules and updated consumers to
  import their actual dependencies.
- Removed 18 redundant app-level model/theme exports and the BioPay screen barrel.
  Shared packages retain their public APIs; app-specific models have clear owners.
- Extracted shared QR/NFC payment payload parsing from the large UI helper into a
  pure domain module, removing a native-service dependency on presentation code.
- Removed 33 files of placeholder app/package/integration/agent/infrastructure
  scaffolding. Preserved their contents and earlier architecture snapshots under
  `history/`. Current ownership is documented in this directory's README.
- Consolidated native bridge historical QA into the main release evidence tree;
  future bridge captures write to ignored `build/qa/`.
- Preserved all 232 pre-existing local PNG changes with SHA-256 hashes before
  cleanup. Untracked generated failure images and the Fastlane report; reviewed
  golden baselines remain versioned. Old build/cache outputs and loose root logs
  were preserved locally (now under the ignored `output/` directory).
- Consolidated Flutter/Dart selection and public runtime-define parsing. All
  Flutter workflows now use 3.44.3; CI Android builds use the same guarded release
  script as local builds. Bootstrap generates shared model parts on a clean clone.
- Added architecture/import/hygiene checks and nine focused Python helper tests.
  Native app identities, applied migrations, platform sources, server contracts
  and existing golden baseline images are unchanged.

The detailed mapping is in [source-moves.json](source-moves.json). Local backup,
baseline comparisons and verification logs are under
`/Volumes/PRO-G40/mobio/output/repository-refactor-20260905/`. The refactor does not
commit, push, deploy or submit a store release.

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
