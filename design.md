# Mobio — UI Design System Specification

> **Version**: 1.0 · **Last updated**: 2026-03-25
> **Source of truth files**: `lib/core/theme/`, `lib/shared/widgets/`

---

## 1. Design Philosophy: "Claymorphic Utility"

Mobio's visual language blends **Claymorphism** (soft, tactile 3D surfaces) with **Material Design 3** structural tokens. The result is an interface that feels premium and "physical" — cards press in, buttons have weight — while maintaining the rigor of a financial & logistics platform.

### Core Pillars

| Pillar | Implementation |
|---|---|
| **Tactility** | Every interactive element responds with scale + opacity spring animation on press |
| **Depth** | Multi-layer elevation via `clayCard`, `clayButton`, and `premium` shadow sets |
| **Dark-first** | Ship-dark by default (`#0C0F10`); all tokens tuned for dark backgrounds first |
| **Glassmorphism** | Floating overlays (nav bar, modals) use `BackdropFilter` blur + translucent borders |
| **No-decoration minimalism** | No images/photos required; premium feel from typography, spacing, and motion alone |

---

## 2. Color System

All colors follow the **MD3 on-color** naming convention. Defined in [app_colors.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/core/theme/app_colors.dart).

### 2A. Primary & Action (Green)

| Token | Hex | Usage |
|---|---|---|
| `primary` | `#006D2F` | Main brand / CTA backgrounds |
| `primaryDim` | `#006028` | Gradient endpoint, hover/active states |
| `primaryContainer` | `#005221` | Container fill (dark) |
| `primaryFixed` | `#66FF8E` | High-visibility highlight badge |
| `primaryFixedDim` | `#50F17F` | Dimmed highlight |
| `onPrimary` | `#003915` | Text on `primary` surfaces |
| `onPrimaryContainer` | `#66FF8E` | Text on `primaryContainer` |
| `inversePrimary` | `#5DFD8A` | Inverted context accent |
| `surfaceTint` | `#006D2F` | Tint layer (same as primary) |

### 2B. Secondary (Blue-Gray)

| Token | Hex | Usage |
|---|---|---|
| `secondary` | `#545F77` | Secondary actions |
| `secondaryDim` | `#48536A` | Secondary gradient endpoint |
| `secondaryContainer` | `#353F56` | Selected chips, badges |
| `secondaryFixed` | `#D7E2FF` | Light-mode fixed |
| `onSecondary` | `#F9F8FF` | Text on secondary |
| `onSecondaryContainer` | `#D7E2FF` | Badge text on container |

### 2C. Tertiary (Admin Blue)

| Token | Hex | Usage |
|---|---|---|
| `tertiary` | `#48617E` | Admin / data-viz accent |
| `tertiaryContainer` | `#3C5572` | Admin card highlighting |
| `tertiaryFixed` | `#C2DCFF` | Fixed tertiary tint |
| `onTertiary` | `#F7F9FF` | Text on tertiary |
| `onTertiaryContainer` | `#C2DCFF` | Text on tertiary container |

### 2D. Surface & Background (Dark Palette)

| Token | Hex | Role |
|---|---|---|
| `background` / `surface` | `#0C0F10` | App scaffold background |
| `surfaceDim` | `#0C0F10` | Dimmed surface (same as bg) |
| `surfaceBright` | `#1A1C1E` | Elevated bright surface |
| `surfaceContainerLowest` | `#080A0B` | Deepest card base |
| `surfaceContainerLow` | `#141618` | Input backgrounds, soft gradient source |
| `surfaceContainer` | `#1A1C1E` | Section backgrounds, skeleton base |
| `surfaceContainerHigh` | `#212426` | Elevated sections, ghost button bg |
| `surfaceContainerHighest` | `#2B2E30` | Toggle track bg |
| `surfaceVariant` | `#2B2E30` | Variant surface |
| `onSurface` | `#F8F9FA` | Primary text color |
| `onSurfaceVariant` | `#ABB3B7` | Muted / secondary text |
| `onBackground` | `#F8F9FA` | Text on background |

### 2E. Outline

| Token | Hex |
|---|---|
| `outline` | `#586064` |
| `outlineVariant` | `#44474A` |

### 2F. System Colors

| Token | Hex | Usage |
|---|---|---|
| `error` | `#9F403D` | Destructive actions / alerts |
| `errorDim` | `#4E0309` | Error gradient endpoint |
| `errorContainer` | `#4E0309` | Error pill bg |
| `onError` | `#FFF7F6` | Text on error |
| `onErrorContainer` | `#FE8983` | Text on error container |
| `success` | `#4CAF50` | Success states |
| `warning` | `#FF9800` | Warning states |
| `redAccent` | `#EF5350` | Logout / cancel |

### 2G. Brand Accents

| Token | Hex | Usage |
|---|---|---|
| `whatsappGreen` | `#25D366` | WhatsApp CTA |
| `whatsappDark` | `#128C7E` | WhatsApp gradient endpoint |
| `bioPayGreen` | `#00C853` | BioPay brand accent |

---

## 3. Typography System

Dual-font strategy: **Manrope** for impact & branding, **Inter** for functional UI. Defined in [app_typography.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/core/theme/app_typography.dart).

### 3A. Font Families

| Role | Font | Source |
|---|---|---|
| Headline / Display | **Manrope** (800, 700) | `google_fonts` package |
| Body / Label | **Inter** (400–700) | `google_fonts` package |

### 3B. Full Typographic Scale

| Token | Font | Size | Weight | Line Height | Letter Spacing | Color | Usage |
|---|---|---|---|---|---|---|---|
| `displayLg` | Manrope | 48 | 800 | 1.1 | -2.0 | onSurface | Hero titles, splash |
| `displayMd` | Manrope | 36 | 800 | 1.1 | -1.5 | onSurface | Screen headers |
| `headlineLg` | Manrope | 28 | 800 | 1.2 | -1.0 | onSurface | Section titles |
| `headlineMd` | Manrope | 22 | 800 | 1.2 | -0.5 | onSurface | Card titles |
| `titleLg` | Manrope | 20 | 800 | 1.3 | -0.3 | onSurface | List headers |
| `titleMd` | Manrope | 18 | 700 | 1.3 | 0 | onSurface | Sub-headers, button labels |
| `bodyLg` | Inter | 18 | 500 | 1.6 | 0 | onSurface | Primary content |
| `bodyMd` | Inter | 16 | 400 | 1.6 | 0 | onSurface | Secondary content |
| `bodySm` | Inter | 14 | 400 | 1.5 | 0 | onSurface | Tertiary content |
| `labelLg` | Inter | 14 | 700 | – | 1.0 | onSurfaceVariant | Large metadata |
| `labelMd` | Inter | 12 | 700 | – | 0.5 | onSurfaceVariant | Metadata / captions |
| `labelSm` | Inter | 10 | 700 | – | 1.5 | onSurfaceVariant | Uppercase metadata |
| `heroNumber` | Manrope | 56 | 800 | 0.9 | -3.0 | onSurface | Large stat numbers |
| `chipText` | Inter | 12 | 700 | – | 0 | onSurface | Chip labels |
| `badgeText` | Inter | 8 | 700 | – | 0.5 | onSecondaryContainer | Badge labels |

---

## 4. Elevation & Effects

Defined in [app_shadows.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/core/theme/app_shadows.dart).

### 4A. Shadow Tokens

| Token | Composition | Usage |
|---|---|---|
| `clayCard` | `white@5% blur:1 offset:(0,1)` + `black@20% blur:4 offset:(0,-2)` | Static clay cards, main UI surfaces |
| `clayButton` | `white@5% blur:4 offset:(0,2)` + `black@40% blur:32 offset:(0,12)` | Elevated floating buttons |
| `premium` | `black@3% blur:25 spread:-5 offset:(0,20)` + `black@2% blur:10 spread:-5 offset:(0,10)` | Premium floating elements, MobiButton |

> [!NOTE]
> Flutter doesn't support CSS `inset` shadows natively. The "inset" effect is achieved via **gradient overlays** (white→transparent at top-left) on card surfaces, combined with the outer shadow tokens above.

### 4B. Gradient Overlays

| Surface | Gradient |
|---|---|
| Clay Card | `LinearGradient(topLeft→bottomRight, white@3%→transparent)` |
| Glass Card | `LinearGradient(topLeft→bottomRight, white@2%→transparent)` |
| Primary Button | `LinearGradient(topLeft→bottomRight, primary→primaryDim)` |
| Danger Button | `LinearGradient(topLeft→bottomRight, error→errorDim)` |
| WhatsApp Button | `LinearGradient(topLeft→bottomRight, whatsappGreen→whatsappDark)` |

### 4C. Blur Effects

| Component | Blur Sigma | Opacity |
|---|---|---|
| GlassCard (glass_container) | 30 × 30 | `surfaceContainerLowest @ 40%` |

---

## 5. Border Radii

| Token | Value | Usage |
|---|---|---|
| Hero radius | `40–48px` | Main screen hero sections, large clay cards |
| Card radius | `40px` | Default ClayCard, GlassCard |
| Section radius | `24px` | Icon containers, medium cards |
| Button radius | `100px` (stadium) | All MobiButton variants, pills, chips |
| Input radius | `100px` | Toggle tracks, filter chips |

---

## 6. Spacing Grid

Strict **4px** base unit. All spacing is a multiple of 4.

| Token | Value | Common Usage |
|---|---|---|
| `x1` | 4px | Micro gaps |
| `x2` | 8px | Between icon and label, chip gaps |
| `x3` | 12px | Nav item padding, toggle internal |
| `x4` | 16px | Nav bar horizontal padding, standard gap |
| `x5` | 20px | Card content gap, button horizontal padding |
| `x6` | 24px | Default card padding, screen horizontal padding |
| `x7` | 28px | Config card padding |
| `x8` | 32px | Section vertical spacing |
| `x10` | 40px | Button horizontal padding |

---

## 7. Component Library

All shared components live in [widgets/](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/).

### 7A. ClayCard

**The signature component.** Soft-plastic tactile surface with press animation.

| Property | Default | Description |
|---|---|---|
| `borderRadius` | `40` | Main card curvature |
| `padding` | `EdgeInsets.all(24)` | Internal padding |
| `color` | `surfaceContainerLowest` | Override-able base color |
| `onTap` | `null` | If set, enables press feedback |

**Press animation** (when `onTap` is set):
- Duration: `120ms` with `easeInOut`
- Scale: `1.0 → 0.97`
- Opacity: `1.0 → 0.85`

```dart
ClayCard(
  onTap: () => doSomething(),
  child: Text('Tap me'),
)
```

### 7B. GlassCard (glass_container.dart)

**Frosted glass overlay.** Used for bottom nav, floating headers, modals.

| Property | Default | Description |
|---|---|---|
| `borderRadius` | `40` | Curvature |
| `customBorderRadius` | `null` | Override for non-uniform corners |
| `padding` | `EdgeInsets.zero` | Internal padding |

**Visual recipe**:
- `BackdropFilter` blur: sigma 30×30
- Background: `surfaceContainerLowest @ 40%` opacity
- Border: `white @ 5%`, 1px
- Gradient overlay: `white@2% → transparent`

### 7C. MobiButton

**5-variant button** with gradient fill and premium shadow.

| Variant | Gradient | Foreground |
|---|---|---|
| `primary` | `primary → primaryDim` | `onPrimary` |
| `whatsapp` | `whatsappGreen → whatsappDark` | `white` |
| `ghost` | None (solid `surfaceContainerHigh`) | `onSurface` |
| `danger` | `error → errorDim` | `onError` |
| `success` | `surfaceTint → primaryDim` | `onPrimary` |

**Common properties**:
- Border radius: `100px` (stadium)
- Shadow: `AppShadows.premium`
- Border: `white @ 10%`, 1px
- Default padding: `horizontal:40, vertical:20`
- Loading state: `CircularProgressIndicator` (24×24, stroke 2.5)
- Label style: `titleMd`

### 7D. MobiToggle

**Segmented control** matching Passenger/Driver mode switcher.

| Property | Value |
|---|---|
| Track bg | `surfaceContainerHighest @ 50%` |
| Track radius | `100px` |
| Selected pill bg | `surfaceContainerLowest` |
| Selected pill shadow | `black@15% blur:8 offset:(0,2)` |
| Unselected bg | `transparent` |
| Label font | Manrope 14px, w800 |
| Active color | `onSurface` |
| Inactive color | `onSurfaceVariant` |
| Transition | `300ms` |

### 7E. MobiBottomNav

**3-tab floating nav bar** using GlassCard as background.

| Property | Value |
|---|---|
| Position | `bottom: 16 + safeBottom`, `left/right: 24` |
| Background | GlassCard with `borderRadius: 40` |
| Internal padding | `horizontal:16, vertical:12` |
| Tabs (Passenger) | Discover · BioPay · Profile |
| Tabs (Admin) | Dashboard · Users · Profile |
| Active icon | Green circle `48×48`, icon `22px`, `primary` bg |
| Inactive icon | No circle, icon `20px`, `onSurfaceVariant` |
| Label font | Inter 10px, w700, spacing -0.3 |
| Active label color | `primary` |
| Inactive label color | `onSurfaceVariant` |
| Press feedback | Opacity `0.6` + Scale `0.92`, `100ms` |
| Circle transition | `300ms easeOutCubic` |

### 7F. TappableIconButton

**Standard icon-only tap target** with Material ripple. Minimum `48×48dp` touch target.

| Property | Default |
|---|---|
| `size` | `24` (icon size) |
| `touchTargetSize` | `48` |
| `color` | `primary` |
| Splash | `color @ 15%` |
| Highlight | `color @ 8%` |

### 7G. VehicleFilterChips

**Horizontal scrolling chip list** with press animation.

| State | Background | Shadow |
|---|---|---|
| Selected | `secondaryContainer` | None |
| Unselected | `surfaceContainerLowest` | `black@10% blur:4 offset:(0,2)` |
| Press feedback | Scale `0.95`, Opacity `0.8`, `100ms` |
| Chip padding | `horizontal:20, vertical:12` |
| Chip radius | `100px` |
| Icon size | `16px` |
| Label font | 12px, w700 |

### 7H. LoadingSkeleton

**Shimmer skeleton** for loading states.

| Property | Default |
|---|---|
| `borderRadius` | `40` |
| `height` | `128` |
| Animation duration | `1500ms`, looping |
| Gradient colors | `surfaceContainer → surfaceContainerHigh → surfaceContainer` |

### 7I. SoftGradient

**Full-screen promotional background wrapper** for screens. Fetches AI-generated promo media from Supabase and displays as ambient background. Cards/containers sit on top with their own opaque surfaces.

| Layer | Behavior |
|---|---|
| **Video** (priority) | `VideoPlayer` loops silently, reduced-motion respects `disableAnimations` |
| **Image carousel** (fallback) | `CachedNetworkImage`, 10s rotation, 800ms crossfade |
| **Radial gradient** (final fallback) | `RadialGradient`, center `topRight`, radius `1.5`, `surfaceContainerLow → surface` |
| **Status bar scrim** (if media) | Linear gradient `surface@45% → transparent`, height = `statusBar + 56` |

| Property | Value |
|---|---|
| Category | `PromoCategory` enum (per-screen) |
| Timer | 10s image rotation |
| Layout | `Stack` with `StackFit.expand`, child on top |


### 7J. DriverCard

**Trip listing card** combining ClayCard + vehicle icon + driver ID + badges + WhatsApp CTA.

| Element | Spec |
|---|---|
| Container | `ClayCard`, default padding `24` |
| Vehicle icon box | `80×80`, `surfaceContainer` bg, radius `24`, icon `40px` |
| Driver ID | `headlineMd` at `24px`, spacing `-0.5` |
| Vehicle type badge | `secondaryContainer` pill, `badgeText`, radius `100` |
| Distance badge | `surfaceContainer` pill, `badgeText`, `onSurfaceVariant` |
| WhatsApp button | `48×48` circle, `primary` bg, Material ripple (`white@30%` splash) |

---

## 8. Iconography

| Library | Package | Usage |
|---|---|---|
| **Lucide Icons** | `lucide_icons: ^0.257.0` | Primary icon set — all nav, actions, badges |
| Material Icons | Flutter built-in | Fallback only |

### Key Icon Mappings

| Concept | Icon |
|---|---|
| Moto | `LucideIcons.zap` |
| Cab | `LucideIcons.car` |
| Trike | `LucideIcons.truck` |
| Truck | `LucideIcons.layoutGrid` |
| Private | `LucideIcons.shield` |
| Discover tab | `LucideIcons.compass` |
| BioPay tab | `LucideIcons.shieldCheck` |
| Profile tab | `LucideIcons.user` |
| Admin Dashboard | `LucideIcons.layoutDashboard` |
| Admin Users | `LucideIcons.users` |

---

## 9. Motion & Interaction System

All interactive elements provide **instant physical feedback**. No element should feel "dead."

### 9A. Animation Tokens

| Pattern | Duration | Curve | Values |
|---|---|---|---|
| **Card press** | 120ms | easeInOut | Scale `1.0→0.97`, Opacity `1.0→0.85` |
| **Nav item press** | 100ms | linear | Scale `1.0→0.92`, Opacity `1.0→0.6` |
| **Chip press** | 100ms | linear | Scale `1.0→0.95`, Opacity `1.0→0.8` |
| **Active tab circle** | 300ms | easeOutCubic | Size `40→48`, color transition |
| **Toggle slide** | 300ms | default | Background + shadow transition |
| **Tab switcher** | 300ms | easeOutCubic / easeInCubic | `AnimatedSwitcher` cross-fade |
| **Skeleton shimmer** | 1500ms | linear, repeat | Gradient sweep left→right |
| **Button container** | 200ms | default | `AnimatedContainer` color/shape |

### 9B. Interaction Rules

> [!IMPORTANT]
> **Every tappable element MUST provide visual feedback.** Use one of:
> 1. `ClayCard(onTap: ...)` — built-in scale+opacity
> 2. `TappableIconButton` — Material ripple
> 3. `MobiButton` — InkWell + AnimatedContainer
> 4. Custom `GestureDetector` with `AnimatedScale` + `AnimatedOpacity`

**Minimum touch target**: `48×48dp` (per Material guidelines).

---

## 10. Layout Patterns

### 10A. Screen Scaffolding

```
Scaffold(
  backgroundColor: AppColors.background,
  body: Stack([
    SafeArea(bottom: false, child: content),
    MobiBottomNav(...),           // Floating glass nav
    // Optional modal overlays
  ]),
)
```

- `SafeArea` with `bottom: false` — nav bar handles its own safe area
- `AppBarTheme`: transparent, no elevation, no `scrolledUnderElevation`
- Scrollbar: hidden (`width: 0`) for app-like aesthetic
- Splash/highlight: disabled globally (`Colors.transparent`)

### 10B. Screen Transitions

| Navigation | Method |
|---|---|
| Tab switching | `AnimatedSwitcher` (300ms, easeOutCubic) with `KeyedSubtree` |
| Sub-screen push | `GoRouter` with `context.push()` / `context.go()` |
| Dialog dismiss | `Navigator.pop(context)` (standard Flutter dialog pattern) |
| System back | `PopScope` with custom `onPopInvokedWithResult` |

### 10C. Content Width

- Max content width: none (full-width, mobile-first)
- Error/config screens: `maxWidth: 420` with centered `Container`

---

## 11. Dual-Mode Theming (Dark & Light)

Mobio supports full **Dark** and **Light** mode with user toggle + persistence.
Default is **Dark**. Mode-dependent tokens live in `AppColors.dark` / `AppColors.light`;
custom surface containers live in [MobiThemeExtension](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/core/theme/mobi_theme_extension.dart).

### 11A. Surface & Text Tokens (side-by-side)

| Token | Dark | Light |
|---|---|---|
| `background` / `surface` | `#0C0F10` | `#F8F9FA` |
| `surfaceContainerLowest` | `#080A0B` | `#FFFFFF` |
| `surfaceContainerLow` | `#141618` | `#F1F4F6` |
| `surfaceContainer` | `#1A1C1E` | `#EAEFF1` |
| `surfaceContainerHigh` | `#212426` | `#E3E9EC` |
| `surfaceContainerHighest` | `#2B2E30` | `#DBE4E7` |
| `onSurface` | `#F8F9FA` | `#2B3437` |
| `onSurfaceVariant` | `#ABB3B7` | `#586064` |
| `outline` | `#586064` | `#737C7F` |
| `outlineVariant` | `#44474A` | `#ABB3B7` |
| `onPrimary` | `#003915` | `#E4FFE2` |
| `primaryContainer` | `#005221` | `#66FF8E` |

### 11B. Shadow Adjustments per Mode

| Shadow Set | Dark | Light |
|---|---|---|
| `clayButton` outer | `40%` black, blur 32 | `8%` `#2B3437`, blur 32 |
| `clayButton` inner | `5%` white, blur 4 | `30%` white, blur 4 |
| `clayCard` outer | `20%` black, blur 4 | `2%` black, blur 4 |
| `clayCard` inner | `5%` white, blur 1 | `60%` white, blur 1 |

### 11C. Glass-Card Opacity Tuning

| Token | Dark | Light |
|---|---|---|
| `glassCardBgAlpha` | `0.4` | `0.6` |
| `glassCardBorderWhiteAlpha` | `0.05` | `0.2` |
| `glassCardGradientWhiteAlpha` | `0.02` | `0.1` |
| `clayCardGradientWhiteAlpha` | `0.03` | `0.4` |

---

## 12. Theme Configuration

Defined in [app_theme.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/core/theme/app_theme.dart).
Managed by [ThemeProvider](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/core/theme/theme_provider.dart).

### Architecture

1. `ThemeProvider` (ChangeNotifier) stores the current binary `ThemeMode` (`dark` / `light`) and persists to `SharedPreferences` (key: `mobi_theme_mode`)
2. `ThemeProvider` is created during startup in `main.dart`, initialized before `runApp`, and injected through Riverpod
3. `MobiMainApp` listens to `ThemeProvider` with `ListenableBuilder`, then passes `theme: AppTheme.lightTheme`, `darkTheme: AppTheme.darkTheme`, and `themeMode: provider.mode` into `MaterialApp`
4. `SystemChrome.setSystemUIOverlayStyle` reacts to theme changes from the same listener (status bar + nav bar icons/colors)
5. All widgets resolve colors via `Theme.of(context).colorScheme` or `Theme.of(context).extension<MobiThemeExtension>()!`

### Usage

```dart
// Toggle theme
ref.read(themeProviderProvider).toggleTheme();

// Read current mode
final isDark = ref.read(themeProviderProvider).isDark;

// Resolve colors in any widget
final cs = Theme.of(context).colorScheme;
final ext = Theme.of(context).extension<MobiThemeExtension>()!;
```

> [!TIP]
> The base `textTheme` uses Inter. Manrope is applied via `AppTypography` static styles, not via the theme. This ensures headline styles must be explicitly applied — no accidental Manrope on body text.

---

## 13. Dependencies (UI-relevant)

| Package | Version | Role |
|---|---|---|
| `google_fonts` | ^8.0.2 | Manrope + Inter loading |
| `lucide_icons` | ^0.257.0 | Primary icon set |
| `flutter_animate` | ^4.5.2 | Advanced animation chains |
| `shimmer` | ^3.0.0 | Shimmer effects (legacy, replaced by custom `LoadingSkeleton`) |
| `cached_network_image` | ^3.4.1 | Async image loading |
| `qr_flutter` | ^4.1.0 | QR code rendering (BioPay) |
| `camera` | ^0.11.1 | Face enrollment camera |

---

## 14. Screen Application Guide

### Home (Discover Tab)

- Background: `SoftGradient` wrapper
- Layout: Vertical stack of ClayCards (bento-like)
- Hero typography: `displayLg` or custom 3.5rem for impact
- Mode switcher: `MobiToggle(labels: ['Passenger', 'Driver'])`
- Driver list: `DriverCard` components
- Vehicle filter: `VehicleFilterChips` horizontal scroll

### BioPay Tab

- Aesthetic: "Security vault" — minimal, dark, authoritative
- Hero text: `displayMd` with tight tracking for stamp-like impact
- Action cards: Large ClayCards with icon + label, easy-to-tap (48dp+)
- Sub-screens: Get QR, Scan QR, Face Scan, Face Register, Face Enroll

### Profile Tab

- Settings list: ClayCards as section containers
- Dark mode toggle, admin gateway CTA
- Edit profile: sub-screen push

### Admin Dashboard

- Pattern: Data-dense utility grid
- Metrics: `displayMd` for key numbers
- Metadata: `labelSm` (uppercase, wide tracking)
- Color shift: Tertiary (blue-gray) distinguishes admin from green primary

---

## 15. File Reference Map

| Concern | File |
|---|---|
| Colors | [app_colors.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/core/theme/app_colors.dart) |
| Typography | [app_typography.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/core/theme/app_typography.dart) |
| Shadows | [app_shadows.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/core/theme/app_shadows.dart) |
| Theme | [app_theme.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/core/theme/app_theme.dart) |
| ClayCard | [glass_card.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/glass_card.dart) |
| GlassCard | [glass_container.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/glass_container.dart) |
| MobiButton | [mobi_button.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/mobi_button.dart) |
| MobiToggle | [mobi_toggle.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/mobi_toggle.dart) |
| MobiBottomNav | [mobi_bottom_nav.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/mobi_bottom_nav.dart) |
| TappableIconButton | [tappable_icon_button.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/tappable_icon_button.dart) |
| VehicleFilterChips | [vehicle_filter_chips.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/vehicle_filter_chips.dart) |
| DriverCard | [driver_card.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/driver_card.dart) |
| LoadingSkeleton | [loading_skeleton.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/loading_skeleton.dart) |
| SoftGradient | [soft_gradient.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/soft_gradient.dart) |
| AiEmptyState | [ai_empty_state.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/ai_empty_state.dart) |
| PlaceAutocompleteField | [place_autocomplete_field.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/place_autocomplete_field.dart) |
| PermissionAccessDialog | [permission_access_dialog.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/permission_access_dialog.dart) |
| RouteMapCard | [route_map_card.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/route_map_card.dart) |
| PromoImageCarousel | [promo_image_carousel.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/promo_image_carousel.dart) |
| PromoVideoPlayer | [promo_video_player.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/promo_video_player.dart) |
| WhatsAppIcon | [whatsapp_icon.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/whatsapp_icon.dart) |
| WhatsAppInput | [whatsapp_input.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/whatsapp_input.dart) |
| WhatsAppModal | [whatsapp_modal.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/whatsapp_modal.dart) |
| App Shell | [app.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/app.dart) |
| Constants | [app_constants.dart](file:///Volumes/PRO-G40/MOBI/mobi_app/lib/core/constants/app_constants.dart) |
