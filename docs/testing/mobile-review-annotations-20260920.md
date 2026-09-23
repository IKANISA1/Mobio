# Mobile review annotations — EV chargers and scheduled trips

This local review batch implements the five additional browser notes after the
navigation/accessibility pass. It preserves the earlier review changes.

## Changes

- EV charger cards no longer show connector-type and power badges. The managed
  catalog data remains available to admin operations.
- Each card has separate **Open in Google Maps** and **Chat** buttons. Chat uses
  the existing WhatsApp SVG and the charger's saved Rwanda mobile number. Missing,
  malformed and short-code contacts leave Chat disabled with an accessible
  explanation. The preview fixtures contain no contact numbers. No operator
  numbers were invented, and tests intercept external launches.
- The actions have charger-specific accessible names and at least 48-pixel
  targets. They sit side by side at standard phone width and stack at narrow
  widths or enlarged text sizes.
- Home scheduled cards now open their own trip details in the production router
  and local preview. They support touch, keyboard and semantic activation, with
  Back returning to Home. Unknown preview trip IDs show a not-found state rather
  than substituting another trip.
- Default active/approved badges are removed from trip details. A cancelled trip
  retains its meaningful cancellation indication.
- The Fare row, fare fallback text and fare prompts in trip guidance and the chat
  composer are removed.

## Local verification

Flutter 3.44.3 from `/Users/jeanbosco/Developer/flutter_3_44_codex/bin`:

- 112 focused cases pass across the completed runs: nine charger action cases,
  55 production navigation cases, six preview navigation cases, 15 affected-screen
  accessibility cases, plus existing Home, layout and scope contract checks.
- Charger tests intercept Google Maps and WhatsApp launches, verify the selected
  location and normalized contact, reject unavailable contacts, and cover launch
  failures and 200% text at 320-pixel width.
- Accessibility checks cover EV chargers, trip details, Home, the Home shell and
  chat in light/dark 390-pixel layouts and dark 320-pixel layouts at 200% text.
- Static analysis reports no issues. Repository structure, whitespace and
  secret-pattern checks pass.
- Native Android packaging remains blocked by missing configured public runtime
  values. No installed-device or production release acceptance is claimed.

Raw logs and the case-by-case verification manifest are under
`build/qa/navigation-accessibility-20260920/annotation-batch-9-*`. Earlier test
harness failures are retained; the manifest identifies the successful reruns.
The preview build and source-hash receipt are under
`build/ui-review-20260920/comment-batch-9/`.

The browser check confirmed the matching selected trip, return to Home, removed
fare/status content, and named charger actions. It also exposed a disabled-button
colour filter obscuring the WhatsApp logo. The follow-up preserves the SVG colours
while retaining the disabled state, grey text and unavailable-contact explanation.
It is grouped into `comment-batch-10`; other buttons retain their existing styling.
All 19 follow-up charger/shared-button/accessibility cases pass, and analysis is
clean. Their logs use the `annotation-batch-10-` prefix in the same evidence folder.

## Agency preference — batch 11

- Added **Any** as the first scheduling choice, including when the catalog is
  empty or the search text matches no named agencies.
- Any passes bus-agency validation and is stored as `Bus agency: Any` in the
  scheduled-post note. Editing restores that selection and preserves pickup,
  drop-off, departure time and free-text notes. It is a preference, not a managed
  transport-agency record. Existing suggestions use the saved trip ID without an
  agency constraint.
- Fixed the note cleanup pattern that previously left part of an old agency
  name when editing. Agency choices announce their selected state and the list
  scrolls within the available sheet height when large text and a keyboard reduce
  the available space.
- All 26 focused model, picker and scheduling/transport contract tests pass;
  analysis reports no issues. The widget coverage includes creating/editing with
  Any, returning to a named agency, empty/search states, and 200% text with a
  keyboard at 320 × 640. Test and analysis logs use `annotation-batch-11-`.
- The review preview is rebuilt as `comment-batch-11`. These local checks do not
  establish a new live backend or native-device acceptance result.

The browser check found duplicate button nodes around agency choices and a
repeated search-field label. Batch 12 removes the redundant semantics wrapper
and excludes the visual hint from announcements while retaining the persistent
search label. This follow-up is checked with the same focused suite before one
grouped preview rebuild. All 26 cases pass and analysis is clean; logs use the
`annotation-batch-12-` prefix and the preview build is `comment-batch-12`.

## Full agency catalog — batch 13

- Added all 43 names supplied in the review to the shared offline/preview
  catalog. Scheduling offers 44 choices with **Any** first; driver profiles use
  the 43 agency names without an Any preference.
- Added `20260920120000_expand_transport_agency_catalog.sql` to populate the
  managed production catalog. It preserves existing agency IDs, contact details,
  activation states and linked records, adds only missing names, and creates no
  contact, fleet or timetable data. Existing Trinity Express and Volcano Express
  names map to TRINITY TRANSPORTERS and VOLCANO so saved selections still work.
- All 32 model, picker, profile and transport contract cases plus two preview
  provider cases pass. Coverage checks the 43-name migration/preview parity,
  retained Any preference, older saved names, case-insensitive search, the final
  agency and long labels at 200% text on a 320 × 640 screen.
- Analysis, repository structure, secret scan and SQL parsing pass. A database
  execution check could not run because local Docker did not respond within the
  bounded check. The migration has not been applied to a live database.
- Evidence uses `annotation-batch-13-` in
  `build/qa/navigation-accessibility-20260920/`; the complete preview batch is
  rebuilt once as `comment-batch-13`.
