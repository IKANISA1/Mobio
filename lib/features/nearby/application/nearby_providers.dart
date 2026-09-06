import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/backend/supabase_provider.dart';
import 'package:mobi_app/core/location/location_providers.dart';
import 'package:mobi_app/features/nearby/data/driver_location_service.dart';
import 'package:mobi_app/features/nearby/data/driver_location_sharing_service.dart';
import 'package:mobi_app/features/nearby/data/nearby_discovery_service.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';

final driverLocationServiceProvider = Provider(
  (ref) => DriverLocationService(supabase: ref.read(supabaseClientProvider)),
);

final nearbyDiscoveryServiceProvider = Provider(
  (ref) => NearbyDiscoveryService(
    locationService: ref.read(locationServiceProvider),
    driverLocationService: ref.read(driverLocationServiceProvider),
  ),
);

final driverLocationSharingServiceProvider = Provider(
  (ref) => DriverLocationSharingService(
    locationService: ref.read(locationServiceProvider),
    driverLocationService: ref.read(driverLocationServiceProvider),
    profileService: ref.read(profileServiceProvider),
  ),
);
