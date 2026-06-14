import 'package:flutter/services.dart';
import 'package:mobi_app/core/platform/platform_io.dart';
import 'package:mobi_app/core/services/location_access_state.dart';
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
  }) : _readStatus = readStatus ?? _defaultReadStatus,
       _requestPermission = requestPermission ?? _defaultRequestPermission,
       _openSettings = openSettings ?? openAppSettings,
       _supportsRuntimePermissions =
           supportsRuntimePermissions ?? (Platform.isAndroid || Platform.isIOS);

  static final instance = AppPermissionService();

  final PermissionStatusReader _readStatus;
  final PermissionRequester _requestPermission;
  final OpenSettingsCallback _openSettings;
  final bool _supportsRuntimePermissions;

  /// Requests location permission (whenInUse).
  /// Returns true if granted/limited, false otherwise.
  /// Opens settings if permanently denied.
  Future<bool> ensureLocationAccess() async {
    if (_supportsRuntimePermissions) {
      return _ensureActionPermission(Permission.locationWhenInUse);
    }
    return Future.value(true);
  }

  /// Requests always/background location after foreground access is granted.
  /// Only call this from an explicit driver live-sharing action.
  Future<bool> ensureBackgroundLocationAccess() async {
    if (!_supportsRuntimePermissions) {
      return true;
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

  /// Checks if always/background location is already granted without prompting.
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

  Future<bool> openAppPermissionSettings() => _openSettings();

  Future<bool> _ensureActionPermission(Permission permission) async {
    final currentStatus = await _safeReadStatus(permission);
    if (currentStatus.isGranted || currentStatus.isLimited) {
      return true;
    }

    if (currentStatus.isPermanentlyDenied || currentStatus.isRestricted) {
      await _openSettings();
      return false;
    }

    final requestedStatus = await _safeRequestPermission(permission);
    if (requestedStatus.isGranted || requestedStatus.isLimited) {
      return true;
    }

    if (requestedStatus.isPermanentlyDenied || requestedStatus.isRestricted) {
      await _openSettings();
    }

    return false;
  }

  Future<PermissionStatus> _safeReadStatus(Permission permission) async {
    try {
      return await _readStatus(permission);
    } on MissingPluginException {
      return PermissionStatus.granted;
    } on UnimplementedError {
      return PermissionStatus.granted;
    }
  }

  Future<PermissionStatus> _safeRequestPermission(Permission permission) async {
    try {
      return await _requestPermission(permission);
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
