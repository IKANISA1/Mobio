# Revolut Recommendations Implementation Log

Date: 2026-06-13
Goal source: `docs/product/revolut_full_repo_flutter_admin_comparative_audit_2026-06-13.md`

## Completed in first implementation slice

- Corrected the initial BioPay visual pass after design review: the original BioPay structure, copy, and four-tile flow remain intact instead of being replaced by a new dark shell.
- Preserved the existing `Pay & Get Paid Instantly` hero and the original `Face Scan`, `NFC Tap`, `Get QR`, and `Scan QR` actions.
- Applied only a restrained Revolut-style tactile treatment to the original BioPay cards: scroll physics, subtle card elevation, light borders, and icon-box shadow.
- Kept BioPay QR, scan, face scan, face enrollment, and NFC subflows on their existing product-specific structure while retaining route-level visual evidence.
- Updated BioPay golden baselines:
  - `test/features/preview/goldens/revolut/biopay_home_390x844.png`
  - `test/features/preview/goldens/revolut/biopay_home_430x932.png`
  - `test/features/preview/goldens/revolut/biopay_qr_390x844.png`
  - `test/features/preview/goldens/revolut/biopay_qr_430x932.png`
  - `test/features/preview/goldens/revolut/biopay_scan_390x844.png`
  - `test/features/preview/goldens/revolut/biopay_scan_430x932.png`
  - `test/features/preview/goldens/revolut/biopay_face_scan_390x844.png`
  - `test/features/preview/goldens/revolut/biopay_face_scan_430x932.png`
  - `test/features/preview/goldens/revolut/biopay_face_enroll_390x844.png`
  - `test/features/preview/goldens/revolut/biopay_face_enroll_430x932.png`
  - `test/features/preview/goldens/revolut/biopay_nfc_390x844.png`
  - `test/features/preview/goldens/revolut/biopay_nfc_430x932.png`
- Reconciled `design.md` with the current app structure:
  - four shell branches: Home, Trips, BioPay, Profile;
  - BioPay is active as an external USSD handoff and face/QR/NFC identity surface;
  - legacy payment/ledger routes remain outside the benchmark scope.

## Completed in second implementation slice

- Expanded `test/features/preview/revolut_reference_golden_test.dart` from 34 to 46 route/surface captures.
- Added golden coverage for notifications, edit profile, first-run profile setup, config error, 404, four admin tab states, and the actual BioPay Ops admin console.
- Standardized all direct app/admin `showModalBottomSheet` calls through `MobiBottomSheet.show`; the only remaining direct call is inside the shared wrapper.
- Enhanced `MobiBottomSheet` with safe-area and keyboard-inset handling so country pickers, report forms, schedule suggestions, and admin editors share one sheet shell.
- Renamed the active admin BioPay surface to canonical `/admin/biopay`; `/admin/finance` remains a compatibility redirect only.
- Added `AdminWorkspaceTab.biopayOps` and removed the generic finance tab naming from active admin UI.
- Fixed compact BioPay Ops metric-card overflow by giving the two-column admin metrics grid enough vertical space for hint text.
- Fixed BioPay Ops three-column overview density so desktop confirmation summaries no longer overflow.

## Completed in third implementation slice

- Expanded the Revolut-reference golden suite from 46 to 60 route/surface captures.
- Added actual-widget golden coverage for trip detail, trip edit, admin auth, admin vehicle types, admin subscriptions, admin reports, and admin audit.
- Added deterministic preview service overrides inside `test/features/preview/revolut_reference_golden_test.dart` for admin, catalog, country, subscription, vehicle, and trip data.
- Added a local-preview path to `TripDetailsScreen` so visual evidence can render without initialized Supabase state.
- Guarded trip-detail chat/owner checks so local preview does not touch `Supabase.instance` when backend dart-defines are intentionally absent.
- Added admin desktop/tablet visual captures for BioPay Ops, admin auth, vehicle types, subscriptions, reports, audit, and tab-state previews at `768x1024`, `1280x900`, and `1440x1000`.
- Fixed BioPay Ops desktop overview density by increasing the three-column overview grid height so confirmation summaries no longer overflow.

## Completed in fourth implementation slice

- Expanded `tool/revolut_visual_proof_app.dart` from the older 13-screen proof sequence to a full route proof matrix covering shell tabs, Home, Bookings, Schedule, Trip Details, Trip Edit, Profile, Profile Setup, Edit Profile, Notifications, Chat, Nearby, all BioPay subflows, config/404 states, and every admin route.
- Added `tool/revolut_preview_services.dart` so native proof builds render deterministic admin, trip, country, vehicle, and subscription data without requiring live Supabase state.
- Added native proof variants for large-text and keyboard-inset stress cases: admin auth/login large text, schedule keyboard, edit profile large text, and admin reports large text.
- Updated the visual proof shell to match the current four-branch passenger navigation: Home, Trips, BioPay, Profile.

## Verification

- `/Volumes/PRO-G40/flutter_3_44/bin/dart analyze`
- `FLUTTER_BIN=/Volumes/PRO-G40/flutter_3_44/bin/flutter /Volumes/PRO-G40/flutter_3_44/bin/flutter test --concurrency=1 test/features/biopay/biopay_payment_surfaces_test.dart test/features/biopay/biopay_admin_console_test.dart test/features/preview/revolut_reference_golden_test.dart`

Result after first slice: analyzer clean and 34 focused tests passed.

Latest targeted verification:

- `/Volumes/PRO-G40/flutter_3_44/bin/dart analyze`
- `FLUTTER_BIN=/Volumes/PRO-G40/flutter_3_44/bin/flutter /Volumes/PRO-G40/flutter_3_44/bin/flutter test --update-goldens test/features/preview/revolut_reference_golden_test.dart`

Latest result: analyzer clean and 46 updated golden cases passed.

Latest route-coverage update:

- `/Volumes/PRO-G40/flutter_3_44/bin/dart analyze`
- `FLUTTER_BIN=/Volumes/PRO-G40/flutter_3_44/bin/flutter /Volumes/PRO-G40/flutter_3_44/bin/flutter test --update-goldens test/features/preview/revolut_reference_golden_test.dart`

Latest route-coverage result: analyzer clean and 60 updated phone golden cases passed.

Latest admin desktop evidence update:

- `FLUTTER_BIN=/Volumes/PRO-G40/flutter_3_44/bin/flutter /Volumes/PRO-G40/flutter_3_44/bin/flutter test --update-goldens test/features/preview/revolut_reference_golden_test.dart`

Latest admin desktop evidence result: 93 updated golden cases passed, including admin captures at `768x1024`, `1280x900`, and `1440x1000`.

Latest native proof harness verification:

- `/Volumes/PRO-G40/flutter_3_44/bin/dart analyze tool/revolut_visual_proof_app.dart tool/revolut_preview_services.dart`
- `/Volumes/PRO-G40/flutter_3_44/bin/dart analyze`

Latest native proof harness result: analyzer clean. Android emulator capture did not complete because the proof APK build was blocked by the local Gradle environment. First attempt failed on `/Volumes/PRO-G40/AppData/android/gradle` cache lock/write failures. Retry with `GRADLE_USER_HOME=/tmp/mobi-revolut-proof-gradle` and daemon disabled remained in `assembleDebug` for 295 seconds and was interrupted before artifact creation.

Latest focused validation:

- `FLUTTER_BIN=/Volumes/PRO-G40/flutter_3_44/bin/flutter /Volumes/PRO-G40/flutter_3_44/bin/flutter test --concurrency=1 test/features/biopay/biopay_payment_surfaces_test.dart test/features/biopay/biopay_admin_console_test.dart test/features/preview/revolut_reference_golden_test.dart test/core/router/app_router_test.dart test/release/scope_boundary_test.dart test/release/mobile_readiness_contract_test.dart test/release/admin_panel_production_readiness_contract_test.dart`

Latest focused validation result: 138 tests passed, including BioPay surfaces, the 93-case Revolut-reference golden suite, router contracts, scope boundary contracts, mobile readiness contracts, and admin panel production-readiness contracts.

Latest BioPay correction verification:

- `/Volumes/PRO-G40/flutter_3_44/bin/dart analyze lib/features/biopay/biopay_screen.dart lib/shared/widgets/otp_code_field.dart`
- `FLUTTER_BIN=/Volumes/PRO-G40/flutter_3_44/bin/flutter /Volumes/PRO-G40/flutter_3_44/bin/flutter test --update-goldens test/features/preview/revolut_reference_golden_test.dart --name "biopay|BioPay"`

Latest BioPay correction result: analyzer clean and 17 BioPay-related golden cases passed. The root BioPay golden again shows the original `Pay & Get Paid Instantly` design with `Face Scan`, `NFC Tap`, `Get QR`, and `Scan QR`.

Known tool warning: Flutter reports that `permission_handler_apple` does not support Swift Package Manager for iOS yet. This is a future compatibility warning, not a current test failure.

## Remaining recommendations

- Complete fresh native Android/iOS captures from the expanded proof harness once the local Gradle/iOS build environment can produce and install the proof target.
- Add explicit permission-denied, loading, empty, error, and success runtime-state captures beyond the current deterministic route, large-text, and keyboard proof variants.
- Add runtime browser/PWA captures if required beyond the deterministic Flutter-rendered desktop admin golden evidence.
