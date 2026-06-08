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

## Legacy Code Rule

Legacy payment, BioPay, ledger, ride-request, and lifecycle code may exist in
the repository while removal is staged. It must remain isolated from active user
navigation unless the public-transport booking expansion reintroduces payments
through new, audited booking-specific contracts.
