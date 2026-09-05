# Shared Types Package

Canonical source of truth for app-agnostic Dart data contracts.

## Current Contents

- Core models: `lib/src/models`
- Admin DTOs: `lib/src/models/admin`
- Public exports: `lib/models` and `lib/mobi_shared_types.dart`

Consumers import `package:mobi_shared_types/models/...` directly. Redundant
app-level compatibility exports were removed in September 2026.

## Boundaries

Keep this package free of Flutter widgets, Supabase clients, provider state, and
screen logic. The UI-backed `VehicleTypeModel` belongs to `lib/shared/models/`
in the application. Feature-specific models belong to the feature's `domain/`.

Payment and ride-request DTOs are outside the current Mobio production scope and
are not exported from this shared package. Role/mode constants remain app-owned
in `lib/core/constants/`.

Generate model parts with `scripts/ci/bootstrap_flutter.sh` from the repository
root. The script runs build_runner here before resolving the application.
