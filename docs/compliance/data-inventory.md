# Data Inventory

Last updated: 2026-05-24

## Active Product Data

| Data class | Examples | Purpose | Storage/processor | Retention note |
| --- | --- | --- | --- | --- |
| Account/auth | Supabase auth user ID, WhatsApp phone, role | Login, role guards, profile ownership | Supabase Auth and `profiles` | Keep while account is active; delete on account deletion where legally allowed. |
| Profile | Display name/code, role, vehicle type, avatar/media URL where enabled | Discovery and user trust | Supabase `profiles`, storage buckets | User-editable; restrict sensitive fields via RLS/RPC. |
| Location | Current/last driver/passenger snapshot, approximate radius search | Nearby discovery | `driver_locations` and location RPCs | Store only while visible/online; avoid route history. |
| Scheduled trip posts | Origin/destination labels, optional coordinates, date/time, vehicle type, note | Marketplace posting and discovery | `trips` | User can cancel; define cleanup for old posts. Route computation is disabled; `compute_route` returns 410 and no ETA/fare/dispatch decision is generated. |
| Chat | Conversation participants, messages, read timestamps | In-app communication | `chat_conversations`, `chat_messages`, realtime | Participant-scoped RLS; moderation policy needed before public launch. |
| Reports/blocks | Reporter/reported IDs, block pairs, report category/details, review status | Marketplace safety, abuse handling, and chat blocking | `user_blocks`, `user_reports`, admin report RPCs | Keep with audit/support retention; restrict direct client writes and admin review. |
| WhatsApp handoff | WhatsApp URL/phone where user-provided | External contact | Profile fields and client handoff | Users negotiate manually outside Mobio. |
| Notifications | Push token, unread counts, consent settings | App notifications and admin campaigns | Firebase/Supabase notification tables | Consent gates required for promotional sends. |
| Admin/audit | Admin actions, access attempts, operational health | Accountability and support | Admin/audit tables and Edge Functions | Retain for audit/security period. |
| Account deletion request | WhatsApp phone, Mobio member code where provided, support email thread, verification notes | User account deletion and data rights handling | Public `landing/account-deletion.html`, support mailbox, backend deletion workflow | Acknowledge within 7 days and complete eligible deletion within 30 days after verification. |

## Out-Of-Scope Or Legacy Data

| Data class | Current repo state | Production stance |
| --- | --- | --- |
| BioPay biometrics | Flutter BioPay feature files, models, tests, ML assets, and Android client dependencies were removed from the active app package. The BioPay Edge Function entrypoint now returns 410 scope unavailable. Forward cleanup migrations drop BioPay tables/functions and profile BioPay columns. Local Docker Desktop replay is proven through the final cleanup migration. | Keep out of Mobio production. Replay the cleanup migrations on linked staging before broad release. |
| Payment intents/events | Flutter payment models and `packages/payments` were removed from the active app package. Legacy payment function entrypoints now return 410 scope unavailable. Forward cleanup migrations drop payment tables/functions. Local Docker Desktop replay is proven through the final cleanup migration. | Do not use for trip collection or automated settlement. Replay the cleanup migrations on linked staging before production. |
| Native ledger/SMS ingestion | Native Android ledger/SMS source, receivers, generated bridge, and related dependencies were removed from the active app package. SMS parsing/reconciliation function entrypoints now return 410 scope unavailable. Forward cleanup migrations drop SMS ledger tables and the country SMS sender column; direct local schema checks confirm `transactions` and `sms_raw_queue` are absent from schema/realtime. | Keep inactive unless a separate Play-approved SMS/payment product is approved. |
| Ride request/offer lifecycle | Flutter service/provider/model/sheet entry points have been removed. A forward cleanup migration drops historical `ride_requests` and `trip_requests` schema objects. Local Docker Desktop replay is proven. | Keep out of active app. Replay the cleanup migration on linked staging before production. |

## Play Data Safety Notes

- Location: used for nearby discovery; disclose approximate/precise location if
  both permissions stay in Android.
- Personal info: phone/profile details used for account and discovery.
- Messages: in-app chat content is user-generated communication.
- Photos/camera/SMS/payments: not active after this scope pass and should not be
  claimed unless re-enabled.
- Data deletion: public account-deletion instructions now exist locally at
  `landing/account-deletion.html` and the app exposes them through
  `ACCOUNT_DELETION_URL`; the live HTTPS URL was verified on 2026-05-23 and
  should be rechecked before each Play production submission.
