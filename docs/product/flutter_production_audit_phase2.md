# Flutter Production Audit Phase 2

> Historical snapshot: this 2026-05-01 audit predates the 2026-05-23 Mobio
> limited-scope cleanup. Treat BioPay, payment, SMS ledger, and ride-request
> lifecycle references below as historical findings only. Current product scope
> is `docs/product/scope.md`.

Date: 2026-05-01

## Surfaces Inspected

- Root Flutter app shell: `lib/main.dart`, `lib/app.dart`, `lib/core/router`.
- Passenger/driver auth: `lib/features/auth`.
- Mobility flows: `lib/features/home`, `lib/features/bookings`, `lib/features/nearby`, `lib/features/chat`.
- Profile and driver subscription setup: `lib/features/profile`.
- BioPay, QR, USSD, and biometric flows: `lib/features/biopay`.
- Ledger and payment contracts: `lib/features/ledger`, `lib/features/payments`.
- Admin surfaces embedded in Flutter: `lib/features/admin`.
- Shared UI/state foundations: `lib/shared/widgets`, `lib/core/theme`, extracted `packages/*`.
- Android/iOS/web host config, assets, fonts, localization, and existing tests.

## Issues Found

- Scheduling state could not clear nullable fields such as selected places and route info because `copyWith(null)` preserved old values.
- Scheduling submit returned generic copy for past departure times, missing locations, and missing recurring days.
- Several `AsyncValue` screens showed raw exception text instead of branded, user-safe error states.
- Schedule/profile layouts were unbounded on wide mobile web/tablet viewports.
- Profile country fallback could crash if country data was temporarily empty.
- WhatsApp country loading had no local failure guard despite having fallback country data.
- Ledger loading/error states were inconsistent with the rest of the app.
- Payment client methods assumed in-app intent creation/status APIs, which is no longer allowed for this product.
- Release error fallback was technically safe but visually weak and not aligned with the design system.
- iOS release dependency resolution failed because the app deployment target was below `google_mlkit_commons` requirements.

## Refactors Completed

- Added `MobiAsyncStateView` for consistent Riverpod loading/error rendering.
- Added `MobiFatalErrorView` for release-safe app-level Flutter build errors.
- Added semantics/live-region treatment to reusable empty and error states.
- Hardened `ScheduleTripState.copyWith` with nullable-field clearing.
- Added typed scheduling validation messages for role, route, future departure time, and repeat days.
- Improved schedule screen loading skeleton, validation banner, responsive width, and safe retry state.
- Improved edit-profile error handling, save-error copy, fallback country behavior, and responsive width.
- Hardened WhatsApp country picker loading and empty country fallback.
- Improved BioPay face scan async loading/error presentation.
- Improved ledger summary/list loading and error states.
- Reworked the Flutter payment service to support local USSD instruction parsing only and to fail closed for in-app payment intent/status/session API methods.
- Raised the iOS deployment target to 15.5 across Podfile, Xcode build settings, and Flutter framework metadata.

## Deferred

- Moving auth, API clients, domain services, and shared widgets into packages is deferred until route/auth integration tests are broader.
- Native iOS readiness still needs a clean local CocoaPods install and a signed device/archive pass; after the deployment-target fix, local `pod install` progressed into dependency installation but the Ruby/CocoaPods process became idle and had to be stopped.
- Payment UX should stay explicit that payments happen outside the app by USSD only; app surfaces may show instruction, pending manual confirmation, manually confirmed, disputed, refunded, or cancelled states where backend state exists.
- Push notification tap flows need device-level integration tests.
- Admin screens still need full widget coverage for restricted actions and bulk operations.
