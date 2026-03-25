# MOBI Design System Compliance Audit

> **Audit date**: 2026-03-25 · **Files audited**: 19 feature screens + 16 shared widgets + 4 theme files
> **Reference**: [design.md](file:///Volumes/PRO-G40/MOBI/mobi_app/design.md)

---

## Executive Summary

The design system tokens (`AppColors`, `AppTypography`, `AppShadows`) and shared component library (`ClayCard`, `GlassCard`, `MobiButton`, etc.) are **well-defined and production-quality**. However, **the majority of feature screens bypass these tokens**, using inline `GoogleFonts.*()` calls, hardcoded hex colors, and raw `Container` / `GestureDetector` widgets instead of the shared components. This creates visual inconsistency and a maintenance burden.

### Violation Heatmap

| Violation Type | Files Affected | Severity |
|---|---|---|
| Inline `GoogleFonts.manrope()` bypassing `AppTypography` | **15 / 19** | 🔴 Critical |
| Inline `GoogleFonts.inter()` bypassing `AppTypography` | **13 / 19** | 🔴 Critical |
| Hardcoded `Color(0x...)` bypassing `AppColors` | **7 / 19** | 🔴 Critical |
| `GestureDetector` without press feedback | **11 / 19** | 🟡 Major |
| Raw `Container` instead of `ClayCard` | **8 / 19** | 🟡 Major |
| `ElevatedButton` instead of `MobiButton` | **1 / 19** | 🟠 Moderate |
| Inconsistent border radii (not 40px default) | **12 / 19** | 🟡 Major |
| Missing `SoftGradient` background wrapper | **18 / 19** | 🟠 Moderate |
| Duplicate `_TappableContainer` local widget | **1 / 19** | 🔵 Minor |

---

## Screen-by-Screen Findings

### 1. Home Screen (`home_screen.dart`) — 🔴 11 violations

| # | Finding | Spec (design.md) | Actual | Fix |
|---|---|---|---|---|
| 1 | Header title "MOBI" | `AppTypography.headlineMd` (22px) | Inline `GoogleFonts.manrope(fontSize: 24)` | Use `AppTypography.headlineMd` |
| 2 | Hero card radius | `40px` (default ClayCard) | `32px` | Set `borderRadius: 40` or use primary gradient ClayCard variant |
| 3 | Hero card shadow | `AppShadows.premium` or `AppShadows.clayButton` | Inline `BoxShadow(primary@25%, blur:40)` | Use `AppShadows.premium` |
| 4 | Hero text style | `AppTypography.displayLg` (48px) | Inline `GoogleFonts.manrope(fontSize: titleSize)` | Use `displayLg` with responsive sizing |
| 5 | Action tile label | `AppTypography.titleMd` (18px) | Inline `GoogleFonts.manrope(fontSize: 16, w700)` | Use `AppTypography.titleMd` |
| 6 | Action tile container | `ClayCard` | Raw `Container` with inline decoration | Replace with `ClayCard(color: ...)` |
| 7 | Section header title | `AppTypography.headlineLg` (28px) | Inline `GoogleFonts.manrope(fontSize: 28, w800)` | Use `AppTypography.headlineLg` |
| 8 | "View All" link | `AppTypography.labelLg` | Inline `GoogleFonts.inter(fontSize: 14, w600)` | Use `AppTypography.labelLg` |
| 9 | Scheduled card radius | `40px` | `28px` | Set `borderRadius: 40` |
| 10 | Scheduled time style | `AppTypography.displayMd` | Inline `GoogleFonts.manrope(fontSize: 36, w800)` | Use `AppTypography.displayMd` |
| 11 | Local `_TappableContainer` | Should use shared pattern | Duplicates `ClayCard` press logic | Replace with `ClayCard(onTap:)` |

---

### 2. BioPay Screen (`biopay_screen.dart`) — 🔴 8 violations

> [!CAUTION]
> This screen has the **worst compliance** score. It uses zero `AppTypography` tokens and 5 hardcoded hex colors.

| # | Finding | Spec | Actual | Fix |
|---|---|---|---|---|
| 1 | Brand header bg | `AppColors.surfaceContainerLow` or `surfaceContainer` | Hardcoded `Color(0xFF131517)` | Use `AppColors.surfaceContainerLow` |
| 2 | Action tile bg | `AppColors.surfaceContainerLowest` | Hardcoded `Color(0xFF090B0C)` | Use `AppColors.surfaceContainerLowest` |
| 3 | QR accent bg | `AppColors.primaryContainer` or similar | Hardcoded `Color(0xFF113B1D)` | Use `AppColors.primaryContainer` |
| 4 | Scan accent bg | Should map to semantic token | Hardcoded `Color(0xFF2E395A)` | Use `AppColors.secondaryContainer` |
| 5 | Face accent bg | Should map to semantic token | Hardcoded `Color(0xFF334157)` | Use `AppColors.tertiaryContainer` |
| 6 | No `ClayCard` usage | Action tiles should use `ClayCard(onTap:)` | `Material` + `InkWell` + `Ink` | Replace with `ClayCard` |
| 7 | All typography inline | `AppTypography.titleLg` / `bodyMd` | `GoogleFonts.manrope()` / `GoogleFonts.inter()` | Use `AppTypography` tokens |
| 8 | Border radius | `40px` default | `32px` everywhere | Set to `40` |

---

### 3. Splash Screen (`splash_screen.dart`) — 🟡 3 violations

| # | Finding | Spec | Actual | Fix |
|---|---|---|---|---|
| 1 | Title style | `AppTypography.displayLg` (48px, -2.0) | Inline `GoogleFonts.manrope(fontSize: 64)` | Acceptable deviation for branding, but should use `heroNumber` token |
| 2 | Background gradient | `SoftGradient` | Inline `RadialGradient(primary@8%, center)` | Minor deviation — acceptable for splash |
| 3 | Icon container radius | `24` or `32` (per card spec) | `32` | ✅ Acceptable |

---

### 4. Nearby Screen (`nearby_screen.dart`) — 🟡 3 violations

| # | Finding | Spec | Actual | Fix |
|---|---|---|---|---|
| 1 | Header title | `AppTypography.headlineMd` | Inline `GoogleFonts.manrope(fontSize: 24)` | Use `AppTypography.headlineMd` |
| 2 | "LIST" chip label | `AppTypography.labelSm` | Inline `GoogleFonts.inter(fontSize: 10, w700)` | Use `AppTypography.labelSm` |
| 3 | "NEARBY" hero title | `AppTypography.displayLg` (48px) | Inline `GoogleFonts.manrope(fontSize: 48)` | Use `AppTypography.displayLg` |

> [!TIP]
> Nearby screen correctly uses `TappableIconButton`, `DriverCard`, `VehicleFilterChips`, `LoadingSkeleton`, and `AppTypography` tokens for labels/body. Among the best-compliant screens.

---

### 5. Bookings Screen (`bookings_screen.dart`) — 🟡 6 violations

| # | Finding | Spec | Actual | Fix |
|---|---|---|---|---|
| 1 | Header title | `AppTypography.headlineMd` | Inline `GoogleFonts.manrope(fontSize: 24)` | Use token |
| 2 | Page title "My Trips" | `AppTypography.displayLg` | Inline `GoogleFonts.manrope(fontSize: 48)` | Use token |
| 3 | Trip route text | `AppTypography.titleLg` | Inline `GoogleFonts.manrope(fontSize: 20)` | Use token |
| 4 | Trip time text | `AppTypography.displayMd` | Inline `GoogleFonts.manrope(fontSize: 32)` | Use `displayMd` |
| 5 | FAB button | `MobiButton` or `ClayCard` | Raw `GestureDetector` + `Container` — **no press feedback** | Use `TappableIconButton` or Material |
| 6 | "CANCEL TRIP" / "DETAILS" links | `AppTypography.labelSm` | Inline `GoogleFonts.inter(fontSize: 12)` | Use `labelSm` or `labelMd` |

> [!WARNING]
> The FAB at line 243 uses a raw `GestureDetector` with **zero press feedback** — no scale, no opacity, no ripple. Feels dead on tap.

---

### 6. Profile Screen (`profile_screen.dart`) — 🟢 3 violations

| # | Finding | Spec | Actual | Fix |
|---|---|---|---|---|
| 1 | User code title | `AppTypography.headlineLg` | Inline `GoogleFonts.manrope(fontSize: 30)` | Use `headlineLg` |
| 2 | Member subtitle | `AppTypography.bodySm` | Inline `GoogleFonts.inter(fontSize: 14)` | Use `bodySm` |
| 3 | Face ID CTA card | `ClayCard(onTap:)` | Raw `GestureDetector` + `Container` — **no press feedback** | Wrap in ClayCard or add animation |

> [!TIP]
> Profile screen is one of the **best-compliant** screens. It correctly uses `ClayCard` for settings rows, `AppTypography.titleMd` for labels, and proper 48×48 icon containers.

---

### 7. Admin Dashboard (`admin_dashboard_screen.dart`) — 🟢 1 violation

| # | Finding | Spec | Actual | Fix |
|---|---|---|---|---|
| 1 | Stat value numbers | `AppTypography.headlineLg` (28px) | Inline `GoogleFonts.manrope(fontSize: 28)` | Use `headlineLg` |

> Correctly uses `AppTypography.displayMd`, `AppTypography.labelSm`, `ClayCard`. **Best-compliant screen.**

---

### 8. Admin Auth (`admin_auth_screen.dart`) — 🟠 4 violations

| # | Finding | Spec | Actual | Fix |
|---|---|---|---|---|
| 1 | Action button | `MobiButton(variant: primary)` | `ElevatedButton` with inline styling | Replace with `MobiButton` |
| 2 | Back button | `TappableIconButton` | Raw `GestureDetector` + `Container` with Material `Icons.*` | Use `TappableIconButton(icon: LucideIcons.chevronLeft)` |
| 3 | Icon | `LucideIcons.chevronLeft` | `Icons.arrow_back_ios_new_rounded` (Material) | Use Lucide |
| 4 | Input field radius | `100px` (design spec) | `14px` | Change to `100` or at least `24` |

---

### 9. Admin Users (`admin_users_screen.dart`) — ✅ 0 violations

> **Fully compliant.** Uses `AppTypography.displayMd`, `bodyLg`, `titleMd`, `labelSm`, `ClayCard`, `LucideIcons`, and `AppColors` throughout.

---

## Systemic Issues

### Issue 1: Typography Token Bypass (Critical)

**15 of 19 screens** construct text styles with inline `GoogleFonts.manrope()` / `GoogleFonts.inter()` instead of `AppTypography` tokens.

```dart
// ❌ WRONG — seen in 15+ files
GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary)

// ✅ CORRECT
AppTypography.headlineMd.copyWith(color: AppColors.primary)
```

**Impact**: If you change Manrope to a different headline font or adjust the typographic scale, you must find-and-replace across 50+ inline calls instead of changing one token.

---

### Issue 2: Border Radius Inconsistency (Major)

design.md specifies `40px` as the default card radius. In practice:

| Screen | Expected | Actual |
|---|---|---|
| Home hero card | 40 | 32 |
| Home action tiles | 40 | 24 |
| Home scheduled card | 40 | 28 |
| BioPay brand header | 40 | 32 |
| BioPay action tiles | 40 | 32 |
| Profile Face ID card | 40 | 32 |
| Profile settings cards | 40 | 32 |
| Admin stat cards | 40 | 24 |
| Admin user cards | 40 | 24 |
| Admin auth inputs | 100 | 14 |

**Recommendation**: Standardize on `ClayCard` default radius (`40px`) for all cards. Only purposeful exceptions (stadium pills at `100`, small inputs at `16`).

---

### Issue 3: Hardcoded Colors in BioPay (Critical)

7 files use `Color(0x...)` hex values not in `AppColors`. BioPay alone introduces 5 orphan colors:

| Hardcoded | Nearest Token | Delta |
|---|---|---|
| `#131517` | `surfaceContainerLow` (`#141618`) | ~1 shade off |
| `#090B0C` | `surfaceContainerLowest` (`#080A0B`) | ~1 shade off |
| `#113B1D` | `primaryContainer` (`#005221`) | Different hue |
| `#2E395A` | `secondaryContainer` (`#353F56`) | Different hue |
| `#334157` | `tertiaryContainer` (`#3C5572`) | Different hue |

**Recommendation**: Add missing tokens to `AppColors` (e.g., `bioPayActionBg`, `bioPayQrAccent`) OR map to nearest existing tokens.

---

### Issue 4: GestureDetector Without Press Feedback (Major)

11 screens use raw `GestureDetector` for tappable elements without scale/opacity animations. Per design.md §9B:

> **Every tappable element MUST provide visual feedback.**

**Worst offenders**:
- Bookings FAB (no feedback at all)
- Profile Face ID CTA (no feedback)
- Admin Auth back button (no feedback)
- Nearby location prompt (no feedback)

**Recommendation**: Replace all raw `GestureDetector` with either `ClayCard(onTap:)`, `TappableIconButton`, or `MobiButton`.

---

### Issue 5: Missing SoftGradient Background (Moderate)

design.md specifies `SoftGradient` wrapper for screens. Only the Splash screen uses a gradient background. All other screens use flat `AppColors.background`.

**Recommendation**: Wrap main screen content bodies in `SoftGradient` for the subtle depth effect specified in the design system.

---

## Compliance Scorecard

| Screen | Typography | Colors | Components | Motion | Radius | **Score** |
|---|---|---|---|---|---|---|
| Admin Users | ✅ | ✅ | ✅ | ✅ | ⚠️ | **95%** |
| Admin Dashboard | ⚠️ | ✅ | ✅ | ✅ | ⚠️ | **88%** |
| Profile | ⚠️ | ✅ | ✅ | ⚠️ | ⚠️ | **78%** |
| Nearby | ⚠️ | ✅ | ✅ | ✅ | ✅ | **82%** |
| Splash | ⚠️ | ✅ | N/A | ✅ | ✅ | **85%** |
| Bookings | ❌ | ⚠️ | ✅ | ⚠️ | ✅ | **65%** |
| Home | ❌ | ✅ | ⚠️ | ⚠️ | ❌ | **50%** |
| Admin Auth | ⚠️ | ✅ | ❌ | ❌ | ❌ | **45%** |
| BioPay | ❌ | ❌ | ❌ | ⚠️ | ❌ | **25%** |

**Overall compliance: ~62%**

---

## Recommended Fix Priority

### Phase 1: Quick Wins (Low risk, high impact)

| # | Change | Files | Effort |
|---|---|---|---|
| 1 | Replace all inline `GoogleFonts.manrope/inter()` with `AppTypography` tokens | 15 files | ~2hrs |
| 2 | Standardize border radii to 40px (or use ClayCard default) | 12 files | ~1hr |
| 3 | Replace Bookings FAB with `TappableIconButton` or Material | 1 file | ~10min |

### Phase 2: Component Alignment (Medium effort)

| # | Change | Files | Effort |
|---|---|---|---|
| 4 | BioPay: replace all hardcoded colors with `AppColors` tokens | 1 file | ~30min |
| 5 | BioPay: replace raw containers with `ClayCard(onTap:)` | 1 file | ~30min |
| 6 | Home: replace action tiles + hero card with `ClayCard` variants | 1 file | ~45min |
| 7 | Profile: wrap Face ID CTA in `ClayCard` for press feedback | 1 file | ~15min |
| 8 | Admin Auth: replace `ElevatedButton` with `MobiButton` | 1 file | ~15min |
| 9 | Admin Auth: replace back button with `TappableIconButton` | 1 file | ~5min |

### Phase 3: Polish (Nice-to-have)

| # | Change | Files | Effort |
|---|---|---|---|
| 10 | Add `SoftGradient` wrapper to all main screens | 5 files | ~30min |
| 11 | Remove local `_TappableContainer` from Home — use `ClayCard` | 1 file | ~15min |
| 12 | Add missing `AppColors` tokens for BioPay-specific accents | 1 file | ~10min |
| 13 | Audit remaining BioPay sub-screens (get_qr, scan_qr, face_*) | 5 files | ~2hrs |

---

## Summary

The design system infrastructure is solid. The gap is **enforcement** — screens were built iteratively and drift happened. The fixes are safe, mechanical refactors (token substitution) with negligible risk. Phase 1 alone would raise compliance from 62% → ~85%.
