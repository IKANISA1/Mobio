# Website QA checkpoint — 14 September 2026

**The local website batch is complete; the full-system QA goal remains active.** Three reproducible website defects were repaired. This is a partial per-surface report, not release or full design acceptance.

## Findings and changes verified

- **FQA-009 — mobile menu:** selecting Get Mobio previously left the overlay open and the destination content inert. All navigation links now dismiss it, keyboard traversal stays inside it, and a script failure retains ordinary links. The fallback was also corrected after a delayed-script test exposed a layout shift.
- **FQA-010 — text contrast:** discovery copy and the Bus label had ratios of 4.47 and 4.29. Existing copy/label colour roles now provide approximately 6.51 and 4.52; the purple surface remains the same.
- **FQA-011 — store-review page:** inherited dark text was nearly invisible, its definition list overflowed on phones, and video metadata changed the layout. Explicit foreground colour, compact definitions and reserved portrait video dimensions fix these issues. The owner's existing review-account behavior and instructions remain intact, as documented in `docs/development/review-login-20260906.md`.

The changed source is `landing/script.js`, `landing/style.css`, `landing/play-review/foreground-location-demo.html`, plus two reusable browser QA runners. Existing recovery edits remain preserved. All changes are local.

## Environment and evidence

Entry: `http://127.0.0.1:8764/`, served directly from `landing/` by a loopback Python HTTP server. Tested pages: homepage, privacy policy, terms, account deletion and the discovered review-video page. **Browser plugin not available**; existing Playwright 1.62.1 ran Chromium 151.0.7922.34 and WebKit 26.5 without installing dependencies. Chrome DevTools Lighthouse supplied independent automated page scans. WebKit is an engine test, not a physical Safari/iOS result.

Samples include 320, 360, 390, 768, 820, 1024, 1440 and 1920 CSS-pixel widths. The loopback server does not apply Cloudflare headers or prove combined app packaging, deployed routing, installed PWAs or store availability.

Source fingerprint: `118db1d54ec5ab193ba625e42a3b72fd8885629d942648430bdba1d1a4cbcdaf`. Landing-file fingerprint: `da567f40df87742e5a1f2c57b702db6af30f522a83284e571688e52511308491`. The full file manifests and per-artifact SHA256 values are in `build/qa/fullstack-qa-20260914/source-binding-after-website.json`, `website-source-manifest.json` and `website-artifacts.json`. No source file outside the three landing files and two runners changed since the previous checkpoint.

## Checks

| Check | Result | Proof and limits |
| --- | --- | --- |
| Page identity, meaningful content, assets and runtime errors | Pass | All five pages identify correctly; no unexpected runtime/asset errors in the final browser run; screenshots contain no framework error overlay |
| Interaction and layout | **104 passed** | Menu open/close, focus, Escape, download dismissal, viewport change, FAQs, legal navigation, reflow, video metadata/play/pause and return home |
| Failure and delayed asset recovery | **10 passed** | Script/font/hero failure and delayed script cases at 390px in both engines; readable content and no horizontal overflow |
| Automated accessibility | **100 in six scans** | Homepage desktop/mobile and four secondary-page mobile scans; SEO and best practices also 100; this is not full WCAG conformance |
| Flutter regression | **611 passed** | Full suite after menu/copy work; subsequent review-page markup checked with 16 focused scope tests; Dart source unchanged |
| Packaging helpers | **27 passed** | Synthetic precompiled fixture, not a release build |
| Analysis, structure, secret scan and diff hygiene | Pass | Logs retained; latest changes are HTML/CSS/JavaScript |
| Guarded combined PWA build | Unverified | Stops before compilation: four mandatory public runtime values missing |
| Firefox | Unverified | Matching Firefox build 1538 absent; older installed build 1511 was not substituted |

The first browser run mixed real failures with harness observations. WebKit uses Option/Alt+Tab to include links under its default navigation preference; FAQ and viewport-change assertions now wait for their actual resulting state within a bound. The original failed logs remain available. Neither timing correction nor browser unavailability is recorded as a new product defect.

## Interaction and performance observations

The principal flow was homepage → open mobile menu → Get Mobio → visible download section with released page content. Other verified flows were keyboard menu traversal → Escape → restored toggle focus; each FAQ → Enter open → Space close; legal navigation → correct page; and review page → video metadata → muted playback → pause → homepage.

In the controlled delayed-script Chromium test, local CLS fell from about 0.152 to 0.018. Normal and hero-failure runs recorded zero; the font-failure run was about 0.018. WebKit does not expose layout-shift entries here, so its CLS is **null/unavailable**, not zero. On the review-video page, the measured Lighthouse CLS fell from 0.315 to zero after reserving video space.

The final account-deletion scan recorded CLS **0.100195**, compared with roughly 0.064 in an earlier local scan. This near-threshold variation remains a performance observation for controlled network/font-loading work. No field percentile, throttled-device result or full Core Web Vitals pass is claimed.

## Visual comparison and remaining acceptance

The selected reference remains the skill's dated UK photographic blue hero, Aeonik marketing typography, neutral pills and responsive editorial hierarchy. Mobio retains its own logo, campaign image, content, destinations and approved capabilities. Menu fallback, contrast corrections and the compact review definition list are explicit usability adaptations.

| Comparison item | Current evidence | Status |
| --- | --- | --- |
| Public hero and marketing typography | Skill's 5 September observations; target desktop/mobile captures | Pattern reviewed; exact source image comparison unverified |
| Mobile menu | Target open/closed/fallback captures and actual interactions | Local usability verified; exact source comparison unverified |
| Legal and review utility pages | Own content, readable surfaces and responsive layout | Explicit adaptation; full visual acceptance unverified |
| Live source access | Official homepage browser returned a 403 security check | Excluded from visual evidence; no bypass attempted |

The [official reference homepage](https://www.revolut.com/) was also readable through the web text tool, but text is not screenshot evidence. Its security-check captures are labelled and excluded. No source account was opened or source-branded artwork copied into Mobio.

Remaining website acceptance includes deployed source/header/cache identity, actual website-to-app/Admin/store journeys, Firefox, actual 200%/400% browser zoom, screen-reader traversal, media accessibility review, complete source matching, controlled performance and owner/independent review. The web tool could not open the Play Store destination; that is an access limitation, not evidence that the listing is absent. The four initial website journey groups were expanded into five explicit page acceptance groups, all still unverified beyond their local proof cases.

Across the system, database/storage/realtime integration, native builds/devices, authenticated Admin/app journeys, installed PWAs, providers and the remaining semantic inventory continue. **Release remains NO-GO.**

## Repeatable commands

Start the server with `python3 -m http.server 8764 --bind 127.0.0.1 --directory landing`. Use an already installed Playwright runtime, set `PLAYWRIGHT_MODULE` to its module path when it is outside repository resolution, then run:

```sh
node scripts/qa/verify_landing_browser.mjs /absolute/path/to/browser-evidence
node scripts/qa/verify_landing_resilience.mjs /absolute/path/to/recovery-evidence
```

The runners permit loopback targets only. The checked executable commands and exact current runtime versions are retained in this checkpoint's logs. No messages, logins, provider requests, deployments or store uploads were performed.

## Screenshots

Mobile menu after repair, navigation with JavaScript disabled, and the readable review-page header. These are local implementation captures, not source-fidelity acceptance.

![Mobile menu](/Users/jeanbosco/Projects/Recovered-PRO-G40/Mobio/build/qa/fullstack-qa-20260914/website-final-4/chromium-menu.png)
![No JavaScript navigation](/Users/jeanbosco/Projects/Recovered-PRO-G40/Mobio/build/qa/fullstack-qa-20260914/website-final-4/chromium-no-js-mobile.png)
![Review page header](/Users/jeanbosco/Projects/Recovered-PRO-G40/Mobio/build/qa/fullstack-qa-20260914/website-final-4/chromium-review-page-header.png)
