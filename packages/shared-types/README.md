# Shared Types Package

Canonical source of truth for app-agnostic Dart data contracts.

## Current Contents

- Core models: `lib/src/models`
- Admin DTOs: `lib/src/models/admin`
- Public exports: `lib/models` and `lib/mobi_shared_types.dart`

Compatibility exports remain in `../../lib/models` so existing
`package:mobi_app/models/...` imports continue to work during the app split.

## Boundaries

Keep this package free of Flutter widgets, Supabase clients, provider state, and
screen logic. UI-backed models such as `VehicleTypeModel` remain in the app until
the vehicle-domain package is split with widget coverage.

Payment DTOs and role/mode constants are still owned by the app while the payment
and auth packages are extracted separately.
