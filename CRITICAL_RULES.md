# Mobio — Critical Rules (Non-Negotiable)

> [!CAUTION]
> **These rules are absolute laws of the Mobio codebase.**
> They must ALWAYS be followed — no exceptions, no overrides, no "temporary" workarounds.
> Any agent, contributor, or process that violates these rules is producing invalid output.

---

## Rule 1: User IDs Are Always 6 Numeric Digits

- Every user-facing ID (driver ID, passenger ID, display ID) **MUST** be exactly **6 numeric digits** (`000000`–`999999`).
- **No letters.** No alphanumeric. No UUIDs shown to users.
- Internal Supabase UUIDs exist for database operations but are **never displayed** in the UI.
- The canonical value is the server-owned `profiles.member_id`, preserved as a six-digit string, including leading zeros. Display it through `displayMobioMemberId` in `lib/core/utils/mobio_member_id.dart`. Missing IDs show an unavailable label; never hash a UUID or fabricate a replacement ID.
- **Validation rule**: `RegExp(r'^\d{6}$')` — if a user-facing ID doesn't match this pattern, it is a bug.

---

## Rule 2: Rwanda Is the Default Country — Always

- The app **defaults to Rwanda (RW)** in every context: country selection, dialing code, currency, MoMo brand, USSD format.
- Default dialing code: `+250`
- Default currency: `RWF`
- Default MoMo brand: `MTN MoMo`
- Default telecom: `MTN Rwanda`
- If no country is explicitly set, assume Rwanda.
- The `CountryService` fallback **MUST** resolve to `RW`.
- No feature or flow may prompt the user to "choose a country" as a prerequisite — Rwanda is pre-selected.

---

## Rule 3: App, Web and Admin Must Follow `revolut-design` Exactly

- The **sole design authority** is the [external `revolut-design` skill](</Volumes/PRO-G40/Application Data/Codex/Codex-Home/skills/revolut-design/SKILL.md>) and its bundled references. Its selected visual typologies and full applicable colour system govern every Mobio app, web, public website and admin screen and state.
- Preserve Mobio's own name, logo, app icon, supported features, navigation, workflows, content and backend behavior.
- Do not introduce ad-hoc colours, fonts, spacing, shadows, radii or component styles from another reference. Framework controls must use the shared reference-adapted semantic roles rather than leaking default library styling.
- Repository tokens, product mappings, dated comparisons, screenshots and acceptance records are implementation evidence. They are not a second design authority. [The product evidence index](docs/design/README.md) locates them.
- For a missing pattern, consult the applicable skill reference and record its cohort, comparator or explicit adaptation before implementing the shared role. Unknown source values remain explicitly unverified.
- Do not restore deleted local design specifications or introduce competing inspiration. Run `python3 scripts/ci/check_design_authority.py` for design or instruction changes.
- A 100% fidelity result requires complete visual and workflow evidence for the declared scope. Mobile release acceptance additionally follows the skill's `MOBILE-DESIGN-100` rule; build/test success cannot substitute for acceptance.

### Shared Implementation Adapters

| Category | Source Files |
|---|---|
| Colors | `packages/design-system/lib/src/theme/app_colors.dart` |
| Typography | `packages/design-system/lib/src/theme/app_typography.dart` |
| Theme | `packages/design-system/lib/src/theme/app_theme.dart` |
| Theme Extension | `packages/design-system/lib/src/theme/mobi_theme_extension.dart` |
| Components | `lib/shared/widgets/*` |

---

## Rule 4: Passenger and Driver Auth Requires WhatsApp OTP

- Passenger and driver production app routes require **WhatsApp Cloud OTP login**.
- Anonymous Supabase sessions may exist as a technical bootstrap state, but they are treated as unauthenticated for protected passenger/driver flows.
- Admin access uses a **separate** WhatsApp OTP purpose and an allowlisted admin phone number.
- App-login OTPs and admin-login OTPs must never be replayable across flows.
- Server-side RLS, RPCs, and Edge Functions remain the source of truth for authorization. Flutter route guards are not security boundaries.
- Never introduce email/password, unaudited bypasses, or role escalation from the client.

---

## Rule 5: All Four Public Runtime Defines Must Be Set for Every Build

> [!CAUTION]
> **This is the #1 production blocker.** An APK/AAB built without these flags ships a dead app — no auth, no data, no BioPay, nothing works.

- **Every** `flutter build apk`, `flutter build appbundle`, and `flutter run` command **MUST** include all four defines: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `PRIVACY_POLICY_URL` and `ACCOUNT_DELETION_URL`.
- **Never run bare `flutter build appbundle`** — it produces an AAB that crashes on the config-error screen in production.
- The **only** sanctioned way to build a release binary is via the release script:
  ```bash
  ./scripts/release/build_android_release.sh appbundle   # AAB for Play Store
  ./scripts/release/build_android_release.sh apk         # APK for sideloading
  ```
- The script sources `.env` automatically and **hard-fails** if any of the four required public values are missing.
- If building manually (not recommended), the full command is:
  ```bash
  flutter build appbundle --release \
    --dart-define=SUPABASE_URL=https://your-project.supabase.co \
    --dart-define=SUPABASE_ANON_KEY=your-anon-key \
    --dart-define=PRIVACY_POLICY_URL=https://your-domain/privacy-policy.html \
    --dart-define=ACCOUNT_DELETION_URL=https://your-domain/account-deletion.html
  ```
- **Agent enforcement**: Any AI agent or CI pipeline that calls `flutter build apk` or `flutter build appbundle` **without** these `--dart-define` flags is producing **invalid output** and must be stopped immediately.
- Runtime guard: `lib/app/bootstrap.dart` throws `StateError` in release mode if `SupabaseConfig.isConfigured` is `false`. This is intentional — it is better to crash on launch than to ship a silently broken app.

---

## Rule 6: No Automatic Route Computation In Active Marketplace

- Active scheduled-trip posts store route labels and optional coordinates only.
- Mobio must not compute Google-backed ETA, route distance, route duration, route polylines, route matrices, fare-distance basis, automatic dispatch, or route tracking for legacy scheduled-trip posts.
- Do not recommend or enable Google Routes API `computeRoutes`, Google Routes API `computeRouteMatrix`, Directions API, Distance Matrix API, or a custom routing engine for the active marketplace.
- Google Places/Geocoding may be used server-side for place lookup and reverse geocoding.
- Google Maps is used by external deep link handoff for route display, navigation, traffic, route rendering, and trusted vehicle position viewing.
- `maps-gateway` returning `410` for `compute_route` is intentional and must remain guarded by tests.
- Route ETA, distance, duration, polyline, matrix, fare-distance, and dispatch-grade routing are out of context for this app and must never be recommended as Mobio work.

---

## Quick Reference

| Rule | One-Liner |
|---|---|
| **1. User ID** | 6 numeric digits only — no letters, no UUIDs in UI |
| **2. Default Country** | Rwanda (RW) — always pre-selected, never prompted |
| **3. UI Integrity** | External `revolut-design` skill only — app, web, public website and admin |
| **4. Auth Method** | WhatsApp OTP required for passenger/driver app access; admin OTP is separate and allowlisted |
| **5. Build Env Vars** | All four public runtime defines are mandatory on every APK/AAB build — use `./scripts/release/build_android_release.sh` |
| **6. Route Scope** | No route ETA, distance, polyline, matrix, fare-distance, dispatch, or Google Routes API in active marketplace |
