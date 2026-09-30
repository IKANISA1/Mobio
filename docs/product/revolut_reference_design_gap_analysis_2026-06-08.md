# Revolut Reference Design Gap Analysis

> Historical comparison evidence. The source-contract filename below records the
> former local specification, deleted on 30 September 2026. This report cannot
> govern subsequent UI work; the external `revolut-design` skill is the sole
> design authority. Its dated findings do not establish current acceptance.

> Date: 2026-06-12
> Scope: MOBI Flutter app, design tokens, static web shell, launch surfaces, and
> product docs
> Historical source contract: `design.md` (removed)
> Reference folder supplied by user: `/Users/jeanbosco/Downloads/Revolut10`

## Executive Finding

MOBI is now materially aligned with the Revolut reference grammar in the source
contract, launch surfaces, shared widgets, local preview harness, and visual
goldens. The current implementation follows the reference pattern of a dark
immersive shell, black command chrome, large centered hero hierarchy, circular
actions, translucent panels, white/black pill controls, and a restrained
four-color MOBI palette.

It is still not defensible to claim "100% same look and feel" as a release
statement. The reference images are now inspectable, and MOBI has passing
goldens, browser-runtime screenshots, and native Android/iOS screenshots across
the primary screen matrix. Motion-video proof was attempted on native targets
and remains blocked by device/build-state issues, so the remaining gaps are
motion-video proof, production data realism, and product-approved density
differences.
There are also deliberate product differences: MOBI is a transport network, not
a finance app, and `design.md` currently preserves a three-tab shell.

- **Design-token and contract alignment:** `94/100`
- **Implemented source alignment:** `94/100`
- **Evidence-backed visual parity:** `95/100`
- **Release claim:** not ready for "100% same look and feel" wording

The correct target remains: Revolut-level interaction grammar, rhythm, density,
surface treatment, and hierarchy, with MOBI-owned content, MOBI routes, and the
four approved colors. Do not copy Revolut marks, copy, financial claims,
proprietary card imagery, crypto/invest labels, RevPoints labels, or unsupported
product flows.

## Reference Evidence

The supplied folder is readable in this pass. It contains 12 reference PNGs:

`IMG_2739.PNG`, `IMG_2740.PNG`, `IMG_2741.PNG`, `IMG_2742.PNG`,
`IMG_2743.PNG`, `IMG_2747.PNG`, `IMG_2748.PNG`, `IMG_2749.PNG`,
`IMG_2750.PNG`, `IMG_2751.PNG`, `IMG_2752.PNG`, and `IMG_2755.PNG`.

All reference captures are `1170x2532`. The MOBI evidence set now includes 14
golden screenshots, 20 browser-runtime screenshots, and 26 native Android/iOS
screenshots:

- `Home`, `Bookings`, `Schedule`, `Profile`, `Chat`, `Nearby`, and `Admin`
- compact phone: `390x844`, rendered as `1170x2532`
- large phone: `430x932`, rendered as `1290x2796`
- runtime shell states: `home_shell`, `bookings_shell`, and `profile_shell`
- runtime evidence folder:
  `docs/release/evidence/revolut-runtime-2026-06-12/`
- native evidence folder:
  `docs/release/evidence/revolut-native-2026-06-12/`
- motion-proof attempt folder:
  `docs/release/evidence/revolut-motion-2026-06-12/`

Direct inspection of the reference screenshots confirms these visible rules:

1. Saturated top gradient fading into a near-black lower shell.
2. Top command chrome with avatar, black search pill, and black circular
   actions.
3. Oversized centered hero content before secondary lists.
4. Four-wide circular action rows with short labels.
5. Heavy translucent panels with low-contrast borders.
6. White or black pill CTAs rather than saturated filled buttons.
7. Floating black bottom navigation with active capsule treatment.
8. Low-copy rows and cards with strong icon/avatar anchoring.
9. Large product-section panels that fill horizontal space.
10. Visual depth from gradient, blur, opacity, and spacing, not heavy shadow.

## MOBI Contract Alignment

Authoritative source surfaces:

- `design.md`
- `packages/design-system/lib/src/theme/`
- compatibility exports in `lib/core/theme/`
- shared widgets in `lib/shared/widgets/`
- launch/PWA/bootstrap colors in `pubspec.yaml`, `web/`, and Android
  `values-v31`

Current aligned tokens:

| Role | Token | Value | Status |
| --- | --- | ---: | --- |
| Primary brand | `brandPeriwinkle` | `#8885F0` | aligned |
| Secondary warmth | `brandDustyRose` | `#D38B96` | aligned |
| Urgent/error | `brandOrangeRed` | `#FF5E43` | aligned |
| Success/live | `brandMintGreen` | `#3CD070` | aligned |
| Base shell | dark background | `#02030A` | aligned |
| Command/navigation chrome | tokenized black alpha | extension-backed | aligned |
| Secondary info | `info`, `aqua`, `caution` | tokenized | aligned |

## Critical Gap Matrix

| Area | Current MOBI state | Revolut target | Gap | Severity |
| --- | --- | --- | --- | --- |
| Reference evidence | 12 Revolut PNGs inspected at `1170x2532` | Inspectable source screenshots | Closed for static reference inventory | Done |
| Visual proof | 14 MOBI goldens, 20 browser-runtime screenshots, and 26 native screenshots pass for the main matrix | Native device screenshots plus transition endpoints | Android/iOS screenshot blocker is cleared; motion video was attempted but remains blocked | P0 |
| Top chrome | Home runtime and native proof match avatar/search/circular-action grammar | Same command grammar on every main route | Covered on shell, nearby, profile, bookings, and schedule evidence | Done |
| Hero rhythm | Home uses centered transport hero and large numeric focus | Revolut uses oversized single-value/section hero | Good direction; segmented mode control adds product density | P1 |
| Action row | Home uses circular Nearby/Schedule/Trips actions | Revolut uses four circular actions | Add/justify fourth action only if product-owned | P1 |
| Bottom nav | Floating dark nav exists in app shell | Five-slot floating black nav in reference | Three-slot shell is a `design.md` product constraint | P1 |
| Panels | Metric/cards use dark translucent panels | Heavy full-width translucent panels | Some MOBI cards are more bordered and operational | P1 |
| Bookings/Profile/Chat | Golden, browser-runtime, Android native, and iOS native covered | Low-copy list/detail panels | Pushed chat/detail proof captured natively | Done |
| Static launch/PWA | Legacy splash/static colors replaced | No contradictory pre-app flash | Android/iOS native screenshots show no contradictory post-launch chrome | Done |
| Landing CSS | Four-color/dark contract applied | Same visual language as app | Aligned; keep zero letter-spacing | P1 |
| Admin | Dark operational cards, golden-covered | Analytics-like dense panels | Accept density; admin is not consumer Revolut parity | P2 |
| Copy density | Reduced contract language and stale labels | Reference has very sparse explanatory text | Continue deleting helper paragraphs while touching screens | P2 |

## Findings

### P0: Motion proof is still blocked, so 100/100 is still overreach

The source direction is strong, `flutter analyze --no-pub` is clean, focused
preview tests pass, the Revolut-reference golden matrix passes, browser runtime
screenshots cover the main matrix, and native Android/iOS screenshots now cover
pushed details, shell endpoints, scroll states, safe-area behavior, and dense
route states. Full repo release gates also pass at the Flutter and linked
backend layers. A 100/100 claim would still be overreach because motion/video
proof is not captured yet and product approval is still needed for the remaining
density differences.

Motion proof was attempted on 2026-06-12:

- iOS simulator debug build was blocked by generated SwiftPM/package target
  integrity reporting an iOS 13.0 minimum against Firebase products that require
  iOS 15.0 or higher.
- Existing simulator app recording was blocked when `simctl` became
  unresponsive.
- Android Pixel 4a debug proof builds succeeded, but install was blocked by the
  existing release-signed `rw.mobi.app` on the device.

Evidence:
`docs/release/evidence/revolut-motion-2026-06-12/README.md`.

### P1: MOBI now matches the core Revolut shell grammar

The inspected reference screens and MOBI home runtime screenshot both use a
saturated top-to-black gradient, black pill search, circular command actions,
large center hierarchy, circular quick actions, icon-first chips, and dark
translucent lower panels. This is the strongest parity area.

### P1: Runtime and native QA found and fixed visual blockers

The browser-runtime capture exposed a chat preview crash in profile web mode and
tiny raster vehicle thumbnails inside Revolut-style chips. Chat preview now uses
a deterministic local trip instead of debug-only constants, and vehicle
surfaces use Lucide icons for a cleaner reference-aligned treatment. Native
proof also exposed timing drift in the capture harness, so the Android proof
target now accepts launch links for deterministic per-screen capture.

### P1: MOBI is still denser than the reference

The Revolut captures keep section pages extremely sparse: one large hero, one
wide pill CTA or one action row, then a small number of full-width panels. MOBI
still exposes operational transport controls earlier: mode toggle, availability
state, metrics, vehicle chips, and route actions. This is acceptable for product
utility, but it prevents exact visual sameness.

### P1: Static shell contradictions have been removed

Native splash, web bootstrap, PWA manifest, Android 12 splash styles, iOS launch
backgrounds, and the landing page no longer carry the older green/static launch
language. The regenerated Android/iOS launch PNGs sample to `#02030A`.

### P1: The three-tab shell is an intentional design-contract difference

The reference uses a five-slot bottom nav. MOBI currently preserves a three-tab
product shell under `design.md`. Do not add fake top-level tabs just to mimic the
reference. Only promote real destinations if MOBI approves them as first-class
product routes.

### P2: Legacy naming is now compatibility-only

`ClayCard` remains as a source-level compatibility alias, but the public product
language and current behavior are dark translucent panels. New docs and UI copy
must not reintroduce legacy surface language.

## Required Cleanup State

The following are not allowed in active design-facing surfaces:

- legacy brand narrative
- legacy public surface language
- generic Material colors as brand substitutes
- unsupported payment, crypto, invest, rewards, or bank-account labels
- long helper paragraphs where a chip, badge, icon, or direct action is enough
- splash or PWA colors that flash a different brand system before Flutter loads
- nonzero letter spacing in app or landing UI

The following are allowed:

- the four MOBI colors as primary brand nodes
- black, navy, violet-depth, and translucent surface neutrals
- `info`, `aqua`, and `caution` as secondary semantic tokens
- source-level compatibility aliases when changing names would create churn
- three product-owned tabs while the product contract remains three-tab

## Acceptance Gates

1. Done: reference folder inventory is accessible and contains 12 PNG captures.
2. Done: active scanned files contain no legacy splash/static brand tokens.
3. Done: `flutter analyze --no-pub` passes.
4. Done: focused local preview widget tests pass for Home, Bookings, Schedule,
   Profile, and Chat.
5. Done: golden screenshots cover Home, Bookings, Schedule, Profile, Chat,
   Nearby, and Admin at `390x844` and `430x932`.
6. Done: browser-runtime screenshots cover 10 screen/shell states at `390x844`
   and `430x932`, with zero real browser errors in final capture logs.
7. Done: native Android and iOS screenshots cover 13 states each, including
   shell endpoints, pushed/detail surfaces, scroll states, and safe-area
   behavior.
8. Blocked: capture motion/video proof for animated transitions. Current
   blockers are documented in
   `docs/release/evidence/revolut-motion-2026-06-12/README.md`.
9. Remaining: get product approval for the remaining transport-density
   differences before any 100/100 claim.

## Current Verdict

MOBI is now close enough to the Revolut visual system to use the reference as a
serious design benchmark, and the browser-runtime plus native-device evidence
materially improves the proof position. It is still not close enough to certify
100/100 release parity. The remaining work is unblocked motion proof, selective
density approval/reduction, and release-signing/Play evidence, not another broad
token rewrite.

Do not rebuild the AAB for this design pass.
