import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/location/location_access_state.dart';
import 'package:mobi_app/core/permissions/app_permission_service.dart';
import 'package:mobi_app/core/platform/platform_io.dart';
import 'package:mobi_app/core/utils/app_logger.dart';

/// Wraps the Geolocator package for clean location access.
/// Caches last known position for fast autocomplete bias without blocking GPS.
class LocationService {
  LocationService({
    AppPermissionService? permissionService,
    DateTime Function()? now,
    int Function()? accountRevision,
  }) : _permissionService = permissionService ?? AppPermissionService.instance,
       _now = now ?? DateTime.now,
       _accountRevision =
           accountRevision ?? (() => AccountContext.changes.value);

  final AppPermissionService _permissionService;
  final DateTime Function() _now;
  final int Function() _accountRevision;

  /// In-memory cache — avoids repeated GPS queries during a session.
  Position? _cachedPosition;
  DateTime? _cachedAt;
  int? _cachedRevision;

  static const Duration cacheTtl = Duration(minutes: 2);
  // Discovery accepts approximate fixes within 1 km, without requiring the
  // user to grant precise location. Wider fixes are not a usable nearby bias.
  static const double maximumAccuracyMeters = 1000;

  /// Returns the cached position, or null if not yet acquired.
  Position? get cachedPosition =>
      hasFreshCachedPosition ? _cachedPosition : null;

  DateTime? get cachedAt => _cachedAt;

  /// Whether we already have a usable cached position.
  bool get hasPosition => hasFreshCachedPosition;

  bool get hasFreshCachedPosition {
    final cachedAt = _cachedAt;
    final position = _cachedPosition;
    if (position == null ||
        cachedAt == null ||
        _cachedRevision != _accountRevision()) {
      return false;
    }
    final age = _now().difference(cachedAt);
    return !age.isNegative && age <= cacheTtl && _isUsable(position);
  }

  /// Checks if location permission is already granted (no prompt).
  Future<bool> get hasPermission => _permissionService.hasLocationAccess();

  Future<LocationAccessState> accessState({bool background = false}) async {
    final revision = _accountRevision();
    try {
      final serviceEnabled = await RequestDeadline.read(
        Geolocator.isLocationServiceEnabled(),
      );
      if (revision != _accountRevision())
        return LocationAccessState.unavailable;
      if (!serviceEnabled) {
        clearCache();
        return LocationAccessState.serviceDisabled;
      }

      final state = await _permissionService.locationAccessState(
        background: background,
      );
      if (revision != _accountRevision())
        return LocationAccessState.unavailable;
      if (state != LocationAccessState.granted) {
        clearCache();
      }
      return state;
    } on Object catch (e) {
      AppLogger.error('Error checking location access state: $e');
      if (revision == _accountRevision()) clearCache();
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
    final revision = _accountRevision();
    var permissionConfirmed = false;
    try {
      // Check location services
      final serviceEnabled = await RequestDeadline.read(
        Geolocator.isLocationServiceEnabled(),
      );
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
      if (revision != _accountRevision()) return null;
      permissionConfirmed = true;

      // Get fresh position
      final position = await RequestDeadline.read(
        Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        ),
      );

      if (revision != _accountRevision() || !_remember(position)) return null;
      return position;
    } on Object catch (e) {
      AppLogger.error('Error getting current position: $e');
      if (!permissionConfirmed && revision == _accountRevision()) clearCache();
      if (permissionConfirmed &&
          !requireFresh &&
          allowCachedFallbackOnError &&
          revision == _accountRevision() &&
          hasFreshCachedPosition) {
        return _cachedPosition;
      }
      return null;
    }
  }

  /// Returns last known position from the OS (fast, no GPS lock needed).
  /// Falls back to cached position. Updates cache if successful.
  Future<Position?> getLastKnownOrCached() async {
    final revision = _accountRevision();
    try {
      final granted = await _permissionService.hasLocationAccess();
      final serviceEnabled = await RequestDeadline.read(
        Geolocator.isLocationServiceEnabled(),
      );
      if (!granted || !serviceEnabled) {
        clearCache();
        return null;
      }
      if (revision != _accountRevision()) return null;
      if (hasFreshCachedPosition) return _cachedPosition;

      final last = await RequestDeadline.read(
        Geolocator.getLastKnownPosition(),
      );
      if (revision != _accountRevision() || last == null || !_remember(last)) {
        return null;
      }
      return _cachedPosition;
    } on Object catch (e) {
      AppLogger.error('Error getting last known position: $e');
      if (revision == _accountRevision()) clearCache();
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
    _cachedRevision = null;
  }

  bool _remember(Position position) {
    if (!_isUsable(position)) {
      clearCache();
      return false;
    }
    _cachedPosition = position;
    // An OS last-known fix may predate this request. Its acquisition timestamp
    // owns freshness; retrieving it again must never renew the cache lifetime.
    _cachedAt = position.timestamp;
    _cachedRevision = _accountRevision();
    return true;
  }

  bool _isUsable(Position position) {
    final age = _now().difference(position.timestamp);
    return !age.isNegative &&
        age <= cacheTtl &&
        position.accuracy.isFinite &&
        position.accuracy >= 0 &&
        position.accuracy <= maximumAccuracyMeters &&
        position.latitude.isFinite &&
        position.latitude >= -90 &&
        position.latitude <= 90 &&
        position.longitude.isFinite &&
        position.longitude >= -180 &&
        position.longitude <= 180;
  }

  @visibleForTesting
  void setCachedPositionForTesting(Position position, DateTime cachedAt) {
    _cachedPosition = position;
    _cachedAt = cachedAt;
    _cachedRevision = _accountRevision();
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
