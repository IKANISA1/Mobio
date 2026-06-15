# Design Navigation Accessibility Audit - 2026-06-15

## Scope

Screen-by-screen pass against Mobio/Revolut expectations: alignment, navigation, responsive layout, tablet/admin behavior, text fit, semantics, keyboard/back flow, loading/empty/error states, and route entry/exit consistency.

## Current Evidence

- Current split Flutter QA previously passed 245 + 37 non-preview assertions and 97 preview/golden assertions, including Revolut mobile goldens and admin desktop goldens.
- Current Revolut reference visual gate has been expanded beyond the previous 104 preview/golden assertions, adding wallet, Mobio Plus, login, BioPay NFC write-card, actual admin users/trips, and admin agencies coverage.
- Current profile/Mobio Plus text-fit changes pass focused contracts, analyzer, and profile/edit-profile/profile-setup goldens.
- Route matrix first pass exists in `docs/reports/route-screen-matrix-2026-06-15.md`.

## Worklist

| Area | Required evidence | Status |
| --- | --- | --- |
| Mobile shell and bottom nav | Tap targets, semantics, selected state, safe-area behavior | Bottom-nav widget semantics covered; full device safe-area review pending |
| Wallet/tokens/subscriptions | Revolut-aligned spacing, button fit, empty/error/loading states | Contract and mobile golden covered; manual backend edge-state review pending |
| BioPay QR/share | Save/share affordance, gallery/share failure handling, no overlap | Contract/golden covered, device interaction proof pending |
| Profile/edit profile | Read-only WhatsApp, first-run setup, keyboard/back flow | Contract and goldens passed; manual keyboard/back-flow proof pending |
| Scheduling/bookings/trip details | Empty/error/loading, edit flow, back flow | Golden and contract covered; manual device back-flow proof pending |
| Chat/report/block | Message composer, blocked/report modals, error states | Contract and mobile golden covered; manual device composer proof pending |
| Admin tablet/desktop | 768/1024/1280/1440 goldens, responsive nav, table/card density | Golden-covered across 768, 1280, and 1440 desktop viewports, including actual users/trips and agencies; manual review pending |
| Accessibility | Semantics labels, keyboard focus, text scale, contrast | Targeted widget semantics covered; broad text-scale/focus audit pending |
