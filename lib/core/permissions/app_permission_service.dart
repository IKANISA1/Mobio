import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/location/location_access_state.dart';
import 'package:mobi_app/core/platform/platform_io.dart';
import 'package:permission_handler/permission_handler.dart';

typedef PermissionStatusReader =
    Future<PermissionStatus?> Function(Permission permission);
typedef PermissionRequester =
    Future<PermissionStatus?> Function(Permission permission);
typedef OpenSettingsCallback = Future<bool> Function();

class AppPermissionService {
  AppPermissionService({
    PermissionStatusReader? readStatus,
    PermissionRequester? requestPermission,
    OpenSettingsCallback? openSettings,
    bool? supportsRuntimePermissions,
    Duration readTimeout = RequestDeadline.readTimeout,
    Duration promptTimeout = const Duration(seconds: 60),
  }) : _readStatus = readStatus ?? _defaultReadStatus,
       _requestPermission = requestPermission ?? _defaultRequestPermission,
       _openSettings = openSettings ?? _defaultOpenSettings,
       _supportsRuntimePermissions =
           supportsRuntimePermissions ?? (Platform.isAndroid || Platform.isIOS),
       _readTimeout = readTimeout,
       _promptTimeout = promptTimeout;

  static final instance = AppPermissionService();

  final PermissionStatusReader _readStatus;
  final PermissionRequester _requestPermission;
  final OpenSettingsCallback _openSettings;
  final bool _supportsRuntimePermissions;
  final Duration _readTimeout;
  final Duration _promptTimeout;

  /// Requests location permission (whenInUse).
  /// Returns true if granted/limited, false otherwise.
  /// Opens settings if permanently denied.
  Future<bool> ensureLocationAccess() =>
      _ensureActionPermission(Permission.locationWhenInUse);

  /// Requests background location for explicit driver live-sharing actions.
  Future<bool> ensureBackgroundLocationAccess() async {
    if (!_supportsRuntimePermissions) {
      return false;
    }

    final foregroundGranted = await ensureLocationAccess();
    if (!foregroundGranted) {
      return false;
    }

    return _ensureActionPermission(Permission.locationAlways);
  }

  /// Checks if location permission is already granted without prompting.
  Future<bool> hasLocationAccess() async {
    final status = await _safeReadStatus(Permission.locationWhenInUse);
    return status != null && (status.isGranted || status.isLimited);
  }

  /// Checks if background live-sharing location is already granted.
  Future<bool> hasBackgroundLocationAccess() async {
    if (!_supportsRuntimePermissions) {
      return false;
    }

    final status = await _safeReadStatus(Permission.locationAlways);
    return status != null && (status.isGranted || status.isLimited);
  }

  Future<LocationAccessState> locationAccessState({
    bool background = false,
  }) async {
    if (background && !_supportsRuntimePermissions) {
      return LocationAccessState.unavailable;
    }

    final status = await _safeReadStatus(
      background ? Permission.locationAlways : Permission.locationWhenInUse,
    );
    if (status == null) return LocationAccessState.unavailable;
    return _locationAccessStateForPermissionStatus(status);
  }

  Future<bool> openAppPermissionSettings() => RequestDeadline.mutation(
    _openSettings(),
    operation: 'open_permission_settings',
    timeout: _readTimeout,
  );

  Future<bool> _ensureActionPermission(Permission permission) async {
    final currentStatus = await _safeReadStatus(permission);
    // An absent platform implementation cannot establish consent. Do not open
    // another prompt or Settings until the permission channel is available.
    if (currentStatus == null) return false;
    if (currentStatus.isGranted || currentStatus.isLimited) {
      return true;
    }

    if (currentStatus.isPermanentlyDenied || currentStatus.isRestricted) {
      if (_supportsRuntimePermissions) await openAppPermissionSettings();
      return false;
    }

    final requestedStatus = await _safeRequestPermission(permission);
    if (requestedStatus == null) return false;
    if (requestedStatus.isGranted || requestedStatus.isLimited) {
      return true;
    }

    if (requestedStatus.isPermanentlyDenied || requestedStatus.isRestricted) {
      if (_supportsRuntimePermissions) await openAppPermissionSettings();
    }

    return false;
  }

  Future<PermissionStatus?> _safeReadStatus(Permission permission) async {
    try {
      return await RequestDeadline.read(
        _readStatus(permission),
        timeout: _readTimeout,
      );
    } on MissingPluginException {
      return null;
    } on UnimplementedError {
      return null;
    } on UnsupportedError {
      return null;
    }
  }

  Future<PermissionStatus?> _safeRequestPermission(
    Permission permission,
  ) async {
    try {
      // A prompt may remain visible after the caller stops waiting. No retry is
      // started here; a later action re-reads the platform's actual permission.
      return await RequestDeadline.read(
        _requestPermission(permission),
        timeout: _promptTimeout,
      );
    } on MissingPluginException {
      return null;
    } on UnimplementedError {
      return null;
    } on UnsupportedError {
      return null;
    }
  }

  static Future<PermissionStatus?> _defaultReadStatus(
    Permission permission,
  ) async {
    if (Platform.isAndroid || Platform.isIOS) return permission.status;
    if (permission != Permission.locationWhenInUse) return null;
    return _geolocationPermission(await Geolocator.checkPermission());
  }

  static Future<PermissionStatus?> _defaultRequestPermission(
    Permission permission,
  ) async {
    if (Platform.isAndroid || Platform.isIOS) return permission.request();
    if (permission != Permission.locationWhenInUse) return null;
    return _geolocationPermission(await Geolocator.requestPermission());
  }

  static PermissionStatus _geolocationPermission(
    LocationPermission permission,
  ) => switch (permission) {
    LocationPermission.always ||
    LocationPermission.whileInUse => PermissionStatus.granted,
    LocationPermission.deniedForever => PermissionStatus.permanentlyDenied,
    // A browser without the Permissions API has no observed grant yet.
    // The explicit enable-location action can still request a real fix.
    LocationPermission.denied ||
    LocationPermission.unableToDetermine => PermissionStatus.denied,
  };

  static Future<bool> _defaultOpenSettings() {
    if (Platform.isAndroid || Platform.isIOS) return openAppSettings();
    // Browsers own site permissions; neither native Settings bridge is usable.
    return Future.value(false);
  }

  static LocationAccessState _locationAccessStateForPermissionStatus(
    PermissionStatus status,
  ) {
    if (status.isGranted || status.isLimited) {
      return LocationAccessState.granted;
    }
    if (status.isPermanentlyDenied) {
      return LocationAccessState.permanentlyDenied;
    }
    if (status.isRestricted) {
      return LocationAccessState.restricted;
    }
    if (status.isDenied) {
      return LocationAccessState.denied;
    }
    return LocationAccessState.unavailable;
  }
}
