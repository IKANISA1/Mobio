# Mobio Public Transport Tracking And Booking Scope

Date: 2026-06-08

## Objective

Enable users to track public transport in Kigali and Rwanda's provinces, browse
transport-agency buses, book seats on agency departures, and pay for confirmed
bookings. The app must hand users off to Google Maps for route and live-vehicle
location viewing instead of embedding maps inside Mobio.

## Current Product State Recorded

- UI/UX: the active Flutter app uses a 3-tab shell: Discover, Trips, Profile.
  Existing mobility surfaces include Home, Nearby, Bookings, Schedule, Trip
  Details, Chat, Profile, and Admin.
- Frontend: scheduled trip posts already capture route labels, optional
  coordinates, date/time, role, vehicle type, recurring days, notes, and active
  or cancelled status.
- Backend: Supabase RPCs and direct RLS-safe reads currently support profiles,
  scheduled trip posts, nearby discovery snapshots, chat, reports/blocks, and
  admin moderation.
- Database: `vehicle_types` is the dynamic vehicle catalog. `trips` is a
  scheduled-post table, not a ticketing or ride lifecycle table. `bus` is now an
  approved vehicle type in the Flutter model, offline catalog fallback, and
  Supabase catalog migration.
- Maps: Mobio does not embed maps. Trip route cards now open Google Maps through
  a route deep link.

## Main User Journeys

1. Track a bus
   - User chooses Kigali city routes or province routes.
   - User selects an agency, route, or bus.
   - Mobio shows route, agency, next departure, and last trusted location.
   - User taps Open in Google Maps to view the route or current bus position.

2. Book a seat
   - User chooses origin, destination, travel date, agency, departure, and seat
     quantity or seat number when a seat map exists.
   - Mobio places a short booking hold.
   - User pays through the approved booking payment flow.
   - Mobio confirms the ticket and exposes a receipt/ticket reference.

3. Agency operations
   - Agency registers routes, buses, schedules, fares, capacity, and contacts.
   - Agency monitors bookings, payments, cancellations, and bus location feed
     health.

4. Driver or device tracking
   - Option A: bus driver runs the Mobio driver app and grants foreground or
     approved background location permissions.
   - Option B: agency installs approved GPS hardware in the bus. Commodity GPS
     trackers normally send coordinates to a backend API; only Android-capable
     hardware can run the Flutter app directly.

## Vehicle Types

Active catalog:

- moto
- cab
- bus
- trike
- truck
- private

Bus is the public-transport vehicle type. Agency-owned buses should also have
fleet records so Mobio can distinguish a generic vehicle type from a specific
bus with plate, capacity, route assignment, and tracking source.

## Frontend Scope

- Add bus to vehicle filters, schedule/trip forms, trip cards, and admin vehicle
  catalog surfaces.
- Add public-transport browsing surfaces for agencies, routes, departures, and
  bus detail.
- Add booking surfaces for seat count/seat selection, hold timer, passenger
  details, payment, ticket confirmation, and booking history.
- Add Google Maps handoff actions for route and current bus position.
- Keep map rendering outside the app.

## Backend Scope

- Keep legacy scheduled trip posts separate from bus bookings.
- Add booking-specific RPCs for schedule search, seat hold, hold release,
  payment initiation, payment verification, ticket confirmation, cancellation,
  refund eligibility, and agency reconciliation.
- Add location ingestion for driver-app heartbeat and GPS hardware heartbeat.
- Add admin/agency permissions for fleet, route, schedule, booking, and payment
  operations.

## Database Scope

Required new tables should be booking-specific:

- `transport_agencies`
- `agency_buses`
- `transport_routes`
- `route_stops`
- `bus_schedules`
- `bus_seat_inventory`
- `bus_bookings`
- `bus_booking_payments`
- `bus_location_events`
- `bus_tracking_sources`

Do not reuse removed BioPay, ledger, `payment_intents`, `ride_requests`, or
`trip_requests` tables for this expansion.

## Google Maps Deep-Link Contract

- Route preview: `https://www.google.com/maps/dir/?api=1&origin=lat,lng&destination=lat,lng&travelmode=driving`
- Current vehicle position: `https://www.google.com/maps/search/?api=1&query=lat,lng`
- Mobio owns agency, booking, and trusted-location data.
- Google Maps owns map display, navigation, traffic, and route rendering.

## Permanent Route API Exclusion

Google Routes API, Compute Route Matrix, Directions API, Distance Matrix API,
route ETA/duration calculation, distance-based fare calculation, route
polylines, and dispatch-grade routing are permanently out of context for Mobio.
Public transport support should model agency schedules, route definitions,
trusted vehicle location events, seat inventory, booking holds, and
booking-specific payments. Map display, navigation, traffic, and route rendering
remain an external Google Maps deep-link handoff.

Do not enable route-computation APIs or add Mobio-owned ETA, distance, polyline,
matrix, fare-distance, or dispatch-routing contracts to this app.

## Open Implementation Gaps

- Agency/fleet/route/schedule tables and RLS policies are not implemented yet.
- Seat inventory, booking holds, payment contracts, tickets, and refunds are not
  implemented yet.
- Driver app heartbeat and GPS hardware ingestion are not implemented yet.
- Linked Supabase deployment and production payment provider approval remain
  required before paid bookings can go live.
