# App navigation and accessibility review

Scope: every active Flutter consumer and admin screen, shared controls, routing,
dialogs and recovery states. Existing browser annotations remain part of this
batch. The preview is a local fixture host; production navigation is checked
separately. This is not a claim of deployment or assistive-device acceptance.

## Work plan

1. Inventory routes, screens, reusable interactions and existing coverage.
2. Fix the Nearby back action and audit return paths, direct entries, tab state,
   loading/error exits, and preview navigation against the production router.
3. Audit real screen fixtures at phone width, narrow width with 200% text, and
   desktop admin width. Check labels, actions and minimum touch targets.
4. Fix shared keyboard/assistive activation and screen-specific findings; add
   behavior regressions for navigation, focus, and accessibility.
5. Run analysis, relevant suites and guarded packaging; rebuild the browser
   preview once after the complete batch. Verify affected journeys in-browser.
6. Record results and remaining native TalkBack/VoiceOver, hardware, deployment
   and user-acceptance checks separately.

## Implementation

- Inventory: 49 production route patterns, including the four expanded payment
  library routes, across 44 screen source files. Redirects and aliases are counted
  as routes, not separate screen designs.
- Nearby has a named top-left Back action. Consumer detail pages preserve pushed
  history and use an appropriate parent for direct entries. Admin detail pages
  fall back to Operations. Loading screens can be left before their library loads.
- Shared icon controls expose a semantic tap action. Discovery cards, vehicle
  filters and selectors support keyboard activation. Input fields retain their
  accessible names after a value is entered. Repeated button names were removed
  from BioPay, vehicle filters and shared admin controls.
- Thirteen fields in BioPay, chat, admin search, location, country/agency search
  and profile forms now keep a name independent of the input value. BioPay and
  place fields grow with enlarged text; hint text uses readable foregrounds.
  Nearby, BioPay flow and admin headers expose heading semantics.
- Touch targets are at least 48 logical pixels for the corrected icon controls,
  chips, recurring days, cancel actions, contact buttons and pagination controls.
- Narrow layouts wrap OTP fields, recurring-day controls, admin actions and
  metrics. Chat context scrolls with messages so enlarged text leaves room for the
  composer. BioPay action and insurance text can wrap without ellipsis.
- Headings and text use semantic foreground colors in both themes. The brightest
  BioPay and wallet gradient stops were adjusted within their existing color
  families for legibility. These small accessibility adaptations are recorded in
  `design.md`; Mobio identity and workflows are preserved.
- Decorative entry, loading and pulse animations respect reduced motion.
- NFC card screen disposal no longer reads a disposed widget ref. Foreground NFC
  suspension is released after cancellation; physical NFC behavior still needs
  device verification.
- The isolated review host now connects its admin navigation destinations. Its
  synthetic data and local navigation are separate from production auth guards.
- Earlier annotation changes are preserved: BioPay headline and removed redundant
  controls, driver request heading, QR scanner simplification and removed Nearby
  Filters action.

## Coverage

| Area | Evidence |
| --- | --- |
| Auth | Login, number entry, sending, OTP, invalid/expired code, resend, verification and rate-limit fixtures |
| Discovery and trips | Home and shell, Nearby, EV chargers, bookings, schedule/create/edit, repeat days and trip details |
| Communication and account | Chat/conversation views, notifications, profile/setup/edit, wallet and Mobio Plus |
| BioPay | Home, QR, scan and camera recovery, face/enrollment, NFC, request/payment-link views; modern payment composer, methods, requests, activity, recents, templates, arrival and NFC-link fixtures |
| Admin | Auth, Operations, users, fleet, agencies, EV, plans, trips, reports, BioPay, health, audit, broadcasts, shared search/filter/sort/pagination and desktop workspace fixtures |
| Recovery and shared UI | Missing/configuration/scope-unavailable views, deferred loading/failure/retry/return, form names, semantic activation, keyboard actions and reduced motion |

The main accessibility matrix contains 187 screen/state/viewport cases: dark and
light at 390 × 844; dark at 320 × 640 with 200% text; admin desktop at 1280 × 900
with 200% text. It checks initial 48-pixel tap targets, names, layout exceptions,
and the scrollable content. It also checks text-field names and sufficient input
height for a complete text line. A separate scrolled-target check distinguishes a
partly clipped 48-pixel control from an actually undersized control; a negative
regression verifies that a 24-pixel control still fails.

Text contrast is checked on standalone 100% text fixtures. Shell overlay contrast
is not inferred from those checks. Existing focused payment tests add narrow,
enlarged-text coverage in the three supported payment languages. These are
representative fixtures and explicit states, not every possible backend record,
modal combination or platform accessibility behavior.

Production-router tests exercise 27 consumer/detail destinations both after a
push and on direct entry (54 cases), including expected fallback destinations.
Preview tests cover four-tab switching at two widths, Nearby return at two widths,
and navigation through 12 admin modules. Production privileged sessions are not
replaced by the preview tests.

## Verification

Local checks use Flutter 3.44.3 and its bundled Dart from
`/Users/jeanbosco/Developer/flutter_3_44_codex/bin`. Raw local evidence is under
`build/qa/navigation-accessibility-20260920/`.

| Check | Result and evidence |
| --- | --- |
| Static analysis | No issues; `analysis-final.log` |
| Functional suite | 761/761 pass in one final full run; `functional-suite-complete.jsonl` |
| Accessibility matrix | 187/187 pass in that full run; includes control/field names, targets, scrolling, complete input text lines, layouts and the stated contrast checks |
| Production return navigation | 54/54 pass; full functional run and `return-11.jsonl` |
| Shared interaction regressions | Six controls tests plus the icon-button regression pass in the full functional run; includes exact accessible names, semantic activation, keyboard activation and reduced motion |
| Preview navigation | 5/5 pass in the full functional run; two-width tab and Nearby checks, plus 12 admin destinations |
| Repository and secrets | Structure checker, `git diff --check` and secret-pattern scan pass |
| Android packaging | Blocked at the required public-runtime-configuration guard; `android-package.log` |

The full suite was rerun after the field, heading, layout and contrast corrections.
All 761 executed cases passed, with no skipped cases. The earlier source-text
wallet assertions were replaced by the existing real-router return coverage.

Browser verification on the first rebuilt batch confirmed top-left Nearby Back,
Home → Nearby → Home, the simplified BioPay home, QR camera-unavailable recovery,
admin Operations → Fleet → Operations and readable light-mode Nearby. Browser
semantics exposed duplicate control names, which were corrected together with
the BioPay wrapping and admin light-mode contrast follow-up. Keyboard activation
is established by widget regressions; a browser automation attempt to focus the
Flutter Back node did not send input and is not counted as a passed keyboard test.

The final `comment-batch-8` browser check confirmed the Request Payment heading,
named MoMo number and amount fields, the name changing to MoMo Pay code with the
mode selector, and Back returning to BioPay. The updated preview remains available
for review. This browser observation is separate from the native reader checks.

The complete initial batch was built once as `comment-batch-6`; the browser
findings are grouped into the subsequent `comment-batch-7` and `comment-batch-8`
builds, with focused checks before each complete follow-up batch. The review host
is served from `build/ui-review-20260920/app` on port 64152. Build logs and source
hash receipts live beside each batch; production auth and release mode are not
enabled in this local fixture host.

Historical Revolut gallery golden comparisons are excluded from the functional
run because the user-approved annotation changes intentionally supersede those
dated images. Their screen fixtures are reused for the accessibility matrix. The
current BioPay admin golden was inspected and updated only for the larger action
targets; this does not constitute a new whole-app visual approval.

## Remaining acceptance

- Native TalkBack and VoiceOver task completion, reading/focus order, announcements,
  system Back/gesture behavior, keyboard/switch control and permission dialogs on
  installed Android/iOS builds remain unverified.
- Authenticated backend/admin outcomes and camera, location, NFC and external-app
  handoffs need live/device checks. The local admin Operations preview renders its
  recoverable load-error state; it does not prove live operational data access.
- The guarded Android packaging check stopped because this checkout has no
  configured `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `PRIVACY_POLICY_URL` or
  `ACCOUNT_DELETION_URL`. No native release artifact was produced. The fixture web
  preview uses the existing public configuration from the prior preview artifact.
- Public website and the separate Android operator SMS utility belong to the
  wider full-system QA plan; this pass covers the Flutter consumer/admin app.
- Deployment, CI, signing/store distribution and owner acceptance remain separate
  gates. The wider full-system QA goal is not marked complete by this pass.
