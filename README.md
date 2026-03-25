# MOBI — Mobility Platform (Flutter)

Rwanda-first mobility app with BioPay biometric payments, trip scheduling, and real-time driver discovery.

> [!CAUTION]
> **All APK / AAB builds MUST include Supabase credentials.**
> Builds without these flags will launch in offline-only fallback mode — no auth, no live data, no BioPay.
>
> ```bash
> # Debug
> flutter run \
>   --dart-define=SUPABASE_URL=https://your-project.supabase.co \
>   --dart-define=SUPABASE_ANON_KEY=your-anon-key
>
> # Release APK
> flutter build apk \
>   --dart-define=SUPABASE_URL=https://your-project.supabase.co \
>   --dart-define=SUPABASE_ANON_KEY=your-anon-key
>
> # Release AAB (Play Store)
> flutter build appbundle \
>   --dart-define=SUPABASE_URL=https://your-project.supabase.co \
>   --dart-define=SUPABASE_ANON_KEY=your-anon-key
> ```

## Quick Start

```bash
# Install dependencies
flutter pub get

# Run on connected device (with Supabase)
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key

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
| `MAPS_API_KEY` | Optional | Google Maps Android API key (set in `local.properties` or env) |

## Project Structure

```
lib/
├── core/           # Config, services, theme, utils
├── features/       # Feature screens (home, nearby, bookings, biopay, profile, admin)
├── models/         # Data models
├── shared/         # Reusable widgets
└── main.dart       # App entry point
```

---

## Authentication

- **Anonymous-first**: Supabase anonymous sign-in happens automatically at splash. No login wall.
- **Admin gateway**: Admin access requires WhatsApp OTP verification (separate flow in Profile → Admin).
- All features are accessible without explicit login. Profile is optional.

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
- QR card: white background, MOBI Pay branding, circular dot modules, handle + amount below QR

### Face Enrollment (`face_enrollment_screen.dart`)

- Display name and payment string fields (no mandatory validation)
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
```
