# Mobio colour and authentication follow-up

5 September 2026. Based on `d450e8e`. This supersedes the version 4 colour mapping, which assigned Home and BioPay the same blue and left Trips, Profile and Wallet neutral. It also closes missing launch and WhatsApp state captures. It does not replace product workflows or certify all possible source themes.

## Source boundaries

The six actual images inspected for colour are the owner's Desktop batch DESK-001 and DESK-003–007, captured on 5 September 2026, 408×857. File times: 12.22.50, 12.23.25, 12.23.34, 12.23.46, 12.23.54 and 12.24.13. These are phone captures in the Desktop batch, not authenticated desktop UI. Installed build, account region and exact native tokens are unknown. Colour-managed sRGB samples are rendered observations; interpolation stops in `MobiFamilyPalette` are adapters. The existing LIVE cohort supplies geometry only where mapped by the earlier report. Private images and their account contents remain outside the repository.

Launch uses the inspected historical ONB-00 white launch composition, substituted with Mobio's original mark and name. Native build/date are unknown. Dark launch and native light colour washes are explicit target adaptations. Native launch centers the OS-sized mark; the Flutter/web boot phase adds Mobio's name. They share neutral canvases and contain the original artwork without cropping.

WEB-STATE-002 is the skill's current signed-out public web SSO observation, including 88 resolved `--rui-color-*` variables. Its accent `#6FA0FF`, positive `#1AC097`, negative `#FF5363`, warning `#FF9F0A`, purple `#BF5AF2`, deep purple `#805CFF`, cyan `#0CD9E6`, popover `#28333D` and error input `#330E0C` inform shared roles. Their use in Flutter is an explicit adapter, not a native-token claim. Dark text over bright accent/error buttons and deeper light-theme accent/error text are contrast adaptations. Native neutral groups retain the prior measured adapters. Current native light/high-contrast and authenticated desktop variants remain unverified.

WEB-STATE-001 supplies current marketing button hover opacity, focus rings and dark pill colour. Marketing keeps its separate light editorial composition. Mobio's original CSS illustrations now associate discovery with blue, trips with purple and BioPay with teal; these are marketing adaptations, not copied account UI. Hero photography remains Mobio's own illustrative asset. Admin retains the prior Business promotional hierarchy and operational adaptations; updated shared status/focus colours do not establish full authenticated desktop parity.

## Route and state coverage

All 41 literal routes remain enumerated in `routes-20260905.json`; routing and server contracts are unchanged.

| Routes / surface | Colour family | State treatment |
|---|---|---|
| OS launch; Flutter bootstrap; web pre-frame | White launch / paired black | Original Mobio mark, bounded size; name in Flutter/web; no forced delay |
| `/login` | Authentication slate / blue-indigo, DESK-001 | Empty/ready number, sending, send error, rate limit, OTP, verifying, incorrect/expired code, resend ready; error icon and text accompany colour |
| `/` | Home royal blue / navy, DESK-003 | Passenger/driver, overview, loading/recovery and scrolled canvas |
| `/biopay` | Teal / petrol, DESK-004 | Existing identity/actions, insurance/status surfaces; quiet task children |
| `/bookings`, `/nearby` | Purple / deep plum, DESK-005 | Existing filters, selected state, list rows, empty/recovery |
| `/wallet` | Muted slate / blue-violet, DESK-006 | TOKENS, existing rewards/actions, loading/retry and grouped rows |
| `/profile`, `/admin/profile`, `/mobio-plus` | Vivid violet / blue-violet, DESK-007 | Identity, settings, theme selection, plans and confirmation |
| `/schedule`, `/trip/:id`, `/trip/:id/edit`, `/chat`, `/notifications`, `/ev-chargers`, `/edit-profile`, `/profile/setup` | Quiet neutral | Shared form, selection, focus, disabled, loading, error/success roles; existing task-specific state coverage |
| BioPay request, QR, scan, face, enrollment, NFC, write-card and payment-link routes | Quiet neutral / device overlays | Preserve permission, capture, progress, expiry and external USSD states; both QR renderers use black modules on white |
| `/admin-auth`, admin workspace routes | Neutral Business/SSO adapters | Existing access rules, tables, filters, selection, confirmation, error and recovery; shared semantic role updates |
| `/config-error`, unknown paths | Neutral with semantic error | Existing safe recovery text |
| `/ledger`, `/admin/finance` | Existing compatibility redirects | No restored finance/ledger capability |
| Public marketing and legal pages | Light editorial; distinct illustrative accents | Website hover/focus, links, responsive menu and FAQ; legal content unchanged |

## Colour migration and identity

Removed the old UI aliases and uses of logo-derived periwinkle `#8885F0`, dusty rose `#D38B96`, orange-red `#FF5E43` and mint `#3CD070`. Also replaced the generic `#22C55E` success, yellow scanner accent and Rwanda-colour QR shader with semantic or monochrome roles. Own logo masters remain byte-identical. The native launch derivatives were regenerated through `flutter_native_splash`; obsolete web launch PNGs and the unused derived splash gradient were removed after local archival. No reference mark or private account image is included in runtime.

Source literals are consolidated in the design-system palette/family files. BioPay's fixed camera-overlay neutrals remain explicit adapters for live imagery. Neutral overlays/shadows, light-theme tints and original marketing illustration shades are adapters, not independently evidenced source exports. The reproducible inventory is `colour-role-inventory-20260905.json`, including remaining literals and their classifications. A value's presence in that inventory is not parity proof.

## Interaction corrections

OTP paste/autofill now distributes all six digits, including a full replacement from another focused cell. Backspace can revisit the previous empty cell. Validation colours reset on editing; the error notice retains its words and icon. Send failures respect the server retry interval and expose a countdown. Sending/verifying disables repeated submission. Number change cancels the resend timer and clears the OTP. Passenger/driver and verified-role callbacks remain unchanged.

The country selector now uses readable ISO country labels, country names and dialing codes rather than relying on emoji glyph availability; search and country data remain unchanged. It supports keyboard activation. Segmented selection uses a tonal selected surface, keyboard-capable ink controls and reduced-motion handling. OTP cells no longer inherit square opaque input fills over rounded error surfaces. Both invite and BioPay QR patterns have high-contrast modules with their original payloads; BioPay retains its centered Mobio logo and high error correction.

## Verification and limits

Evidence is kept under ignored `output/revolut-followup-20260905/`. The golden suite adds launch and actual WhatsApp widget states through network-free service overrides. The visual-proof browser entrypoint now opens the real WhatsApp screen for `login` and `login_large_text`; it cannot send messages or create real sessions. Gallery captures use synthetic data, with clear onboarding/theme labels.

Functional tests exercise role/phone forwarding, complete-code paste, success callback, invalid-code correction, number change, server cooldown, single-flight sending, disposal during a request, enlarged text and gradient scroll/reset. Production provider delivery, face/NFC hardware, physical-device launch and production deployment are separate checks. Tests and target-only screenshots do not certify exact source fonts, gradients or every regional/theme variant.


### Checked results

The full regression suite passed **516 tests**, including 169 screen baselines (`tests-verified.log`). After the final OTP accessibility correction, all 27 focused auth/QR/contract tests passed (`interaction-final.log`). The 18 WhatsApp state baselines were recaptured and inspected after that correction. Strict analysis reports no issues; 9 Python configuration/build tests pass. The obsolete source-string assertion requiring a Rwanda-colour QR shader was replaced by checks on the rendered QR widget's black modules, white badge, high error correction and retained payload tests.

Browser checks at 320, 390 and 1440 widths found no horizontal overflow, broken images, missing in-page anchors or page errors. Keyboard focus uses a visible 2-pixel outline. Actual web pre-frame markup was inspected in light and dark with the bootstrap script intentionally paused; both retain the Mobio mark, fit 390×844, and clear on the first-frame event. This is controlled startup-state evidence, not a launch-time benchmark. `ibtool` successfully compiled the regenerated iOS launch storyboard; it is not a full iOS/device build.

The dated gallery contained 171 views (169 Flutter renders plus two website captures), with splash and WhatsApp entry/recovery states first. Its former local generator was removed on 30 September 2026; `scripts/qa/build_design_gallery.py` now delegates to the external skill using current product evidence, without republishing these historical baselines by default. Original Mobio master and web mark were byte-identical, verified against Git in this dated review. No live WhatsApp message, account verification, USSD session, store upload or production deployment was performed.


The final guarded Android AAB (83.2 MB) and combined web package both built successfully. Release hashes and independent checks for launch, retry and numbered OTP labels are recorded in `release-artifacts-followup-20260905.json`. The simulation-only login service is absent from both production bundles. All 18 final WhatsApp visual comparisons pass (`auth-baselines-verified.log`). Android emitted plugin migration notices while completing successfully. Local packaging is complete; no production deployment or store submission is implied.
