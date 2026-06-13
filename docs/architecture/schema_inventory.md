# Schema Inventory

Last updated: 2026-06-08

Current source of truth: `docs/product/scope.md`,
`docs/reports/production-readiness-audit.md`, and
`docs/release/go-no-go.md`.

Mobio's active schema supports nearby discovery, scheduled trip posts, profiles,
communication, reporting/blocking, and admin moderation. The active schema now
also carries `bus` as a vehicle type. It does not yet support agency seat
inventory, paid bus tickets, in-app fare quotes, trip payment settlement,
BioPay, SMS ledger ingestion, ride-request dispatch lifecycle, or payment
ledgers.

## 1. Active Marketplace Schema

- `profiles`: Extends Supabase auth users with role, display name, phone,
  public `member_id`, vehicle/profile fields, and moderation state.
- `trips`: Scheduled trip posts. Active Flutter models expose scheduled-post
  state only, not a ride lifecycle with trip completion.
- `countries`: Region configuration, currency, and public country metadata.
  The legacy SMS `sender_id` column is removed by the scope cleanup migrations.
- `driver_locations`: User-published availability/location snapshots for
  nearby discovery. This is not live route tracking.
- `vehicle_types`: Dynamic catalog for mobility modes. Current active records
  include moto, cab, bus, trike, truck, and private.
- `chat_conversations`, `chat_messages`: In-app participant messaging.
- `user_blocks`, `user_reports`: User safety workflows, exposed through RPCs
  and admin moderation rather than direct client table writes.
- `admin_audit_log`, `admin_audit_logs`, operational/admin tables: Audit,
  tenant/permission, notification, campaign, and admin support records.
- Storage buckets: Profile/media/promo buckets governed by explicit storage
  policies and MIME/size constraints.

## 2. Removed Or Historical Schema

The following tables/functions appear in historical migrations but are outside
current product scope and are removed by forward cleanup migrations:

- PayLedger/SMS objects: `transactions`, `sms_raw_queue`, SMS reconciliation
  routines, and country `sender_id`.
- BioPay objects: `biopay_profiles`, `biopay_wallets`,
  `biopay_transactions`, `face_templates`, and BioPay transfer/scan routines.
- Payment objects: `payment_intents`, `payment_events`,
  `qr_payment_sessions`, `nfc_payment_sessions`, and risk-review payment
  routines.
- Ride-request lifecycle objects: `ride_requests` and `trip_requests`.

The cleanup path is tracked in:

- `supabase/migrations/20260501134000_scope_cleanup_legacy_trip_payment_biopay.sql`
- `supabase/migrations/20260524001000_final_scope_cleanup_after_linked_history.sql`
- `supabase/tests/backend_security_assertions.sql`
- `supabase/tests/storage_realtime_audit.sql`

## 3. Validation Status

Local Docker Desktop replay has applied every migration through the final
cleanup migration and passed local database lint plus backend/storage SQL
assertions. Linked Supabase replay and assertions remain a production blocker
until privileged linked credentials are available.

## 4. Public Transport Expansion Schema Target

The approved public transport expansion should add new booking-specific tables
rather than reviving removed payment or ride-request lifecycle tables:

- `transport_agencies`: Agency profile, service areas, contacts, status.
- `agency_buses`: Fleet records, plate/registration, capacity, agency owner,
  active tracking source, and safety/compliance metadata.
- `transport_routes`: Kigali and inter-province route definitions, terminals,
  stops, and route geometry reference when available.
- `bus_schedules`: Agency route departures, estimated arrival windows, fare
  bands, and operating days.
- `bus_seat_inventory`: Seat map or seat count per scheduled departure.
- `bus_bookings`: Passenger booking records, seat/quantity, hold expiry,
  confirmation status, payment status, and ticket reference.
- `bus_location_events`: Driver-app or GPS-hardware position heartbeats for
  Google Maps live-location handoff.

The approved expansion tables above do not imply Google Routes API or route
matrix support. They should store agency schedules, route definitions, and
trusted location snapshots/events. Do not add `distance_meters`,
`duration_seconds`, route polylines, fare-distance basis, route matrix cache, or
dispatch-grade routing fields to Mobio tables. Those concepts are out of context
for this app and must not become Mobio schema.
