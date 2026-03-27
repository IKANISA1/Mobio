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
| 4 | **Auth = Supabase anonymous** | `signInAnonymously()` at splash. No login wall, no sign-up form. Admin OTP is the only exception. |
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

## Build-Time Variables

| Variable | Required | Purpose |
|----------|----------|---------|
| `SUPABASE_URL` | **Yes** | Supabase project URL |
| `SUPABASE_ANON_KEY` | **Yes** | Supabase anonymous key |
| `PRIVACY_POLICY_URL` | **Yes** | Public privacy-policy URL used in-app and for Play review |
| `MAPS_API_KEY` | Optional | Google Maps Android API key (set in `local.properties` or env) |

## Android Release Signing

- Release Android builds use the standard Gradle `android/key.properties` contract.
- CI writes `android/key.properties` and `android/app/release.keystore` from GitHub secrets at build time via `./scripts/ci/write_android_signing_files.sh`.
- Do not commit `android/key.properties` or release keystores to the repo.
- Local release builds can source `.env` and fail fast on missing inputs via `./scripts/release/build_android_release.sh appbundle`.
- Google Play submission should use the AAB output, not the APK.

## Backend Source Of Truth

- The tracked backend for this repo lives in [`supabase/`](./supabase).
- All migrations, edge functions, and CLI deploys must be run from the repo root: `mobi_app/supabase`.
- If you are working inside a larger workspace that also has a sibling `../supabase`, treat this repo-local `supabase/` directory as canonical and sync outward from it. Do not revive older nested-only migrations or OTP functions.
- CI can lint the linked hosted project when `SUPABASE_ACCESS_TOKEN` and `SUPABASE_PROJECT_REF` are configured in GitHub Actions secrets.

## Project Structure

```
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

- **Anonymous-first**: Supabase anonymous sign-in (`signInAnonymously()`) happens automatically at splash. No login wall, no sign-up form, no email/password — ever.
- **Admin gateway**: Admin access requires WhatsApp OTP verification against a pre-authorized admin phone (separate flow in Profile → Admin). This is the only auth escalation in the entire app.
- All features are accessible without explicit login. Profile is optional.
- User-facing IDs are always **6 numeric digits** (derived from internal UUIDs via `AppConstants.getDriverId()`). Internal Supabase UUIDs are never exposed in the UI.

### Bootstrap A Persistent Admin

Use the repo-local admin bootstrap script when you need to provision the first real admin on a project:

```bash
SUPABASE_URL=https://your-project.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key \
ADMIN_PHONE=+250788000000 \
ADMIN_NAME="Admin MOBI" \
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
