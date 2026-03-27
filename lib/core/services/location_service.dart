import 'package:geolocator/geolocator.dart';
import 'package:mobi_app/core/services/app_permission_service.dart';
import 'package:mobi_app/core/utils/app_logger.dart';

/// Wraps the Geolocator package for clean location access.
/// Caches last known position for fast autocomplete bias without blocking GPS.
class LocationService {
  LocationService({AppPermissionService? permissionService})
      : _permissionService =
            permissionService ?? AppPermissionService.instance;

  final AppPermissionService _permissionService;

  /// In-memory cache — avoids repeated GPS queries during a session.
  Position? _cachedPosition;

  /// Returns the cached position, or null if not yet acquired.
  Position? get cachedPosition => _cachedPosition;

  /// Whether we already have a usable cached position.
  bool get hasPosition => _cachedPosition != null;

  /// Checks if location permission is already granted (no prompt).
  Future<bool> get hasPermission => _permissionService.hasLocationAccess();

  /// Requests location permission via AppPermissionService and returns position.
  /// Returns null if permission is denied or location services are disabled.
  /// Caches result in memory for fast subsequent access.
  Future<Position?> getCurrentPosition() async {
    try {
      // Check location services
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.warning('Location services are disabled');
        return _cachedPosition; // return stale cache if available
      }

      // Use unified permission service
      final granted = await _permissionService.ensureLocationAccess();
      if (!granted) {
        AppLogger.warning('Location permission not granted');
        return _cachedPosition; // return stale cache if available
      }

      // Get fresh position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _cachedPosition = position;
      return position;
    } on Object catch (e) {
      AppLogger.error('Error getting current position: $e');
      return _cachedPosition; // return stale cache on error
    }
  }

  /// Returns last known position from the OS (fast, no GPS lock needed).
  /// Falls back to cached position. Updates cache if successful.
  Future<Position?> getLastKnownOrCached() async {
    if (_cachedPosition != null) return _cachedPosition;

    try {
      final granted = await _permissionService.hasLocationAccess();
      if (!granted) return null;

      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _cachedPosition = last;
      }
      return last;
    } on Object catch (e) {
      AppLogger.error('Error getting last known position: $e');
      return null;
    }
  }

  /// Calculates the distance in kilometers between two points.
  double distanceKm(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    final meters = Geolocator.distanceBetween(
      startLat, startLng, endLat, endLng,
    );
    return meters / 1000.0;
  }
}
