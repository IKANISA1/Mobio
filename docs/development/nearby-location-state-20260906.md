# Nearby location state correction — 6 September 2026

Home and Nearby previously treated missing location permission or a missing
position as a completed search with zero drivers. Nearby also retained earlier
coordinates and drivers when a later location check failed.

## Behavior

- Discovery returns a complete snapshot with location access state, origin and
  drivers. Unavailable snapshots contain no coordinates or drivers.
- Home shows an unknown count (`—`) while loading, on failure, or without a usable
  location. Only a completed search can display a numeric zero.
- Missing permission shows **Enable location**. Other location failures show
  **Location unavailable** with a retry action. Scheduled posts remain available
  without location permission.
- Nearby clears its old origin and drivers at refresh, including the map data.
  Both screens refresh on app resume and reject responses from older requests.
- Permission is checked before using cached positions and after asynchronous
  work. Permission loss during a query discards the query's result.
- Driver-query errors propagate to the existing error/retry UI instead of
  appearing as zero drivers. Home observes its concurrent futures together so
  those errors are handled even if another request has not finished.

The existing blue Home and purple Nearby visual families, shared banner tokens,
navigation and driver-sharing consent flow are retained. This is a state and
recovery correction, not a new visual-fidelity certification.

## Verification

- Focused suite: 24 tests passed. New regression coverage includes denied,
  permanently denied and restricted permission, disabled location services,
  missing position, successful empty search, lost permission/position after
  populated results, permission loss during a pending query, cached-position
  access checks, error propagation and unknown-versus-zero counts.
- Recovery-banner actions and layout passed at 320 px width with 200% text size.
- Focused and full Dart analysis: no issues.
- Full Flutter suite: 540 tests passed, including existing visual baselines.
- Repository structure, secret scan and diff whitespace checks passed.

- iOS simulator debug build passed and was installed over the existing app,
  retaining the signed-in review session. Home displayed `—`, **Location needed**
  and **Enable location**; its action opened Nearby. Nearby displayed the access
  prompt without a false empty-driver message. Opening the permission explanation
  and choosing **Maybe later** preserved that state. Background/resume also
  returned to the correct state.
- The web app, admin and combined website/PWA bundles rebuilt and passed their
  bundle validation. No public deployment was performed for this correction.
- The sampled simulator log contained zero FlutterError, unhandled-exception or
  RenderFlex-overflow matches during startup and the affected-screen checks.

Local captures and machine-readable results are in
`build/qa/location-state-20260906/`. Permission revocation and lost-position
transitions are covered by automated tests; no physical-device location test or
live permission grant was performed. No production data or backend configuration
was changed. The Android binary was not rebuilt for this correction.
