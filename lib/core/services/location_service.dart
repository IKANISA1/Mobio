import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobi_app/core/platform/platform_io.dart';
import 'package:mobi_app/core/services/app_permission_service.dart';
import 'package:mobi_app/core/services/location_access_state.dart';
import 'package:mobi_app/core/utils/app_logger.dart';

/// Wraps the Geolocator package for clean location access.
/// Caches last known position for fast autocomplete bias without blocking GPS.
class LocationService {
  LocationService({AppPermissionService? permissionService})
    : _permissionService = permissionService ?? AppPermissionService.instance;

  final AppPermissionService _permissionService;

  /// In-memory cache — avoids repeated GPS queries during a session.
  Position? _cachedPosition;
  DateTime? _cachedAt;

  static const Duration cacheTtl = Duration(minutes: 2);

  /// Returns the cached position, or null if not yet acquired.
  Position? get cachedPosition =>
      hasFreshCachedPosition ? _cachedPosition : null;

  DateTime? get cachedAt => _cachedAt;

  /// Whether we already have a usable cached position.
  bool get hasPosition => hasFreshCachedPosition;

  bool get hasFreshCachedPosition {
    final cachedAt = _cachedAt;
    if (_cachedPosition == null || cachedAt == null) {
      return false;
    }
    return DateTime.now().difference(cachedAt) <= cacheTtl;
  }

  /// Checks if location permission is already granted (no prompt).
  Future<bool> get hasPermission => _permissionService.hasLocationAccess();

  Future<LocationAccessState> accessState({bool background = false}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        clearCache();
        return LocationAccessState.serviceDisabled;
      }

      final state = await _permissionService.locationAccessState(
        background: background,
      );
      if (state != LocationAccessState.granted) {
        clearCache();
      }
      return state;
    } on Object catch (e) {
      AppLogger.error('Error checking location access state: $e');
      return LocationAccessState.unavailable;
    }
  }

  /// Requests location permission via AppPermissionService and returns position.
  /// Returns null if permission is denied or location services are disabled.
  /// Caches result in memory for fast subsequent access.
  Future<Position?> getCurrentPosition({
    bool allowCachedFallbackOnError = true,
    bool requireFresh = false,
  }) async {
    try {
      // Check location services
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.warning('Location services are disabled');
        clearCache();
        return null;
      }

      // Use unified permission service
      final granted = await _permissionService.ensureLocationAccess();
      if (!granted) {
        AppLogger.warning('Location permission not granted');
        clearCache();
        return null;
      }

      // Get fresh position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _remember(position);
      return position;
    } on Object catch (e) {
      AppLogger.error('Error getting current position: $e');
      if (!requireFresh &&
          allowCachedFallbackOnError &&
          hasFreshCachedPosition) {
        return _cachedPosition;
      }
      return null;
    }
  }

  /// Returns last known position from the OS (fast, no GPS lock needed).
  /// Falls back to cached position. Updates cache if successful.
  Future<Position?> getLastKnownOrCached() async {
    if (hasFreshCachedPosition) return _cachedPosition;

    try {
      final granted = await _permissionService.hasLocationAccess();
      if (!granted) return null;

      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _remember(last);
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
      startLat,
      startLng,
      endLat,
      endLng,
    );
    return meters / 1000.0;
  }

  Stream<Position> backgroundPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: _backgroundLocationSettings(),
    );
  }

  void clearCache() {
    _cachedPosition = null;
    _cachedAt = null;
  }

  void _remember(Position position) {
    _cachedPosition = position;
    _cachedAt = DateTime.now();
  }

  @visibleForTesting
  void setCachedPositionForTesting(Position position, DateTime cachedAt) {
    _cachedPosition = position;
    _cachedAt = cachedAt;
  }

  LocationSettings _backgroundLocationSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
        intervalDuration: const Duration(seconds: 15),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Mobio live location',
          notificationText:
              'Mobio is sharing your driver location while you are online.',
          notificationChannelName: 'Mobio live location',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }

    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 50,
        pauseLocationUpdatesAutomatically: true,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50,
    );
  }
}
