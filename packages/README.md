# Packages

This folder defines shared package boundaries.

Runtime code may move here only through local path packages with compatibility
exports from the old `../lib` paths, updated `pubspec.yaml` dependencies, and a
passing analysis/build/test loop.

| Package boundary | Current source |
| --- | --- |
| `design-system` | `design.md`, `design-system/lib/src/theme`; compatibility exports in `../lib/core/theme`; widgets still in `../lib/shared/widgets` |
| `shared-types` | `shared-types/lib/src/models`; compatibility exports in `../lib/models`; UI-backed `VehicleTypeModel` remains in the app |
| `shared-utils` | `../lib/core/utils`, pure helpers inside services |
| `domain` | Trip, profile, saved-place, entitlement, demand-zone logic in `../lib/core/services` and feature providers |
| `api-clients` | Supabase and Edge Function clients in `../lib/core/services` and `../lib/features/*/services` |
| `auth` | `../lib/core/auth`, session services, OTP/login services |
| `agent-ui` | Future shared operator/agent UI components |
| `analytics` | Firebase analytics/crash/remote-config services |
