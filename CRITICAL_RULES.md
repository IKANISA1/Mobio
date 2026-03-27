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
- The canonical implementation is `AppConstants.getDriverId(String id)` in [`app_constants.dart`](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/core/constants/app_constants.dart), which hashes any string into a 6-digit number.
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

## Rule 3: UI Must Never Be Changed Without Following `design.md`

- The **sole source of truth** for all UI decisions is [`design.md`](file:///Volumes/PRO-G40/MOBI/mobi_app/design.md) — the official "Claymorphic Utility" design system specification.
- **No ad-hoc colors, fonts, spacing, shadows, radii, or component styles may be introduced** that are not defined in `design.md`.
- All UI changes **must reference** the exact token from the design system (color token, typography token, spacing token, shadow token, component spec).
- If a new visual element or pattern is needed, `design.md` **must be updated first** with the new token/spec before any code is written.
- Violating the design system (e.g., using a hardcoded hex color, custom font size, or non-standard border radius) is a **blocking bug** that must be reverted immediately.

### Enforced Design Tokens

| Category | Source Files |
|---|---|
| Colors | `lib/core/theme/app_colors.dart` |
| Typography | `lib/core/theme/app_typography.dart` |
| Shadows | `lib/core/theme/app_shadows.dart` |
| Theme | `lib/core/theme/app_theme.dart` |
| Theme Extension | `lib/core/theme/mobi_theme_extension.dart` |
| Components | `lib/shared/widgets/*` |

---

## Rule 4: Users Are Authenticated Anonymously via Supabase

- All users are authenticated **anonymously** using **Supabase Anonymous Auth** (`signInAnonymously()`).
- There is **no login wall**, no sign-up form, no email/password authentication for regular users.
- Anonymous sign-in happens **automatically at app launch** (splash screen) — the user never sees an auth prompt.
- The anonymous session provides a Supabase UUID used internally for data operations (trips, profiles, BioPay, notifications).
- **Admin access** is the only flow that requires additional verification (WhatsApp OTP) — this is separate from the anonymous session.
- Never introduce a login screen, registration form, or mandatory auth step for the standard user experience.

---

## Quick Reference

| Rule | One-Liner |
|---|---|
| **1. User ID** | 6 numeric digits only — no letters, no UUIDs in UI |
| **2. Default Country** | Rwanda (RW) — always pre-selected, never prompted |
| **3. UI Integrity** | Follow `design.md` exactly — no ad-hoc styles |
| **4. Auth Method** | Supabase anonymous auth — no login wall |
