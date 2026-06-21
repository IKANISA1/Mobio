# Mobio — Mobility Platform (Flutter)

Rwanda-first mobility app with BioPay biometric payments, trip scheduling, and real-time driver discovery.

> [!CAUTION]
> **All APK / AAB builds MUST include Supabase credentials.**
> Builds without these flags will stop on the config-error screen — no auth, no live data, no BioPay.
>
> ```bash
> # Debug
> flutter run \
>   --dart-define=SUPABASE_URL=https://your-project.supabase.co \
>   --dart-define=SUPABASE_ANON_KEY=your-anon-key \
>   --dart-define=PRIVACY_POLICY_URL=https://your-public-domain/privacy-policy.html
>
> # Release APK
> flutter build apk \
>   --dart-define=SUPABASE_URL=https://your-project.supabase.co \
>   --dart-define=SUPABASE_ANON_KEY=your-anon-key \
>   --dart-define=PRIVACY_POLICY_URL=https://your-public-domain/privacy-policy.html
>
> # Release AAB (Play Store)
> flutter build appbundle \
>   --dart-define=SUPABASE_URL=https://your-project.supabase.co \
>   --dart-define=SUPABASE_ANON_KEY=your-anon-key \
>   --dart-define=PRIVACY_POLICY_URL=https://your-public-domain/privacy-policy.html
> ```

---

## ⛔ Critical Rules (Non-Negotiable)

> **Full document: [`CRITICAL_RULES.md`](./CRITICAL_RULES.md)**
> These rules are absolute laws — no exceptions, no overrides, no temporary workarounds.

| # | Rule | Summary |
|---|------|---------|
| 1 | **User IDs = 6 numeric digits** | No letters, no UUIDs in UI. Always `\d{6}`. See `AppConstants.getDriverId()`. |
| 2 | **Default country = Rwanda (RW)** | Pre-selected everywhere: dialing code `+250`, currency `RWF`, MoMo `MTN MoMo`. Never prompt user to choose. |
| 3 | **UI = `design.md` only** | No ad-hoc styles. Every color, font, spacing, shadow, and component MUST follow [`design.md`](./design.md). Update the spec first, then code. |
| 4 | **Auth = WhatsApp OTP** | Passenger/driver app access requires WhatsApp Cloud OTP. Admin OTP is separate and allowlisted. |
| 5 | **Build env vars = mandatory** | Every `flutter build apk/appbundle` **MUST** pass `--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_ANON_KEY=...`. Use `./scripts/release/build_android_release.sh`. |

---

## Quick Start

```bash
# Install dependencies
flutter pub get

# Run on connected device (with Supabase)
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=PRIVACY_POLICY_URL=https://your-public-domain/privacy-policy.html

# Run analysis
flutter analyze

# Run tests
flutter test
```

## Firebase Infrastructure

- Firebase is infrastructure only in this repo: Hosting, Analytics, Crashlytics, Cloud Messaging, and Remote Config.
- Supabase remains the system of record, auth layer, realtime backend, and application data source.
- The Firebase project wired to the repo is `gen-lang-client-0172279957` (`1074154147498`).
- Android is already registered and checked in via [`android/app/google-services.json`](./android/app/google-services.json).
- Firebase Hosting deploys the static marketing/privacy site from [`landing/`](./landing).

### What The Repo Now Expects

- `firebase_core`, `firebase_crashlytics`, `firebase_messaging`, `firebase_analytics`, and `firebase_remote_config` are installed in Flutter.
- `firebase_auth` is initialized as Firebase-only infrastructure support; it does not replace Supabase auth.
- Firebase boots before the rest of the app, but the app keeps running if a platform is not configured yet.
- Crashlytics and Analytics collection are gated by Remote Config so Firebase can stay operationally optional.
- Push registration is gated by both platform support and Remote Config so it does not interfere with the Supabase product flows.
- Firebase Auth attempts an anonymous bootstrap session by default. Disable that with `--dart-define=FIREBASE_ENABLE_ANONYMOUS_AUTH=false` if you want SDK init only.

### Current CLI Status

The local Firebase CLI session is stale for project-management commands. Before generating missing iOS/Web app registrations, re-authenticate:

```bash
firebase login --reauth
flutterfire configure \
  --yes \
  --project=gen-lang-client-0172279957 \
  --platforms=android,ios,web \
  --android-package-name=rw.mobi.app \
  --ios-bundle-id=rw.mobi.app
```

The codebase is already prepared for that command. Until then:

- Android works from the checked-in app registration.
- iOS can be bootstrapped with `--dart-define=FIREBASE_IOS_APP_ID=...`.
- Web can be bootstrapped with `--dart-define=FIREBASE_WEB_APP_ID=...` and optionally `--dart-define=FIREBASE_WEB_MEASUREMENT_ID=...`.
- If you want the anonymous Firebase Auth bootstrap to succeed, enable the Anonymous provider in the Firebase Console for this project.

### Remote Config Keys Supported By The App

- `analytics_enabled`
- `crashlytics_enabled`
- `push_notifications_enabled`
- `maintenance_mode_enabled`
- `maintenance_mode_message`
- `landing_download_android_url`
- `landing_download_ios_url`
- `support_whatsapp_number`

### Hosting

The checked-in [`firebase.json`](./firebase.json) now deploys the `landing/` directory through Firebase Hosting.

```bash
firebase deploy --only hosting --project gen-lang-client-0172279957
```

## Build-Time Variables

| Variable | Required | Purpose |
|----------|----------|---------|
| `SUPABASE_URL` | **Yes** | Supabase project URL |
| `SUPABASE_ANON_KEY` | **Yes** | Supabase anonymous key |
| `PRIVACY_POLICY_URL` | **Yes** | Public privacy-policy URL used in-app and for Play review |
| `MAPS_API_KEY` | Optional | Legacy/native Google Maps key placeholder only. The active app does not embed Google Maps or use the Google Routes API. |

## Google Maps And Route Scope

Mobio intentionally does **not** compute routes, ETAs, route distance,
duration, fare-distance basis, route polylines, or driver/passenger route
matrices. Do not recommend or add Google Routes API `computeRoutes`, Google
Routes API `computeRouteMatrix`, Directions API, Distance Matrix API, or a
custom route engine for the active scheduled-trip marketplace.

The approved implementation is:

- Store user-entered route labels and optional coordinates for scheduled trip
  posts.
- Use Google Places/Geocoding only for place lookup and reverse geocoding
  through the server-side Supabase `maps-gateway`.
- Open external Google Maps deep links when a user wants map display,
  navigation, traffic, route rendering, or current vehicle position viewing.
- Keep fares, timing, and pickup coordination manually agreed between users in
  chat or WhatsApp for legacy scheduled-trip posts.

The backend enforces this boundary: `maps-gateway` returns `410` for
`compute_route`, and release tests guard that route computation remains absent.
Route ETA, route distance, route duration, route polyline, route matrix,
fare-distance basis, and dispatch-grade routing are out of context for this app.
They must not be introduced into Mobio documentation, code, schema, release
gates, API enablement, or store copy.

## Location Permission Scope

Mobio uses foreground location for nearby discovery and pickup autofill.
Driver live sharing is a separate driver-only flow: when a driver explicitly
turns online, the app shows a prominent live-location disclosure, requests
foreground location, starts an OS-visible foreground location stream, and
publishes fresh coordinates to `driver_locations`. The app must not use
background location for passenger discovery, analytics, advertising, route
history, fare distance, or hidden tracking.

### Google/Firebase Release Evidence Gates

Production go/no-go uses non-secret evidence files for Google/Firebase
readiness. Do not paste API keys or service-account JSON into docs. Set these
environment variables only after the named evidence file exists:

| Variable | Evidence required |
|----------|-------------------|
| `GOOGLE_MAPS_SERVER_SECRET_VALIDATED=true` plus `GOOGLE_MAPS_SERVER_SECRET_EVIDENCE=/path/to/file.md` | Supabase `maps-gateway` has `GOOGLE_MAPS_SERVER_API_KEY` configured; no Gemini or client Maps key is accepted for server Maps calls. |
| `FCM_HTTP_V1_SECRET_VALIDATED=true` plus `FCM_HTTP_V1_SECRET_EVIDENCE=/path/to/file.md` | `send-push` deployment has FCM HTTP v1 service-account secrets configured. |
| `IOS_FIREBASE_APNS_VALIDATED=true` plus `IOS_FIREBASE_APNS_EVIDENCE=/path/to/file.md` | iOS Firebase app registration, bundle id, APNs capability, and APNs key/certificate setup were verified. |
| `IOS_CRASHLYTICS_SYMBOLS_VALIDATED=true` plus `IOS_CRASHLYTICS_SYMBOLS_EVIDENCE=/path/to/file.md` | iOS Crashlytics dSYM upload was verified for the release build. |

The current Google/Firebase implementation inventory and required SDK/API work
is tracked in [`docs/reports/google_api_sdk_findings.md`](./docs/reports/google_api_sdk_findings.md).

## Android Release Signing

- Release Android builds use the standard Gradle `android/key.properties` contract.
- CI writes `android/key.properties` and `android/app/release.keystore` from GitHub secrets at build time via `./scripts/ci/write_android_signing_files.sh`.
- Do not commit `android/key.properties` or release keystores to the repo.
- Local release builds can source `.env` and fail fast on missing inputs via `./scripts/release/build_android_release.sh appbundle`.
- Google Play submission should use the AAB output, not the APK.

## GitHub Actions

- [`ci.yml`](./.github/workflows/ci.yml) runs Flutter verification on pushes, pull requests, and manual dispatches, then builds a release AAB with the configured runtime defines.
- [`release.yml`](./.github/workflows/release.yml) runs on version tags and manual dispatches, builds a signed AAB, uploads release artifacts, pushes a draft Play Store release, and creates a GitHub release.
- The release workflow is bound to the `Mobio` GitHub environment.

### Repository Variables

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_PROJECT_REF`
- `PRIVACY_POLICY_URL`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_PROJECT_NUMBER`
- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_PAGES_PROJECT_NAME`
- `CLOUDFLARE_PAGES_DEFAULT_URL`
- `CLOUDFLARE_PAGES_PRODUCTION_URL`
- `CLOUDFLARE_PAGES_CLIENT_PROJECT_NAME`
- `CLOUDFLARE_PAGES_CLIENT_URL`
- `CLOUDFLARE_PAGES_ADMIN_PROJECT_NAME`
- `CLOUDFLARE_PAGES_ADMIN_URL`

### Repository Secrets

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_SERVICE_ROLE_KEY`
- `KEYSTORE_BASE64`
- `KEY_ALIAS`
- `KEY_PASSWORD`
- `STORE_PASSWORD`
- `PLAY_STORE_SERVICE_ACCOUNT_JSON`
- `CLOUDFLARE_API_TOKEN`

### Mobio Environment

- The `Mobio` environment mirrors the production release variables and secrets used by `release.yml`.
- Keep signing credentials and Play publishing credentials in `Mobio` if you later narrow repository-level secret scope.
- Cloudflare Pages production is already wired to the `mobio` project on branch `main`.
- [`cloudflare-pages.yml`](./.github/workflows/cloudflare-pages.yml) is a manual GitHub override for redeploying the static `landing/` site without changing Cloudflare's existing automatic Git deployments.
- [`cloudflare-pwa.yml`](./.github/workflows/cloudflare-pwa.yml) builds the Flutter web app, prepares separate client/admin PWA bundles, and deploys them to Cloudflare Pages on demand.

## Cloudflare PWA Domains

- `mobio.ikanisa.com` remains the marketing and privacy site, backed by the `mobio` Pages project and the repo's `landing/` directory.
- `mobioapp.ikanisa.com` is reserved for the passenger/driver Flutter PWA bundle.
- `mobioadmin.ikanisa.com` is reserved for the admin Flutter PWA bundle.
- The admin bundle injects a root redirect to `/admin-auth` and sets the PWA manifest start URL accordingly.
- Both PWA bundles ship a Cloudflare Pages SPA fallback via `_redirects` so `/admin`, `/admin-auth`, and other GoRouter paths can be refreshed directly.
- Use [`scripts/web/prepare_pwa_bundles.sh`](./scripts/web/prepare_pwa_bundles.sh) to build the two web bundles locally.
- Use [`scripts/web/deploy_cloudflare_pwas.sh`](./scripts/web/deploy_cloudflare_pwas.sh) to deploy both PWAs from a local Wrangler-authenticated machine.

## Backend Source Of Truth

- The tracked backend for this repo lives in [`supabase/`](./supabase).
- All migrations, edge functions, and CLI deploys must be run from the repo root: `mobi_app/supabase`.
- If you are working inside a larger workspace that also has a sibling `../supabase`, treat this repo-local `supabase/` directory as canonical and sync outward from it. Do not revive older nested-only migrations or OTP functions.
- CI can lint the linked hosted project when `SUPABASE_ACCESS_TOKEN` and `SUPABASE_PROJECT_REF` are configured in GitHub Actions secrets.

## Project Structure

The repo is being migrated toward documented monorepo boundaries while keeping active Flutter/Supabase paths stable. See [`docs/architecture/monorepo_structure.md`](./docs/architecture/monorepo_structure.md) for the target structure and migration phases.

```
apps/              # Boundary docs for mobile, PWA, admin, website, future app surfaces
packages/          # Boundary docs for future shared Dart/domain packages
agents/            # Agent policy/workspace/channel boundary docs
integrations/      # External channel/payment integration boundary docs
docs/              # Architecture, product, security, release, testing, operations docs
infra/             # CI/config/monitoring boundary docs

lib/
├── core/           # Config, services, theme, utils
├── features/       # Feature screens (home, nearby, bookings, biopay, profile, admin)
├── models/         # Data models
├── shared/         # Reusable widgets
└── main.dart       # App entry point

supabase/
├── config.toml     # Supabase CLI project config
├── functions/      # Edge functions (OTP, BioPay, maps, chat, promo)
├── migrations/     # Canonical schema + RPC migrations
└── seed.sql        # Local seed data
```

---

## Authentication

- **Passenger/driver app login**: protected app routes require WhatsApp Cloud OTP login. Anonymous Supabase sessions are treated as unauthenticated for production passenger/driver flows.
- **Admin gateway**: admin access requires a separate WhatsApp OTP verification against a pre-authorized admin phone. Admin OTP purpose is isolated from passenger/driver login OTP purpose.
- Server-side RPCs and RLS remain authoritative for permissions; Flutter route guards only improve user experience.
- User-facing IDs are always **6 numeric digits** (derived from internal UUIDs via `AppConstants.getDriverId()`). Internal Supabase UUIDs are never exposed in the UI.

### Bootstrap A Persistent Admin

Use the repo-local admin bootstrap script when you need to provision the first real admin on a project:

```bash
export SUPABASE_URL="https://your-project.supabase.co"
read -rsp "SUPABASE service-role key: " SUPABASE_SERVICE_ROLE_KEY
export SUPABASE_SERVICE_ROLE_KEY
ADMIN_PHONE=+250788000000 ADMIN_NAME="Admin MOBI" \
  deno run --allow-env --allow-net scripts/admin/bootstrap_admin.ts
```

- The script creates or reuses the auth user, marks it as admin, and upserts the matching `profiles` row.
- `ADMIN_EMAIL` is optional. By default it derives `admin+<digits>@mobi.internal`.
- `ADMIN_PASSWORD` is optional. If omitted, the script prints a generated one for the initial bootstrap only.

---

## BioPay — Architecture & Rules

BioPay is a **standalone, validation-free** feature set. It requires no authentication, no profile, and no enforcements.

### Core Principles

| Principle | Rule |
|-----------|------|
| **No auth gate** | BioPay hub and all sub-screens load without Supabase session |
| **No profile dependency** | QR generation and face scanning work without a user profile |
| **No enforcements** | No consent checkboxes, no mandatory fields, no form validation |
| **Independent handles** | MoMo number for QR ≠ MoMo number for face identity |

### Independent MoMo Handles

> [!IMPORTANT]
> The MoMo number used for **QR code generation** is completely separate from the MoMo number **linked to a face identity**. They can be the same or different — the user controls both independently.

| Context | Where | Behavior |
|---------|-------|----------|
| **Get QR Code** | Editable `TextField` on Get QR screen | User types any number/code. Can generate QR for self or others. |
| **Face Registration** | "Payment string" field on Face Enrollment screen | Linked to biometric identity during face capture. |
| **Edit Profile** | Optional MoMo handle in profile settings | Profile-level default. Not enforced anywhere. |

### Screen Architecture

```
BioPay Hub (pure navigation — no data loading)
├── Get QR Code       → Editable handle + amount → QR generation
├── Scan QR Code      → Camera-based QR scanner
└── Face Scan         → Camera-based face recognition (no auth required)

Face Registration     → Enrollment form + 5-sample face capture
└── Face Enrollment   → ML pipeline (FaceNet embeddings)
```

### BioPay Hub (`biopay_screen.dart`)

- **Pure navigation screen** — no `BioPayService` dependency, no loading state
- Brand header ("BioPay" + shield icon) + 3 action tiles with subtitles
- No identity card, no central MoMo number display
- No `RefreshIndicator` — nothing to refresh

### Get QR Screen (`get_qr_screen.dart`)

- **Fully decoupled** from `BioPayService`
- Number/Code toggle with pill selector
- Handle `TextField` starts empty; placeholder updates per type:
  - Number mode: `0781234567`
  - Code mode: `123456`
- Switching types clears the field
- Amount input with **thousand-separator formatting** (e.g., `12,345`)
- QR card: white background, Mobio Pay branding, circular dot modules, handle + amount below QR

### Face Enrollment (`face_enrollment_screen.dart`)

- Payment string field (no mandatory validation)
- Consent checkbox present but not enforced
- 5-sample face capture with quality checks (size, yaw, eyes, lighting)
- FaceNet-based embedding pipeline (on-device ML)
- `_ussdController` is independent from Get QR's handle

### Face Scan (`face_scan_screen.dart`)

- **Free feature** — accessible to all, no registration required
- Camera-based face detection for pay-by-face

---

## UI/UX Rules

### Design System

- **Dark theme** throughout (`AppColors.background: #0C0F10`)
- Rounded containers (radius 28–40) with subtle white borders (`alpha: 0.03–0.09`)
- Typography: `Manrope` (headings), `Inter` (body/labels) via Google Fonts
- BioPay accent: `AppColors.bioPayGreen`
- Components: `ClayCard`, `MobiButton`, `MobiBottomNav`

### Navigation

- 3-tab bottom nav: **Discover** / **BioPay** / **Profile**
- State-machine routing in `app.dart` (no `Navigator.push`) — all screens are flat overlays
- `PopScope` handles Android back button with correct state unwinding
- Splash → main transition uses `addPostFrameCallback` to avoid navigator lock

### Edit Profile — MoMo Section

- Section header shows country's MoMo brand name (e.g., "MTN MoMo"), falls back to "MOBILE MONEY"
- Number/Code toggle (pill selector)
- Code placeholder: `123456` (not merchant codes)
- Handle values are optional — save without validation

---

## Testing

```bash
# Static analysis
flutter analyze

# BioPay ML pipeline tests (9 tests)
flutter test test/features/biopay/

# All tests
flutter test

# Backend contract checks (edge functions + optional linked lint)
./scripts/ci/verify_backend.sh
```
