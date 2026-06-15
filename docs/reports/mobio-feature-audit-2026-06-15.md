# Mobio Feature Audit - 2026-06-15

This workpaper tracks feature-by-feature audit status for the main Mobio Flutter app. BioPay is one Mobio feature in this table.

| Feature | Primary files | Backend dependencies | Current evidence | Status | Next audit action |
| --- | --- | --- | --- | --- | --- |
| Auth and WhatsApp OTP | `lib/features/auth`, `lib/core/router`, `supabase/functions/send-login-otp`, `verify-login-otp` | OTP tables/RPCs, WhatsApp Cloud config, auth audit | Router/auth tests exist; full v14 gate passed earlier | Open | Review OTP empty/error/throttle states and admin/passenger/driver redirects |
| Onboarding/profile setup | `lib/features/profile/edit_profile_screen.dart`, profile providers/widgets | Profile RPC/service, countries, vehicle records | `profile_verified_contact_contract_test.dart` passed; `flutter analyze` passed | In progress | Add visual/accessibility review for first-run setup |
| Home/discovery | `lib/features/home`, `lib/features/nearby` | Trips/profiles/nearby privacy RPCs, Maps gateway | Goldens and local previews passed in v14 gate | Open | Screen-level state review and location denial proof |
| Bookings/scheduled posts | `lib/features/bookings` | Scheduling RPCs, trip tables | Scheduling contracts passed in v14 gate | Open | Review edit/details missing/unauthorized states |
| Chat/report/block | `lib/features/chat`, report/block services | Chat RPCs, report/block tables/RPCs | Report/block contracts passed in v14 gate | Open | Review blocked-user UI and message send failure states |
| Profile/settings | `lib/features/profile/profile_screen.dart`, profile widgets | Profile service, notification consent, wallet summary | Focused profile contact test passed | In progress | Screen-level layout review after read-only WhatsApp change |
| Wallet/tokens/referrals | `lib/features/profile/wallet_screen.dart`, wallet model/services | Wallet ledger, rewards, referral attribution | Wallet contract tests passed | Covered by contract | Review empty/error/loading UI and server-owned boundaries |
| Subscriptions/Mobio Plus | `lib/features/profile/driver_plus_screen.dart` | Subscription plans, driver subscription RPCs, MoMo payment request RPCs | Focused wallet/subscription tests passed | In progress | Visual review for narrow button layout and MoMo receiver setup |
| BioPay | `lib/features/biopay/**` | BioPay RPCs, `biopay-face-provider`, AWS Rekognition, USSD handoff | QR fixed; BioPay readiness passed in v14 gate | Covered by gate | Add iOS release proof if iOS ships |
| Public transport | Public transport models/screens/admin agencies | Transport schedules/bookings/agencies RPCs | Public transport contracts passed in v14 gate | Open | Review passenger/driver/admin state handling |
| Referrals | Referral attribution service, wallet/profile entry points | Referral RPCs/rewards | Wallet/referral contracts passed in v14 gate | Open | Verify attribution deep-link paths and reward pending states |
| Notifications | `lib/features/notifications`, push service | Notification tables, FCM v1 function, triggers | Notification contracts and FCM evidence passed in v14 gate | Covered by contract | Review killed-state tap evidence and inbox empty/error UI |
| Privacy/location | Location services, nearby/schedule/profile | Maps gateway, geolocation permissions | Permission education contracts passed in v14 gate | Open | Device proof for permission denied/retry states |
| Settings/theme | Profile/settings widgets, theme provider | Local state/profile preferences | Existing widget/provider tests | Open | Review semantics and persistence |

## Focused Workpapers

- Profile, wallet, tokens, subscriptions, and Mobio Plus: `docs/reports/mobio-profile-wallet-subscription-audit-2026-06-15.md`.

