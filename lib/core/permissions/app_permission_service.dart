import 'package:flutter/services.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/location/location_access_state.dart';
import 'package:mobi_app/core/platform/platform_io.dart';
import 'package:permission_handler/permission_handler.dart';

typedef PermissionStatusReader =
    Future<PermissionStatus> Function(Permission permission);
typedef PermissionRequester =
    Future<PermissionStatus> Function(Permission permission);
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
       _openSettings = openSettings ?? openAppSettings,
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
  Future<bool> ensureLocationAccess() async {
    if (_supportsRuntimePermissions) {
      return _ensureActionPermission(Permission.locationWhenInUse);
    }
    return Future.value(true);
  }

  /// Requests background location for explicit driver live-sharing actions.
  Future<bool> ensureBackgroundLocationAccess() async {
    if (!_supportsRuntimePermissions) {
      return Future.value(true);
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
    return status.isGranted || status.isLimited;
  }

  /// Checks if background live-sharing location is already granted.
  Future<bool> hasBackgroundLocationAccess() async {
    if (!_supportsRuntimePermissions) {
      return true;
    }

    final status = await _safeReadStatus(Permission.locationAlways);
    return status.isGranted || status.isLimited;
  }

  Future<LocationAccessState> locationAccessState({
    bool background = false,
  }) async {
    if (!_supportsRuntimePermissions) {
      return LocationAccessState.granted;
    }

    final status = await _safeReadStatus(
      background ? Permission.locationAlways : Permission.locationWhenInUse,
    );
    return _locationAccessStateForPermissionStatus(status);
  }

  Future<bool> openAppPermissionSettings() => RequestDeadline.mutation(
    _openSettings(),
    operation: 'open_permission_settings',
    timeout: _readTimeout,
  );

  Future<bool> _ensureActionPermission(Permission permission) async {
    final currentStatus = await _safeReadStatus(permission);
    if (currentStatus.isGranted || currentStatus.isLimited) {
      return true;
    }

    if (currentStatus.isPermanentlyDenied || currentStatus.isRestricted) {
      await openAppPermissionSettings();
      return false;
    }

    final requestedStatus = await _safeRequestPermission(permission);
    if (requestedStatus.isGranted || requestedStatus.isLimited) {
      return true;
    }

    if (requestedStatus.isPermanentlyDenied || requestedStatus.isRestricted) {
      await openAppPermissionSettings();
    }

    return false;
  }

  Future<PermissionStatus> _safeReadStatus(Permission permission) async {
    try {
      return await RequestDeadline.read(
        _readStatus(permission),
        timeout: _readTimeout,
      );
    } on MissingPluginException {
      return PermissionStatus.granted;
    } on UnimplementedError {
      return PermissionStatus.granted;
    }
  }

  Future<PermissionStatus> _safeRequestPermission(Permission permission) async {
    try {
      // A prompt may remain visible after the caller stops waiting. No retry is
      // started here; a later action re-reads the platform's actual permission.
      return await RequestDeadline.read(
        _requestPermission(permission),
        timeout: _promptTimeout,
      );
    } on MissingPluginException {
      return PermissionStatus.granted;
    } on UnimplementedError {
      return PermissionStatus.granted;
    }
  }

  static Future<PermissionStatus> _defaultReadStatus(
    Permission permission,
  ) async {
    return permission.status;
  }

  static Future<PermissionStatus> _defaultRequestPermission(
    Permission permission,
  ) async {
    return permission.request();
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
