# Mobio Product Scope

Last updated: 2026-06-08

Mobio is a mobility marketplace expanding from nearby discovery and scheduled
trip posts into public-transport discovery for Kigali and Rwanda's provinces.
It helps users discover nearby drivers or passengers, view profiles and vehicle
types, communicate through WhatsApp or in-app chat, create/view scheduled trip
posts, and progressively support bus tracking and agency seat booking.

## In Scope

- Passenger and driver WhatsApp login.
- Passenger/driver profiles.
- Vehicle types: moto, cab, bus, truck, trike, private car.
- Nearby discovery by role, vehicle type, distance/radius, and location consent.
- Location snapshots for discovery while users choose to be visible.
- Scheduled trip posts: create, view, edit where implemented, and cancel.
- Route labels and optional coordinates for scheduled trip posts, without
  embedded maps.
- Google Maps deep links for opening trip routes and, once a trusted vehicle
  location feed exists, current bus/vehicle positions.
- In-app chat and WhatsApp handoff.
- Report/block workflows when implemented.
- Admin review of users, roles, scheduled posts, chat/report moderation,
  verification where present, audit logs, operational health, and basic
  analytics.

## Approved Expansion, Not Yet Fully Active

- Public transport coverage for Kigali city routes and inter-province routes.
- Transport agency catalog, bus fleet records, route schedules, seat inventory,
  booking holds, ticket confirmation, and agency operations dashboards.
- Passenger booking and payment for private travel agencies and bus providers.
- Live bus tracking from either the driver app or approved GPS hardware feeds.
- Payment collection must use a new audited booking/payment contract before it
  appears as active user-facing functionality.

See `docs/product/public_transport_tracking_booking_scope_2026-06-08.md`.

## Out Of Scope Until Implemented By Approved Expansion

- Automatic fare quotes or pricing engines.
- Automatic driver/passenger dispatch.
- Trip start, arrival, pickup, completion, or route-tracking lifecycle for
  legacy trip posts.
- Driver earnings, refunds, settlement, wallets, or trip payment ledgers.
- In-app BioPay, QR/NFC payment, SMS payment ingestion, or payment collection
  for legacy trip posts.
- Uber-style trip management.

Fares and prices are negotiated manually between users outside Mobio's automated
systems unless the interaction is inside the new approved bus booking/payment
surface. Active legacy-trip UI must not present Mobio as calculating,
collecting, settling, or adjudicating trip payments.

## Route Computation Boundary

The active marketplace must not compute or display Google-backed route ETA,
route distance, route duration, route polyline, fare-distance basis, automatic
dispatch ranking, or driver/passenger route matrices. Do not recommend or enable
Google Routes API `computeRoutes`, Google Routes API `computeRouteMatrix`,
Directions API, Distance Matrix API, or a custom routing engine for legacy
scheduled trip posts.

The approved Google integration is limited to:

- Google Places/Geocoding through the server-side `maps-gateway` for place
  lookup and reverse geocoding.
- Stored route labels and optional coordinates on scheduled trip posts.
- External Google Maps deep links for map display, navigation, traffic, route
  rendering, and trusted vehicle position viewing.

`maps-gateway` returning `410` for `compute_route` is intentional product-scope
behavior, not a missing production-readiness feature. Route ETA, route distance,
route duration, route polylines, route matrices, fare-distance basis, and
dispatch-grade routing are out of context for this app. They must not be added
to Mobio code, schema, APIs, UI, store copy, release gates, or future Mobio
scope documents.

## Legacy Code Rule

Legacy payment, BioPay, ledger, ride-request, and lifecycle code may exist in
the repository while removal is staged. It must remain isolated from active user
navigation unless the public-transport booking expansion reintroduces payments
through new, audited booking-specific contracts.
