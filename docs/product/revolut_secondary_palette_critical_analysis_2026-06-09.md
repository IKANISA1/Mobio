# Revolut-Reference Secondary Palette Critical Analysis

> Date: 2026-06-09
> Scope: MOBI Flutter design system
> Primary brand colors fixed by logo direction:
> `#8885F0`, `#D38B96`, `#FF5E43`, `#3CD070`

## Executive Decision

The four primary colors are strong enough to anchor the whole product, but they are not enough to run a complete premium mobile design system. The current palette needs a disciplined secondary layer for:

- deep neutral surfaces
- subtle violet/blue gradient stops
- info and navigation states
- caution states that are separate from destructive orange-red
- muted text and disabled states
- borders, overlays, scrims, and glass chrome

The target should not be a colorful app. The target should be a Revolut-reference dark product system where color appears as controlled energy inside a mostly black, navy, and glass-like shell.

## Current Palette Assessment

### What is working

- `#8885F0` periwinkle works well as the premium brand node, focus color, selected state, and main gradient signal.
- `#D38B96` dusty rose gives warm human/profile/promotional contrast without becoming loud.
- `#FF5E43` orange-red is strong enough for destructive and urgent states.
- `#3CD070` mint green reads clearly as live, confirmed, positive, or available.
- Dark surfaces in `app_colors.dart` are already close to the Revolut reference direction: black base, violet-navy panels, white text, floating chrome.

### What is missing

- No dedicated `info` color. Existing hard-coded blues such as `#2979FF` appear in admin stats and are not harmonized with the new brand system.
- No dedicated `caution` family separate from error. Current amber usage is inconsistent across widgets.
- No named glass/scrim/overlay tokens, so many widgets still rely on `Colors.black` or `Colors.white` alpha values.
- No named disabled tokens. Disabled text, disabled controls, and inactive icons should not all rely on `onSurfaceVariant`.
- No premium neutral ramp for "black chrome" versus "content cards" versus "raised glass".
- Gradient stops are too few. Revolut-like screens need screen-specific dark gradients while still using the same brand nodes.
- Earlier scans found generic hard-coded Flutter colors in feature code. Active
  code should route those through `AppColors.success`, `AppColors.caution`,
  `AppColors.info`, or the controlled primary token instead of adding new brand
  colors.

## Palette Principles

1. Keep the four logo colors as the only loud brand colors.
2. Use black and deep blue-violet surfaces for most UI area.
3. Use secondary colors mainly as semantic helpers, not as new brand colors.
4. Use color in containers, icons, badges, and gradients before using it in large text.
5. On dark surfaces, prefer light text on dark containers, not saturated text everywhere.
6. Every semantic color must have: base, dim, container, on-base, and on-container.
7. Avoid generic Material colors unless they are mapped into MOBI tokens.

## Recommended Secondary Palette

### 1. Premium Neutral Ramp

These should become the backbone of `dark` and `light` palettes.

| Token | Dark hex | Usage |
|---|---:|---|
| `inkBlack` | `#02030A` | app background, screen bottom |
| `inkBlackElevated` | `#070812` | bottom sheets, nav glass base |
| `inkNavyLow` | `#101120` | low panels, search field support |
| `inkNavy` | `#15172A` | default cards |
| `inkNavyHigh` | `#1D2036` | raised cards, active nav item |
| `inkVioletHigh` | `#2B2F4A` | highest raised surface |
| `textPrimary` | `#F7F8FF` | primary text on dark |
| `textSecondary` | `#C2C4D6` | secondary text on dark |
| `textTertiary` | `#8B8EA5` | captions, timestamps |
| `textDisabled` | `#5E6278` | disabled controls |
| `borderStrong` | `#686B86` | high-contrast borders |
| `borderSubtle` | `#383B55` | panel borders and dividers |

Critical note: current dark neutrals are mostly usable, but `onSurfaceVariant = #B9BBCD` is too broad. Split it into secondary, tertiary, and disabled text.

### 2. Info / Navigation Blue

Add this. It is the main missing secondary color.

| Token | Hex | Usage |
|---|---:|---|
| `info` | `#4D8DFF` | route, analytics, map, calendar, informational links |
| `infoDim` | `#2E69D8` | pressed/hovered info |
| `infoContainer` | `#0F274F` | info badge/card background |
| `onInfo` | `#061226` | text/icon on `info` |
| `onInfoContainer` | `#D8E7FF` | text/icon on `infoContainer` |

Why it fits: Revolut-style UIs often use electric blue as an action/navigation signal, but MOBI should keep it below periwinkle in brand priority. This blue is cooler and deeper than `#8885F0`, so it will not fight the primary.

### 3. Aqua / Teal Motion Accent

Add this only for location, motion, route availability, and "live map" details. Do not use it as a fifth brand color.

| Token | Hex | Usage |
|---|---:|---|
| `aqua` | `#5DE2E7` | location pulse, map path, live transport accent |
| `aquaDim` | `#33B7C0` | pressed/low emphasis |
| `aquaContainer` | `#0B3439` | map/live badge background |
| `onAqua` | `#041415` | text/icon on `aqua` |
| `onAquaContainer` | `#D7FAFC` | text/icon on `aquaContainer` |

Why it fits: it provides the teal/wealth-screen freshness visible in the reference screenshots without turning the palette into a blue-green app. Use sparingly.

### 4. Caution Amber

Keep amber, but formalize it. It must not be the same as error.

| Token | Hex | Usage |
|---|---:|---|
| `caution` | `#FFB84D` | pending, attention, limited availability |
| `cautionDim` | `#D98F25` | pressed/low emphasis |
| `cautionContainer` | `#3A2608` | warning badge/card background |
| `onCaution` | `#1B1000` | text/icon on `caution` |
| `onCautionContainer` | `#FFE7BD` | text/icon on `cautionContainer` |

Why it fits: it is warmer than the periwinkle/rose/mint group but less aggressive than `#FF5E43`.

### 5. Purple Depth Stops

These are not new brand colors. They are gradient-depth colors.

| Token | Hex | Usage |
|---|---:|---|
| `violetDepth` | `#18124A` | deep brand gradient middle |
| `blueDepth` | `#10164B` | home/crypto gradient middle |
| `plumDepth` | `#2A1639` | profile/rewards gradient middle |
| `roseDepth` | `#39202D` | rose-tinted panels |
| `mintDepth` | `#0F3421` | live/positive panels |
| `orangeDepth` | `#3E1510` | destructive/warning panels |

Why it fits: Revolut-like screens feel immersive because gradients move through dark neighboring hues, not because everything is fully saturated.

### 6. Glass / Overlay Tokens

Add these as semantic alpha tokens, not hex-only colors.

| Token | Value | Usage |
|---|---:|---|
| `blackChromeAlpha` | `0.72` | command bar, circular top actions |
| `navChromeAlpha` | `0.88` | floating bottom nav |
| `panelAlpha` | `0.82` | default translucent surface |
| `panelBorderAlpha` | `0.18` | subtle white panel border |
| `hairlineAlpha` | `0.12` | internal dividers |
| `scrimAlpha` | `0.72` | modal barrier |
| `pressedWhiteAlpha` | `0.08` | ripple/pressed state |
| `disabledAlpha` | `0.38` | disabled foreground |

Critical note: many widgets currently use raw `Colors.black.withValues(...)` and `Colors.white.withValues(...)`. This is visually close but not governed.

## Screen Gradient Presets

Use screen presets to get the Revolut interaction feel without creating random page themes.

| Preset | Stops | Usage |
|---|---|---|
| `homeGradient` | `#8885F0 -> #10164B -> #02030A` | Home, Trips, default shell |
| `nearbyGradient` | `#5DE2E7 -> #0B3439 -> #02030A` | Nearby, map, mobility |
| `profileGradient` | `#D38B96 -> #39202D -> #02030A` | Profile, account, personal settings |
| `rewardsGradient` | `#A45CFF -> #8885F0 -> #26145A -> #02030A` | rewards/premium moments only |
| `successGradient` | `#3CD070 -> #0F3421 -> #02030A` | confirmation and live states |
| `alertGradient` | `#FF5E43 -> #3E1510 -> #02030A` | destructive or failed state screens |

Important: `#A45CFF` should only be a gradient stop, not a standard component color. Otherwise the palette becomes too purple.

## Revolut-Reference Usage Discipline

### Use color like this

- Large screen background: gradient plus black bottom.
- Header chrome: black pill and black circular actions.
- Main number or headline: white.
- Primary CTA: white pill on dark surfaces.
- Active nav: black/raised capsule with white icon/text.
- Status: small badge with semantic container and icon.
- Cards: translucent dark panels with subtle border.
- Promo/reward modules: one gradient media panel, not many colored cards.

### Do not use color like this

- Do not make each card a different bright color.
- Do not use generic blue, green, orange, or purple constants from Flutter.
- Do not put saturated brand colors behind long text.
- Do not use orange-red for mild warnings.
- Do not use dusty rose for errors.
- Do not use mint for generic decoration.
- Do not use periwinkle as every icon color.

## Priority Implementation Plan

### P0: Token Completeness

- Add `info`, `aqua`, `caution`, `textTertiary`, `textDisabled`, `borderStrong`, `borderSubtle`.
- Add gradient depth stops.
- Add overlay alpha tokens in `MobiThemeExtension`.
- Document the full palette in `design.md`.

### P1: Replace Hard-Coded Off-Palette Colors

Replace:

- generic green success constants with `AppColors.success`
- generic orange or amber warning constants with `AppColors.caution`
- generic blue info constants with `AppColors.info`
- generic purple emphasis constants with a controlled gradient-only violet or
  `AppColors.primary`

### P2: Interaction Feel

- Centralize black command-bar chrome tokens.
- Centralize white primary pill button treatment.
- Move page gradients into named presets.
- Give pressed, focused, disabled, selected states explicit tokens.

### P3: QA Gates

- Add contrast checks for text on containers.
- Add widget/golden tests for dark Home, Trips, Nearby, Profile, and config-error.
- Add a hard-coded color lint pass for feature screens.

## Final Recommended Additions

Add these colors to the design system:

```text
info                #4D8DFF
infoDim             #2E69D8
infoContainer       #0F274F
onInfo              #061226
onInfoContainer     #D8E7FF

aqua                #5DE2E7
aquaDim             #33B7C0
aquaContainer       #0B3439
onAqua              #041415
onAquaContainer     #D7FAFC

caution             #FFB84D
cautionDim          #D98F25
cautionContainer    #3A2608
onCaution           #1B1000
onCautionContainer  #FFE7BD

textTertiary        #8B8EA5
textDisabled        #5E6278
borderStrong        #686B86
borderSubtle        #383B55

violetDepth         #18124A
blueDepth           #10164B
plumDepth           #2A1639
roseDepth           #39202D
mintDepth           #0F3421
orangeDepth         #3E1510
```

## Critical Conclusion

The four fixed primary colors are correct for the brand nodes, but the design system is not complete until secondary colors are formalized as semantic and surface tokens. The optimal premium direction is not to add many more visible colors. It is to add a disciplined support palette that lets the app feel dark, glassy, precise, and interaction-led while the four MOBI colors remain the recognizable identity.
