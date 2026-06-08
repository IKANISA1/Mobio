# MOBI Monorepo Structure Plan

> Historical snapshot: this 2026-05-01 structure plan predates the 2026-05-23
> Mobio limited-scope cleanup. Treat BioPay, payment, SMS ledger, and
> ride-request lifecycle references below as historical architecture context
> only. Current product scope is `docs/product/scope.md`.

Date: 2026-05-01

## Current Structure

MOBI is currently a single Flutter/Supabase repo:

```text
.
├── android/                 # Flutter Android host plus active native ledger package
├── assets/                  # ML model, vehicle images, bundled fonts
├── icon/                    # App icons and splash assets
├── ios/                     # Flutter iOS host
├── landing/                 # Static public website and policy pages
├── lib/                     # Flutter app, admin, PWA, shared UI, services, models
├── pigeons/                 # Flutter/native API definitions
├── scripts/                 # CI, release, web deployment, admin bootstrap scripts
├── store_assets/            # App-store screenshots
├── supabase/                # Canonical migrations and Edge Functions
├── test/                    # Flutter unit/widget tests
└── web/                     # Flutter web host assets
```

The Flutter package name is `mobi_app`, so runtime Dart code currently depends on `package:mobi_app/...` imports. Supabase Edge Functions depend on relative imports inside `supabase/functions/_shared`. Cloudflare/Firebase deploy scripts currently point at `landing/`, `web/`, and generated `build/pwa/*` outputs.

## Target Structure

The long-term production structure is:

```text
apps/
├── mobile/                  # Flutter mobile shell: Android/iOS plus mobile entry points
├── pwa/                     # Passenger/driver installable PWA shell
├── admin/                   # Admin PWA/panel shell
├── website/                 # Public marketing, privacy, and policy website
├── venue-dashboard/         # Future venue/cooperative dashboard shell
└── agent-console/           # Future operator/agent console shell

packages/
├── design-system/           # App tokens, theme, reusable components
├── shared-types/            # Cross-app Dart/TS domain DTOs and generated contracts
├── shared-utils/            # Pure helpers with no Flutter or Supabase coupling
├── domain/                  # Trip, driver, passenger, saved-place, entitlement logic
├── api-clients/             # Supabase/Edge Function clients
├── auth/                    # Auth, roles, permissions, session policy
├── payments/                # Payment intent/session/ledger state logic
├── agent-ui/                # Shared agent/operator UI widgets
└── analytics/               # Analytics, crash, event taxonomy

supabase/
├── migrations/              # Source-of-truth schema, RLS, RPCs, triggers
├── functions/               # Edge Functions and shared Deno helpers
├── policies/                # Extracted RLS policy documentation or generated views
├── seed/                    # Future split seed files
├── tests/                   # Database and Edge Function tests
└── docs/                    # Backend-specific operational docs

agents/
├── shared/                  # Shared agent policy, schemas, guardrails
├── workspaces/              # Product-specific agent workspaces
├── tools/                   # Tool contracts and adapters
├── channels/                # WhatsApp/Telegram/Chat/email channel routing
├── memory/                  # Memory policy and storage contracts
├── evals/                   # Agent evaluations
└── prompts/                 # Prompt source of truth

integrations/
├── whatsapp/
├── telegram/
├── google-chat/
├── teams/
├── email/
├── voice/
├── ussd/
└── payments/

docs/
├── architecture/
├── product/
├── security/
├── release/
├── testing/
└── operations/

scripts/
├── admin/
├── ci/
├── release/
└── web/

infra/
├── ci/
├── config/
└── monitoring/
```

## Boundary Mapping

| Target boundary | Current source of truth | Move status |
| --- | --- | --- |
| `apps/mobile` | `lib/`, `android/`, `ios/`, `assets/`, `icon/`, `pigeons/` | Keep in place until Flutter package/import migration is planned. |
| `apps/pwa` | `lib/`, `web/`, `scripts/web/prepare_pwa_bundles.sh` | Keep in place; generated output remains `build/pwa/client`. |
| `apps/admin` | `lib/features/admin`, admin routes in `lib/core/router` | Keep in place; generated output remains `build/pwa/admin`. |
| `apps/website` | `landing/`, `firebase.json`, Cloudflare Pages workflow | Keep `landing/` for current deploy compatibility. |
| `packages/design-system` | `packages/design-system/lib/src/theme`, `design.md`; compatibility exports in `lib/core/theme`; widgets still in `lib/shared/widgets` | Theme tokens extracted as a local path package. |
| `packages/shared-types` | `packages/shared-types/lib/src/models`; compatibility exports in `lib/models`; UI-backed `vehicle_type_model.dart` remains in app | Pure models and generated `freezed` outputs extracted as a local path package. |
| `packages/api-clients` | `lib/core/services`, `lib/features/*/services`, Supabase Edge Function contracts | Extract per service domain after tests cover contracts. |
| `packages/auth` | `lib/core/auth`, `supabase_session_service`, OTP/login services | Extract after admin/app auth routing is stabilized. |
| `packages/payments` | `packages/payments/lib/src/models`; compatibility exports in `lib/features/payments/models`; payment service, Edge Functions, and ledger bridge remain in place | Payment DTOs extracted as a local path package; state transitions remain server-owned. |
| `agents` | `AGENTS.md`, `prompts.md`, `chat-assist`, `generate-promo-content` | Documented only; no OpenClaw workspace found. |
| `integrations/whatsapp` | WhatsApp Edge Function helpers and OTP functions | Documented only; keep function imports intact. |
| `infra/ci` | `.github/workflows`, `scripts/ci` | Documented only; workflows keep existing paths. |

## Safe Phase Applied

This phase first moved non-runtime documentation into `docs/` and added boundary
README files. It then extracted two low-risk local Dart packages:

- `packages/design-system` owns app-agnostic theme tokens.
- `packages/shared-types` owns pure Dart model contracts and generated JSON/freezed files.
- `packages/payments` owns USSD payment instruction DTOs plus legacy
  intent/session DTO compatibility exports. Passenger payment flows must not
  create in-app payment intents or poll payment status APIs.

Old import paths remain as compatibility exports so app routes, services, tests,
and deploy scripts keep working during the transition.

## Next Refactor Phases

1. Extract stable app-agnostic shared widgets into `packages/design-system` only after their service/model dependencies are removed.
2. Extract audited payment service-state helpers into `packages/payments` without moving server-owned transitions.
3. Move Supabase client wrappers from `lib/core/services` into `packages/api-clients` by domain.
4. Move auth/session/permission helpers into `packages/auth` after admin/app auth route coverage is expanded.
5. Move app-specific UI shells into `apps/mobile`, `apps/pwa`, and `apps/admin` only after the root Flutter project is converted to a workspace/package setup.
6. Split `supabase/seed.sql` into `supabase/seed/` and add database policy tests under `supabase/tests/`.
7. Convert `.github/workflows` into documented infra ownership under `infra/ci` without changing workflow paths until GitHub supports the target layout in this repo.
