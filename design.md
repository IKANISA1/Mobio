# Mobio design system

Version 6 · 6 September 2026. This contract includes the 5 September follow-up for missing launch/auth states and the full applicable colour families. Product scope, permissions and server contracts remain governed by `AGENTS.md` and the dated product approvals.

## Reference and identity

Mobio retains its name, logo, app icon, feature names, legal entity and real capabilities. The native visual reference is the September 2026 iOS Dark · Glow cohort. Marketing uses the current UK public website's editorial composition and typography. Admin uses official Business imagery for surface/hierarchy patterns, with explicit adaptations for Mobio's operational tables. These are three separate reference cohorts; none is evidence of the others' exact tokens or behavior.

The current source, colour-role and route/state map is in `docs/design/colour-and-auth-followup-20260905.md`; the earlier geometry report is `docs/design/reimplementation-20260905.md`. Private account captures stay outside this repository. Reference marks and screenshots are not runtime artwork. No percentage or pixel-equivalence claim follows from passing tests or capturing target screens.

## Shared implementation

- Semantic tokens: `packages/design-system/lib/src/theme/`.
- App controls: `lib/shared/widgets/`.
- App shell: `lib/app/shell.dart`; four branches: Home, Trips, BioPay, Profile.
- Feature presentation: `lib/features/*/presentation/`.
- Admin primitives: `lib/features/admin/presentation/widgets/admin_ui.dart`.
- Marketing and legal pages: `landing/`.

Use one component for repeated jobs. Preserve existing route callbacks, WhatsApp OTP, confirmation steps, retry actions, permissions, server-owned balances and external USSD handoffs.

## Native semantic contract

The dark canvas is black; grouped widgets use #161618 with #222224 and #303033 for raised/selected states. Foreground is #F4F4F4, secondary text #A1A1A3. These are Mobio semantic adapters informed by the reference, not asserted native source-code values. Light mode uses the paired neutral theme. Brand logo colours remain intact.

Inter is the bundled native typography adapter; the installed reference app's exact font/build were not exposed. Display is 30–36, pushed-page title 24, section title 18–20, row title 16, body 14–16, labels 11–13. Headings use 600, labels 500, body 400. Avoid heavy 800/900 headings and shrink-to-fit text. Allow enlarged text to wrap; a constrained pushed title can scroll while its back control stays available.

Use a 4-point spacing grid, 16 horizontal page insets, 24-radius grouped mobile panels, and 48 minimum icon targets. Primary buttons are contrasting pills, at least 52 high, with stable loading geometry. Ordinary surfaces are opaque and flat. Home uses royal blue, BioPay teal, Trips/Nearby purple, Wallet muted slate blue-violet, Profile/Mobio Plus vivid violet and WhatsApp login slate-indigo. Their wash scrolls away into a matching lower canvas. Pushed tasks, chat and admin retain quiet neutral surfaces. Do not spread decorative gradients, borders and shadows across every card.

Quick actions use 48 circles with labels inside the entire tap target. Bottom navigation uses a fully opaque neutral near-black capsule, a subtle neutral outline and a grey selected pill across the coloured route families (DESK-003, 5 September 2026, 408×857 phone capture). It has no backdrop blur or translucent white gradient. The semantic navigation roles are Mobio adapters: surface #161618, selection #303033, selected foreground #F4F4F4, secondary foreground #A1A1A3. The same high-contrast capsule in Light mode is an explicit Mobio adaptation pending matching source Light evidence. It floats above system safe areas and exposes selected semantics, keyboard activation and four real destinations. Secondary routes use a back control. Native UI and browser previews respect reduced motion.

## Screen patterns

Home places nearby availability first, followed by compact actions and discovery rows. Trips puts routes/times/status ahead of support copy; create/edit/details keep existing validation. BioPay uses a centered identity overview with Face Scan, NFC Tap, Get QR and Scan QR, followed by payment-link and insurance actions. QR contrast, camera permissions, NFC progress, request expiry and network handoff remain functional requirements.

Profile leads with identity and groups settings. Wallet and Mobio Plus preserve server-authoritative balances, plans, confirmation and recovery. Nearby and EV discovery retain filters, permission handling and external maps. Chat preserves composition, keyboard clearance and message state. Empty/error/loading states use the same typography and surfaces with a clear next action.

## Admin

Preserve operational information architecture and permissions. At 1000 logical pixels and above, use a 216-wide sidebar with all existing modules, a quiet heading/action area, and content constrained to 1360. Below that width, use scrollable module tabs; the mobile shell retains its four destinations. The wide shell does not duplicate the workspace sidebar.

Use 16-radius tonal panels, structured filters, status chips, tables/cards and detail sheets. Keep selection visible through Material ink, support keyboard focus, and keep destructive confirmations. Always reduce headline intensity and use the same chip and spacing language across operational screens. Business promotional images support composition only; they do not establish a live desktop breakpoint or full table specification.

## Public website

Use self-hosted Aeonik Pro for editorial headings and Inter for legal copy. The measured website reference is 48/48 mobile H1 and approximately 84/84 at 1267 desktop width; our responsive scale follows those anchors. The website is light and editorial, with a photographic hero, large sections and simple black/white pill CTAs. Image content is original illustrative Mobio artwork, with explicit provenance.

Navigation supports keyboard, Escape, focus return and a small-screen menu. Main content remains available without JavaScript. Native details elements provide FAQ disclosure. Public download, business login, contact and legal links use real destinations; no placeholder store link or unsupported service claim. Policy text is preserved; shared navigation and readable legal layout are updated.

## Verification and release

Use functional tests for journeys, accessibility checks for large text/keyboard and target captures for inspection at 390×844, 430×932, 768×1024, 1280×900 and 1440×1000 as applicable. Existing historical goldens remain historical evidence; explicit capture mode writes synthetic targets under ignored `output/` and is not a parity pass. Record known differences and evidence gaps in the design report.

Run strict analysis, relevant tests, guarded release packaging and secret checks. A local build, visual inspection, deployment and user acceptance are separate results. Do not publish a synthetic preview as a production app.
