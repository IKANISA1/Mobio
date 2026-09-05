# Retired structure scaffolding

Preserved on 2026-09-05. These folders described proposed boundaries but contained no runtime implementations. The current architecture map replaces them.

## agents/README.md

```text
# Agents

No OpenClaw workspace, MCP server definition, agent memory store, or channel-specific agent runtime was found in this repo.

Current agent-like assets:

- `../AGENTS.md`: repo operating guidance.
- `../prompts.md`: prompt notes.
- `../supabase/functions/chat-assist`: chat assistant Edge Function.
- `../supabase/functions/generate-promo-content`: AI promo generation Edge Function.

Target boundaries:

- `shared/`: common agent policy, structured output schemas, permission rules.
- `workspaces/`: product-specific agent workspaces.
- `tools/`: tool contracts and allowlists.
- `channels/`: WhatsApp, Telegram, Google Chat, Teams, email, and voice adapters.
- `memory/`: memory isolation and retention policy.
- `evals/`: regression/evaluation suites.
- `prompts/`: prompt source files.

Do not add production agent runtime paths without explicit authentication, authorization, audit logging, and tool allowlist design.

```

## agents/evals/README.md

```text
# Agent Evals

No agent evaluation suite was found in this repo.

Add regression tests here before deploying production agent routing or tools.

```

## agents/tools/README.md

```text
# Agent Tools

No production agent tool registry was found in this repo.

Tool definitions must include permission checks, input schemas, output schemas, audit logging, and rate limits.

```

## agents/memory/README.md

```text
# Agent Memory

No production agent memory store was found in this repo.

Any memory implementation must define tenant boundaries, retention, deletion, consent, and retrieval permissions.

```

## agents/shared/README.md

```text
# Shared Agent Policy

No production shared agent policy files exist yet.

When added, define identity, permissions, structured outputs, memory boundaries, and audit requirements here.

```

## agents/workspaces/README.md

```text
# Agent Workspaces

No OpenClaw or product-specific agent workspace was found in this repo.

Workspace definitions must include allowed tools, data boundaries, owner, deployment target, and evaluation coverage.

```

## agents/prompts/README.md

```text
# Agent Prompts

Current prompt notes live in `../../prompts.md`.

Future prompt files should live here with versioning, structured-output contracts, and eval coverage.

```

## agents/channels/README.md

```text
# Agent Channels

No production agent channel router was found in this repo.

Channel adapters should map external identities to internal users without bypassing auth, RLS, or audit requirements.

```

## integrations/README.md

```text
# Integrations

This folder documents external integration ownership. Runtime code remains in the current app/Supabase paths until each adapter is extracted safely.

| Integration | Current source |
| --- | --- |
| WhatsApp | `../supabase/functions/_shared/whatsapp-cloud.ts`, OTP Edge Functions, Flutter WhatsApp login/admin services |
| Telegram | No runtime adapter found |
| Google Chat | No runtime adapter found |
| Teams | No runtime adapter found |
| Email | Auth/admin email identifiers only; no mail adapter found |
| Voice | No runtime adapter found |
| USSD | BioPay QR/USSD services in Flutter and country schema/RPCs |
| Payments | Payment Edge Functions, QR/NFC resolver RPCs, Android ledger, MoMo SMS reconciliation |

Adapter extraction rule: keep channel-specific transport logic here; keep authorization, payment state, and tenant isolation in Supabase-backed domain services.

```

## integrations/payments/README.md

```text
# Payment Integrations

Current source:

- Payment Edge Functions under `../../supabase/functions`
- Payment migrations/RPCs under `../../supabase/migrations`
- Flutter payment client under `../../lib/features/payments`
- Native ledger under `../../android/app/src/main/kotlin/com/mobi/ledger`

Payment status transitions must remain server-owned and auditable.

```

## integrations/google-chat/README.md

```text
# Google Chat Integration

No runtime Google Chat adapter was found in this repo.

Add one only with explicit auth, channel identity mapping, audit logging, and agent/tool permission design.

```

## integrations/voice/README.md

```text
# Voice Integration

No runtime voice adapter was found in this repo.

Add one only with call recording/consent policy, identity mapping, audit logging, and escalation handling.

```

## integrations/ussd/README.md

```text
# USSD Integration

Current source:

- BioPay QR/USSD Flutter helpers under `../../lib/features/biopay`
- Country and USSD data in Supabase migrations/RPCs under `../../supabase/migrations`

USSD payload generation must remain country/currency/provider aware.

```

## integrations/telegram/README.md

```text
# Telegram Integration

No runtime Telegram adapter was found in this repo.

Add one only with explicit auth, channel identity mapping, audit logging, and agent/tool permission design.

```

## integrations/teams/README.md

```text
# Teams Integration

No runtime Microsoft Teams adapter was found in this repo.

Add one only with explicit auth, channel identity mapping, audit logging, and agent/tool permission design.

```

## integrations/email/README.md

```text
# Email Integration

No production email adapter was found in this repo. Current email usage is limited to internal auth/admin identifiers.

Add outbound email only with templates, provider configuration, unsubscribe/compliance handling where relevant, and audit logging.

```

## integrations/whatsapp/README.md

```text
# WhatsApp Integration

Current source:

- `../../supabase/functions/_shared/whatsapp-cloud.ts`
- `../../supabase/functions/send-login-otp`
- `../../supabase/functions/verify-login-otp`
- `../../supabase/functions/send-otp`
- `../../supabase/functions/verify-otp`
- Flutter login/admin services under `../../lib/core/services`

Passenger/driver OTP and admin OTP must remain separate purposes.

```

## infra/README.md

```text
# Infrastructure

This folder documents production infrastructure boundaries.

Current source of truth:

- GitHub Actions: `../.github/workflows`
- CI scripts: `../scripts/ci`
- Release scripts: `../scripts/release`
- Web deploy scripts: `../scripts/web`
- Firebase hosting: `../firebase.json`
- Supabase config: `../supabase/config.toml`

Workflow files remain in `.github/workflows` because GitHub requires that path.

```

## infra/config/repo-boundaries.yaml

```text
version: 1
status: compatibility-packages
updated: 2026-05-01
runtime_moves_allowed_without_plan: false
apps:
  mobile:
    current_source:
      - lib
      - android
      - ios
      - assets
      - icon
      - pigeons
  pwa:
    current_source:
      - lib
      - web
      - scripts/web/prepare_pwa_bundles.sh
      - build/pwa/client
  admin:
    current_source:
      - lib/features/admin
      - lib/core/router
      - lib/core/services/admin
      - build/pwa/admin
  website:
    current_source:
      - landing
      - firebase.json
packages:
  design-system:
    current_source:
      - design.md
      - packages/design-system/lib/src/theme
      - lib/shared/widgets
    compatibility_exports:
      - lib/core/theme
  shared-types:
    current_source:
      - packages/shared-types/lib/src/models
      - lib/core/constants/app_enums.dart
    compatibility_exports:
      - lib/models
    app_owned_exceptions:
      - lib/shared/models/vehicle_type_model.dart
  api-clients:
    current_source:
      - lib/core/services
      - lib/features/*/services
  auth:
    current_source:
      - lib/core/auth
      - lib/features/admin/data/otp_service.dart
      - lib/features/auth/data/whatsapp_login_service.dart
      - lib/core/auth/supabase_session_service.dart
  payments:
    current_source:
      - packages/payments/lib/src/models
      - lib/features/payments/services
      - lib/features/ledger
      - supabase/functions/create-payment-intent
      - supabase/functions/verify-payment-status
      - supabase/functions/reconcile-momo-sms
      - supabase/functions/admin-review-transaction
    compatibility_exports:
      - lib/features/payments/models
backend:
  canonical_source:
    - supabase/migrations
    - supabase/functions
    - supabase/seed.sql
docs:
  canonical_source:
    - docs

```

## infra/ci/README.md

```text
# CI Infrastructure

Current GitHub Actions workflows remain in `../../.github/workflows`, which is the path required by GitHub.

This folder is for CI ownership docs, workflow design notes, and future generated reports.

```

## infra/monitoring/README.md

```text
# Monitoring Infrastructure

Current monitoring hooks are distributed across Firebase Crashlytics, Firebase Analytics, app logging, Supabase Edge Function logs, and operational audit tables.

Add production dashboards, alert definitions, and incident links here as they are formalized.

```

## apps/admin/README.md

```text
# Admin App Boundary

Current source of truth:

- Admin screens and widgets: `../../lib/features/admin`
- Admin route guards: `../../lib/core/router`
- Admin services: `../../lib/core/services/admin` and `../../lib/core/services/admin_service.dart`
- Generated admin PWA output: `../../build/pwa/admin`

Admin authorization remains enforced server-side through Supabase RPCs and Edge Functions. Do not duplicate admin permission logic in this folder.

```

## apps/agent-console/README.md

```text
# Agent Console Boundary

No runtime agent console source exists yet in this repo.

Current agent-like surfaces are documented in `../../agents/README.md` and implemented through Supabase Edge Functions where applicable.

```

## apps/mobile/README.md

```text
# Mobile App Boundary

Current source of truth:

- Flutter app code: `../../lib`
- Android host and active native ledger: `../../android`
- iOS host: `../../ios`
- Assets: `../../assets`, `../../icon`
- Native API definitions: `../../pigeons`

This directory is a boundary marker for the future `apps/mobile` extraction. Runtime files are intentionally not moved yet to avoid breaking `package:mobi_app` imports, Flutter tooling, and native build scripts.

```

## apps/pwa/README.md

```text
# PWA Boundary

Current source of truth:

- Flutter web host: `../../web`
- Shared Flutter app routes and UI: `../../lib`
- Bundle preparation: `../../scripts/web/prepare_pwa_bundles.sh`
- Generated passenger/driver output: `../../build/pwa/client`

This directory documents ownership only. The deployable bundle remains generated from the root Flutter app.

```

## apps/venue-dashboard/README.md

```text
# Venue Dashboard Boundary

No runtime venue dashboard source exists yet in this repo.

When this surface is approved, add a production app shell here only with a product spec, auth model, RLS review, and deployment plan.

```

## apps/website/README.md

```text
# Website Boundary

Current source of truth:

- Static site: `../../landing`
- Firebase hosting config: `../../firebase.json`
- Cloudflare manual deploy workflow: `../../.github/workflows/cloudflare-pages.yml`

`landing/` remains in place because Firebase and Cloudflare deployment paths currently target it directly.

```

## packages/agent-ui/README.md

```text
# Agent UI Package Boundary

No shared agent UI package exists yet.

Create this only after an operator/agent console has production screens and a tested permission model.

```

## packages/analytics/README.md

```text
# Analytics Package Boundary

Current source of truth:

- Analytics: `../../lib/core/services/firebase_analytics_service.dart`
- Crash/remote config/bootstrap: `../../lib/core/services/firebase_*`
- Push registration: `../../lib/core/services/push_notification_service.dart`

Analytics event names and user properties should be treated as production contracts.

```

## packages/api-clients/README.md

```text
# API Clients Package Boundary

Current source of truth:

- Supabase service clients: `../../lib/core/services`
- Feature API clients: `../../lib/features/*/services`
- Edge Function contracts: `../../supabase/functions`

Client methods should call RPCs or Edge Functions; they should not hide business authorization rules that belong in Supabase RLS/RPCs.

```

## packages/auth/README.md

```text
# Auth Package Boundary

Current source of truth:

- Session and admin guard: `../../lib/core/auth`, `../../lib/core/services/supabase_session_service.dart`
- WhatsApp app login: `../../lib/core/services/whatsapp_login_service.dart`
- Admin OTP login: `../../lib/core/services/otp_service.dart`
- Backend OTP/admin helpers: `../../supabase/functions/_shared`

Server-side authorization remains authoritative. Flutter role helpers are for routing and user experience only.

```

## packages/domain/README.md

```text
# Domain Package Boundary

Current source of truth:

- Trips and pool suggestions: `../../lib/core/services/trip_service.dart`
- Driver location and demand zones: `../../lib/core/services/driver_location_service.dart`
- Profiles and roles: `../../lib/core/services/profile_service.dart`
- Favorite addresses: `../../lib/core/services/favorite_address_service.dart`
- Subscription/catalog logic: `../../lib/core/services/subscription_plan_service.dart`, `../../lib/core/services/vehicle_type_service.dart`

Domain logic should be UI-independent and backed by database/RPC source of truth.

```

## packages/shared-utils/README.md

```text
# Shared Utils Package Boundary

Current source of truth:

- Logging/navigation helpers: `../../lib/core/utils`
- Error mapping: `../../lib/core/errors`
- Pure parsing helpers currently embedded in services.

Only pure utilities with no Flutter widget, Supabase client, platform channel, or feature-state dependency should be extracted here.

```
