# Mobio whole-product design reimplementation

Worktree based on `a60cdfb8e69815f6c84928c93810ebcdd658040b`, 5 September 2026. Scope includes the Flutter mobile presentation, public marketing/legal website, and Flutter admin panel. Existing repository architecture and server contracts are preserved. This report records source provenance and validation; it does not certify pixel equivalence or production deployment.

## Cohorts and comparison method

Native: the owner's September 2026 live iOS Dark · Glow captures, with unknown installed build and account-region applicability. Originals are 406×890; the approximate inner phone rectangle is x8..398, y38..882, equivalent to a 390×844 comparison coordinate model. The Mac frame, pointer and bug-report capture banner are excluded from comparison. No claim is made that those raster pixels establish a device's native logical scale. Exact source hashes are in `reference-sources-20260905.json`.

Actual images inspected: LIVE-020 Home, LIVE-006 Profile lower, LIVE-007 Settings, LIVE-051 Payments full header, LIVE-058 recipient form, and official Business `bills-preview.png`. Target-only screenshots use synthetic Mobio fixture data. Private captures and real account contents are not copied into this repository or the app.

Marketing: current UK homepage composition and measured source styles from the selected skill, plus official [public homepage](https://www.revolut.com/) content. A direct browser visit during this run hit Cloudflare's human check, so a freshly composed live browser comparator is unverified. The source's desktop 1267-wide H1 measures about 84.42/84.42 and mobile 390-wide H1 48/48. Target mobile uses 48/48; desktop is a responsive adapter. Public site artwork is original Mobio content, not a source account screen.

Admin: official [Business 5](https://www.revolut.com/business/rb5/) material and inspected bills promotional composition support tonal hierarchy. They do not establish an authenticated desktop table, current permission behavior or a measured desktop sidebar breakpoint. Mobio's 216-wide sidebar at 1000 and operational tables are explicit adaptations.

## Identity and assets

The existing `icon/mobi_logo_transparent.png` and `landing/assets/mobi_icon.png` retain Mobio's artwork and natural aspect ratio. The app icon, manifests, application identifiers, domains and provider integration names remain Mobio's. Home/Trips/BioPay/Profile are existing destinations; the source's other products are not added. Wallet TOKENS and Mobio Plus retain their existing product meaning.

Website fonts are the selected collection's public website font files: `29743adaf2380513.woff2` → AeonikPro-Medium, `c064293ff7b94e55.woff2` → AeonikPro-Regular, and `749a01271caa900f.woff2` → Inter-Regular. They were copied under the owner's supplied reference-asset scope. This records provenance, not a new independent font licence determination. Native Inter is the repository's already bundled adapter; exact native source font identity remains unverified.

The illustrative Kigali campaign photo was generated for Mobio on 5 September 2026. It represents no real customer, current fleet inventory or photographed endorsement. Runtime uses a 1536×1024 JPEG encoding (377 KB); the lossless master remains in local ignored evidence and the generated-image archive. Alt text identifies the scene as illustrative. Hashes and sizes are in `runtime-assets-20260905.json`.

## Route and state comparator map

All 41 literal router paths are enumerated in `routes-20260905.json`. The mappings below cover the active routes and aliases; a pattern mapping is not direct route parity.

| Mobio routes | Comparator / intentional adaptation | Target states covered by presentation and tests |
|---|---|---|
| `/` | LIVE-020 overview; mode control replaces account search, nearby count replaces balance, 3 real discovery actions; 4 target tabs replace 5 source tabs | Passenger/driver, available/empty, online/offline/permission recovery, notifications, shell navigation, 200% text |
| `/bookings`, `/nearby`, `/notifications`, `/ev-chargers` | LIVE-051 list and LIVE-007 grouped rows; mobility metadata, filters and external maps are adapted | Populated/empty, filters, role mode, location/address lookup, permissions and retry; EV preview |
| `/schedule`, `/trip/:id`, `/trip/:id/edit` | LIVE-058 form and LIVE-007 grouping; place/date/vehicle controls and trip detail adapted | Create/edit/details, invalid input, note expansion, keyboard, 200% text, cancel/confirmation contracts |
| `/chat` | LIVE-051 contact/list hierarchy plus adapted conversation and composer | Synthetic conversation, keyboard/large text, send/retry contracts, external WhatsApp handoff |
| `/profile`, `/admin/profile` | LIVE-006/007 identity and grouped settings; Mobio member ID and supported settings retained | Profile, theme toggle, BioPay enrollment status, back and linked settings |
| `/edit-profile`, `/profile/setup` | LIVE-058 form/segmented choices; role and vehicle onboarding adapted | Existing/first-run profile, field validation, large text and keyboard |
| `/wallet`, `/mobio-plus` | LIVE-020 value hierarchy and LIVE-007 grouping; TOKENS, rewards, plans and MoMo actions are Mobio adaptations | Populated preview, unavailable/retry, server-authority and confirmation contracts |
| `/login` | Native glow and LIVE-058 form anatomy, adapted WhatsApp OTP | Entry, invalid/disabled, request/verification/recovery tests, keyboard and large text |
| `/biopay` | LIVE-020 overview and native action anatomy; identity headline and four supported actions adapted | All Face/NFC/QR/request callbacks; insurance loading/recovery retained |
| `/biopay/qr`, `/biopay/request-payment` | LIVE-058 recipient form/amount hierarchy; QR/export/request generation adapted | Number/code, invalid/valid receiver, amount, QR/link generation, share/save and external USSD contracts |
| `/biopay/pay/:token` | Native form and shared status surfaces; external handoff is Mobio-specific | Expired-request recovery capture; existing handoff service tests |
| `/biopay/scan`, `/biopay/face-scan`, `/biopay/enroll`, `/biopay/nfc`, `/biopay/nfc/write-card` | Adapted device journeys with shared native headers/buttons; no direct reference hardware comparator | Permission/standby/scanner, enrollment/retry and write-progress states; validation and mocked device contracts |
| `/admin-auth` | Business neutral surfaces with native form/OTP adapters | Allowlisted login entry, disabled/invalid/restricted and auth contract checks |
| `/admin`, `/admin/users`, `/admin/trips`, `/admin/vehicle-types`, `/admin/agencies`, `/admin/ev-chargers`, `/admin/subscriptions` | Business promotional hierarchy plus adapted operational sidebar, filters, tables and cards | Wide/tablet/mobile, search/selection/filters, records, details, create/edit/recovery contracts; actual EV recovery and dashboard fixtures |
| `/admin/biopay`, `/admin/reports`, `/admin/health`, `/admin/audit`, `/admin/broadcasts` | Business tonal panels and adapted review queues | State filters, details, audit/recovery, actual and pattern fixtures, responsive confirmation columns |
| `/config-error`, unknown paths | Shared native status pattern, adapted error recovery | Missing-config and not-found presentation |
| `/ledger`, `/admin/finance` | Existing retired/compatibility paths | Existing router scope boundaries retained; no new ledger/finance product introduced |
| Website `/`, three policy pages, `/play-review/foreground-location-demo.html` | Current public website editorial composition; legal and review evidence pages adapted | Desktop/mobile, menu keyboard/Escape/focus return, FAQ disclosure, anchors/download/legal links, readable policy layout |

Physical face/QR/NFC acquisition, OS permission sheets, live WhatsApp OTP delivery, external USSD completion and production admin mutations are not executed by synthetic UI tests. Their platform/service tests remain separate. They are not claimed as visually matched source journeys.

## Geometry and justified adaptations

| Component | Source observation | Implemented target |
|---|---|---|
| Overview content | About 16 inset within the mirrored phone | 16 logical inset |
| Quick actions | About 48 circles with labels | 48 circles; entire label and circle form one accessible action |
| Top controls | About 44 height | 48 minimum touch target |
| Grouped settings | About 56 compact rows, larger explanatory rows | Neutral groups; 32 icon + 12 vertical row padding, wrapping when enlarged |
| Native buttons | About 52 height on observed task pages | Minimum 52, stable loading footprint, contrast/disabled state, keyboard activation |
| Navigation | Floating capsule around 64 high with selected segment | Four actual destinations, 48 targets, safe-bottom clearance; grows with text |
| Pushed title | Source varies by task | 24 title adapter; full enlarged title remains scrollable in a short constrained viewport without shrinking |
| Admin content | Promotional panels only | Natural-height responsive panels so added sidebar cannot clip confirmation content |

The minimum touch-target and enlarged-text changes are small usability adaptations. They are documented rather than presented as exact native pixels. The all-screen styling uses shared semantic tokens; unique feature content remains explicit.

## Validation evidence

The local evidence folder is `output/revolut-reimplementation-20260905/` (ignored). Functional logs, strict analysis, responsive screen captures, website browser evidence and guarded release build logs are retained there. Capture mode uses `MOBIO_CAPTURE_DIR`; it only exports synthetic target renders and never implies source parity. Historical baselines are recoverable from base commit `a60cdfb`.

The completed local test run passed 486 tests, including 145 deterministic visual baselines. Strict Flutter analysis reported no issues. The Python build/configuration helper suite passed 9 tests; repository structure verification covered 1,821 source/document files. Secret scanning and whitespace checks passed. No full-source pixel-equivalence percentage is claimed. Native exact typography, several direct feature comparators, fresh live website rendering, device hardware behavior, production deployment and owner acceptance are distinct remaining evidence boundaries.


### Final review and behavioral evidence

The searchable local gallery at `output/revolut-reimplementation-20260905/gallery/index.html` contains all 145 screen renders plus mobile/desktop website browser captures. Representative views were inspected as complete screens and in six contact sheets. The five actual dashboard recovery captures were regenerated after replacing an exposed provider stack trace with a readable retry message. A dedicated test verifies that private implementation details stay out of that error state and Retry calls the controller. Native button tests cover loading geometry, repeated-action prevention, enlarged text and keyboard activation.

Website browser checks passed at 320, 390 and 1440 widths, with no horizontal overflow, valid internal anchors, working menu focus/Escape/return behavior and native FAQ disclosures. All three policy texts are unchanged from the base commit. The built Pages worker passed seven local routing checks, including marketing, admin-auth, an admin deep link, legal content, the hero asset, manifest and the admin-host redirect. These are local routing results, not production probes.

The synthetic Flutter browser preview rendered Home and the admin workspace, generated an open-amount BioPay QR after entering a receiver, and opened/dismissed a member-detail sheet. No console errors or warnings were observed on those checked pages. The packaged production admin-auth entry exposes a named Back button and a disabled Send code control for the empty number; no OTP was sent. Some existing synthetic data is illustrative legacy content, not current inventory or operating results.

The existing visual-proof host intentionally uses no-op route callbacks. It is a screen-capture harness, not an interactive substitute for the full router. Its admin service returns a fixed member fixture, so filter selection in that browser preview does not prove server-filtered result accuracy. Production navigation/auth contracts are covered separately by the app router and service tests. Full authenticated production workflow acceptance is still unverified.

The last accessibility corrections removed duplicate tooltip contributions from primary navigation/command buttons and added Back, Previous page, Next page and Refresh approvals labels to admin icon controls. The primary release targets for this change are the guarded Android app bundle and combined web Pages package. iOS/device release validation and external provider completion remain outside this local run.


### Verified release artifacts

The final guarded Android release app bundle (83.2 MB as reported by Flutter) and the combined web Pages package both built successfully. The final dashboard recovery text was independently found in the Android arm64 binary and the packaged web JavaScript. Artifact sizes and SHA-256 hashes are recorded in `release-artifacts-20260905.json`. Android emitted existing plugin/deprecation warnings but completed successfully. The synthetic visual-proof web build also completed successfully. No deployment, store upload or external provider transaction was performed.

Final logs: `analysis-final.log`, `all-tests-verified.log` (486 passed), `android-release-final.log`, `web-release-verified.log`, `app-preview-build-final.log`, `browser-verification.json` and `worker-routing.json` under the ignored evidence folder.
