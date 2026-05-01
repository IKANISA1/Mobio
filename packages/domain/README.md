# Domain Package Boundary

Current source of truth:

- Trips and pool suggestions: `../../lib/core/services/trip_service.dart`
- Driver location and demand zones: `../../lib/core/services/driver_location_service.dart`
- Profiles and roles: `../../lib/core/services/profile_service.dart`
- Favorite addresses: `../../lib/core/services/favorite_address_service.dart`
- Subscription/catalog logic: `../../lib/core/services/subscription_plan_service.dart`, `../../lib/core/services/vehicle_type_service.dart`

Domain logic should be UI-independent and backed by database/RPC source of truth.
