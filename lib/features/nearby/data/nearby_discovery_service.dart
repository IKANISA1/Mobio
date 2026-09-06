import 'package:mobi_app/core/location/location_access_state.dart';
import 'package:mobi_app/core/location/location_service.dart';
import 'package:mobi_app/features/nearby/data/driver_location_service.dart';

/// A complete discovery snapshot. Unavailable snapshots carry no old locations
/// or drivers; an empty ready snapshot means a search actually completed.
class NearbyDiscoveryResult {
  const NearbyDiscoveryResult.unavailable(this.accessState)
    : latitude = null,
      longitude = null,
      drivers = const [];

  NearbyDiscoveryResult.ready({
    required double this.latitude,
    required double this.longitude,
    required List<NearbyDriver> drivers,
  }) : accessState = LocationAccessState.granted,
       drivers = List.unmodifiable(drivers);

  final LocationAccessState accessState;
  final double? latitude;
  final double? longitude;
  final List<NearbyDriver> drivers;
}

class NearbyDiscoveryService {
  NearbyDiscoveryService({
    required LocationService locationService,
    required DriverLocationService driverLocationService,
  }) : _location = locationService,
       _drivers = driverLocationService;

  final LocationService _location;
  final DriverLocationService _drivers;

  Future<NearbyDiscoveryResult> load({
    String? vehicleType,
    bool preferCachedLocation = false,
  }) async {
    final access = await _location.accessState();
    if (access != LocationAccessState.granted) return _unavailable(access);

    final cached = preferCachedLocation
        ? await _location.getLastKnownOrCached()
        : null;
    final position = cached ?? await _location.getCurrentPosition();
    // Access may have changed while the position request was pending.
    final positionAccess = await _location.accessState();
    if (positionAccess != LocationAccessState.granted) {
      return _unavailable(positionAccess);
    }
    if (position == null) return _unavailable(LocationAccessState.unavailable);

    final drivers = await _drivers.findNearbyDrivers(
      latitude: position.latitude,
      longitude: position.longitude,
      vehicleType: vehicleType,
    );
    final resultAccess = await _location.accessState();
    if (resultAccess != LocationAccessState.granted) {
      return _unavailable(resultAccess);
    }
    return NearbyDiscoveryResult.ready(
      latitude: position.latitude,
      longitude: position.longitude,
      drivers: drivers,
    );
  }

  NearbyDiscoveryResult _unavailable(LocationAccessState access) {
    _location.clearCache();
    return NearbyDiscoveryResult.unavailable(access);
  }
}
