import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/backend/supabase_provider.dart';
import 'package:mobi_app/core/location/location_service.dart';
import 'package:mobi_app/core/location/places_service.dart';
import 'package:mobi_app/core/permissions/permission_providers.dart';

final locationServiceProvider = Provider(
  (ref) => LocationService(
    permissionService: ref.read(appPermissionServiceProvider),
  ),
);

final placesServiceProvider = Provider(
  (ref) => PlacesService(supabase: ref.read(supabaseClientProvider)),
);
