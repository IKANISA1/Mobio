# Route And Screen Matrix - 2026-06-15

Source of truth reviewed: `lib/core/router/app_router.dart`, `lib/core/router/screen_wrappers.dart`, and `lib/features/**`.

Status legend:

- `Open`: route exists and still needs screen-level audit evidence.
- `Covered by gate`: route has current automated gate evidence, but still may need screen-level human/device review.
- `Fixed`: code-owned gap already fixed in this readiness cycle.
- `Redirect`: compatibility route only.

| Route/screen | Feature owner | Roles/auth | Backend/RPC/table dependency | Permissions | States to verify | Navigation entry/exit | Tests/evidence seen | Risk/status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `/config-error` `ConfigErrorScreen` | App shell/config | Public, no Supabase session required | Supabase config only | None | Config missing, recovery copy | Initial route when config invalid | Config error contracts plus Revolut mobile goldens | Covered by gate |
| `/login` `WhatsAppLoginScreenWrapper` | Auth | Passenger, driver, admin auth redirection | `send-login-otp`, `verify-login-otp`, OTP audit tables | Phone/WhatsApp external handoff | Empty phone, invalid OTP, throttle, loading, retry | Redirect query handled by safe local target | Login/auth contracts plus Revolut mobile goldens | Covered by gate |
| `/` `HomeScreenWrapper`/`HomeScreen` | Home/discovery | Verified app session; admin role routes dashboard | Trips/profiles/nearby services | Location if discovery enabled | Empty nearby, loading, offline, role switch | Bottom nav tab 0, pushes nearby/bookings/schedule/notifications/chat | Golden and local preview tests | Covered by gate |
| `/admin` `AdminDashboardScreen` | Admin panel | Admin role/session guard | Admin dashboard RPCs/services | None | Empty metrics, load fail, permission denied | Bottom shell admin route, protected guard | Admin contract/goldens | Covered by gate |
| `/bookings` `BookingsScreenWrapper` | Bookings/scheduled posts | Verified app session | Scheduled trip queries/RPCs | Location optional for pickup | Empty posts, own posts, filters, loading, error | Bottom shell tab 1, schedule/details exits | Booking preview and golden tests | Covered by gate |
| `/admin/users` `AdminUsersScreen` | Admin users | Admin role/session guard | Admin users provider/RPCs | None | Empty users, search, paging, denial | Bottom shell admin users route | Actual admin users mobile and desktop Revolut goldens plus admin pagination contracts | Covered by gate |
| `/biopay` `BioPayScreen` | BioPay feature | Verified app session | BioPay request/profile state | Camera/NFC only from subflows | Feature entry, unavailable provider, error cards | Bottom shell tab 2, pushes QR/scan/face/NFC | BioPay gates/goldens | Covered by gate |
| `/admin/biopay` `BioPayAdminConsoleScreen` | Admin BioPay ops | Admin role/session guard | BioPay admin RPCs, external confirmation RPC | None | Empty ops, confirm external, denial, audit | Bottom shell admin BioPay route | BioPay/admin contract/goldens | Covered by gate |
| `/admin/finance` redirect | Compatibility | Admin route guard inherited | None | None | Redirect only | Redirects to `/admin/biopay` | Scope tests | Redirect |
| `/profile` `ProfileScreenWrapper`/`ProfileScreen` | Profile/settings | Verified app session | Profiles, notification consent, wallet summary, referral | Notification prompt from subflow | Empty profile, contact verification, loading, error | Bottom shell tab 3, edit/wallet/plus/BioPay/admin exits | Profile tests plus Revolut mobile goldens with identity/status strip | Covered by gate |
| `/admin/profile` `ProfileScreenWrapper` | Admin profile context | Admin role/session guard | Same as profile | Notification prompt from subflow | Admin exit, profile state, denial | Admin/router tests plus shared profile Revolut mobile goldens | Covered by gate |
| `/nearby` `NearbyScreenWrapper` | Nearby discovery | Verified app session | Nearby trips/profiles, driver privacy RPCs | Location | No location, denied permission, empty nearby, offline | Full page push, back to shell | Golden/local preview tests | Covered by gate |
| `/notifications` `NotificationsScreenWrapper` | Notifications | Verified app session | Notification inbox tables, FCM trigger/function | Notifications | Empty inbox, push-only excluded, load fail | Home/profile entry, back pop | Notification contract tests | Covered by gate |
| `/ledger` `ScopeUnavailableScreen` | Scope boundary | Verified app session | None active | None | Unavailable copy only | Full page push, back pop | Scope boundary tests | Covered by gate |
| `/schedule` `ScheduleTripScreenWrapper` | Scheduling | Verified app session | Validated audited scheduling RPCs | Location optional | Empty form, invalid timing, duplicate, RPC fail | Bookings/home entry, back pop | Scheduling hardening tests | Covered by gate |
| `/trip/:id/edit` `EditTripScreenWrapper` | Scheduling edit | Verified app session, owner permissions server-side | Trip edit RPCs | Location optional | Missing trip, unauthorized, validation errors | Trip details/edit entry, back pop | Trip edit Revolut mobile goldens plus mobile readiness contracts | Covered by gate |
| `/trip/:id` `TripDetailsScreen` | Trip details | Verified app session | Trip detail query, chat entry | None | Missing trip, deleted trip, blocked user, loading | Bookings/nearby entry, chat/edit exits | Trip details Revolut mobile goldens plus mobile readiness contracts | Covered by gate |
| `/chat` `TripChatScreen` | Chat | Verified app session, block checks server-side | Chat RPCs/messages/blocks | Notifications optional | Empty chat, blocked, reported, send fail | Trip/home/nearby entry, back pop | Report/block contracts | Covered by gate |
| `/edit-profile` `EditProfileScreen` | Profile onboarding/settings | Verified app session | Profile update RPC/service | Location optional for favorites | Required fields, contact verification, save fail | Profile entry, back pop | Edit profile Revolut mobile goldens plus verified contact contract | Covered by gate |
| `/wallet` `WalletScreen` | Wallet/tokens/referrals | Verified app session | Wallet ledger, referral rewards, token balances | None | Empty ledger, server error, pending reward, invite QR | Profile entry, back to profile | Wallet contract tests plus Revolut mobile goldens | Covered by gate |
| `/mobio-plus` `DriverPlusScreen` | Subscriptions/Mobio Plus | Verified driver/passenger session; driver gating server-side | Subscription plans, driver subscription RPCs, MoMo USSD profile fields | Phone dialer external handoff | No MoMo receiver, no tokens, active/expired plan, RPC fail | Profile entry, back to profile | Wallet/subscription contracts plus Revolut mobile goldens | Covered by gate |
| `/profile/setup` `EditProfileScreen(isFirstRun)` | Onboarding | Verified app session | Profile service/update | Location optional | Required fields, first-run exit, failed save | Login success/profile setup entry | Profile setup Revolut mobile goldens plus mobile readiness contracts | Covered by gate |
| `/admin-auth` `AdminAuthScreenWrapper` | Admin auth | Public verified by admin WhatsApp OTP; redirects if already admin | Admin OTP allowlist, admin session guard | Phone/WhatsApp external handoff | Not allowlisted, OTP fail, timeout, success | Admin gateway/profile entry, go admin on success | Admin auth mobile and desktop Revolut goldens plus admin guard tests | Covered by gate |
| `/admin/vehicle-types` `AdminVehicleTypesScreen` | Admin catalog | Admin role/session guard | Audited catalog RPCs | None | Empty catalog, reorder, save fail, denial | Admin dashboard entry, back pop | Admin contracts/goldens | Covered by gate |
| `/admin/agencies` `AdminTransportAgenciesScreen` | Admin transport agencies | Admin role/session guard | Transport agency RPCs/tables | None | Empty agencies, CRUD fail, denial | Admin dashboard entry, back pop | Public transport/admin tests plus mobile and desktop Revolut goldens | Covered by gate |
| `/admin/subscriptions` `AdminSubscriptionsScreen` | Admin subscriptions | Admin role/session guard | Subscription-plan audited RPCs | None | Empty plans, validation, save fail, denial | Admin dashboard entry, back pop | Admin subscription contract/goldens | Covered by gate |
| `/admin/trips` `AdminTripsScreen` | Admin trip ops | Admin role/session guard | Admin trip/list RPCs | None | Empty trips, filters, paging, denial | Admin dashboard entry, back pop | Actual admin trips mobile and desktop Revolut goldens plus admin pagination contracts | Covered by gate |
| `/admin/reports` `AdminReportsScreen` | Admin moderation | Admin role/session guard | Reports/blocks RPCs | None | Empty reports, resolve fail, denial | Admin dashboard entry, back pop | Report/block contracts/goldens | Covered by gate |
| `/admin/health` `AdminOperationalHealthScreen` | Admin ops health | Admin role/session guard | Operational health events/RPCs | None | Empty events, degraded service, denial | Admin dashboard entry, back pop | Admin contracts/goldens | Covered by gate |
| `/admin/audit` `AdminAuditLogScreen` | Admin audit | Admin role/session guard | Audit log RPCs, query search | None | Empty audit, search, paging, denial | Admin dashboard entry, back pop | Actual admin audit mobile and desktop Revolut goldens plus admin detail contracts | Covered by gate |
| `/admin/broadcasts` `AdminBroadcastsScreen` | Admin notifications | Admin role/session guard | Notification fanout/send-push | Notifications downstream | Empty campaigns, send fail, denial | Admin dashboard entry, back pop | Notification contracts/goldens | Covered by gate |
| `/biopay/qr` `BioPayQrScreen` | BioPay QR | Verified app session | BioPay QR payload/profile | Photos/gallery save, share sheet | Empty profile, save/share fail, permission denial | BioPay/profile entry, back pop | QR implementation fixed; golden and readiness gates | Fixed |
| `/biopay/scan` `BioPayScanScreen` | BioPay QR scan | Verified app session | BioPay request lookup/USSD handoff | Camera | Camera denied, invalid QR, lookup fail | BioPay entry, back pop | BioPay scan Revolut mobile goldens plus scanner test channel; live camera proof remains device-only | Covered by gate |
| `/biopay/face-scan` `BioPayFaceScanScreen` | BioPay face match | Verified app session | `biopay-face-provider`, AWS Rekognition health | Camera | Camera denied, liveness unavailable, match fail | BioPay entry, back pop | BioPay live readiness | Covered by gate |
| `/biopay/enroll` `BioPayFaceEnrollScreen` | BioPay face enrollment | Verified app session | `biopay-face-provider`, enrollment RPCs | Camera | Camera denied, challenge fail, enrollment fail | Profile/BioPay entry, back pop | BioPay live readiness | Covered by gate |
| `/biopay/nfc` `BioPayNfcScreen` | BioPay NFC | Verified app session | BioPay payload/profile | NFC | NFC unavailable, read fail, invalid payload | BioPay entry, back pop | BioPay NFC tests/goldens | Covered by gate |
| `/biopay/nfc/write-card` `BioPayNfcWriteCardScreen` | BioPay NFC writer | Verified app session | BioPay payload/profile | NFC | NFC unavailable, write fail, confirmation | Profile entry, back pop | BioPay NFC tests, readback retry contract, plus Revolut mobile goldens; physical NFC proof still device-only | Covered by gate |

## Screen Files Still Requiring Row-Level Audit

- `lib/features/admin/*_screen.dart`
- `lib/features/auth/whatsapp_login_screen.dart`
- `lib/features/biopay/*_screen.dart`
- `lib/features/bookings/*_screen.dart`
- `lib/features/chat/chat_screen.dart`
- `lib/features/home/home_screen.dart`
- `lib/features/nearby/nearby_screen.dart`
- `lib/features/notifications/notifications_screen.dart`
- `lib/features/profile/*_screen.dart`
