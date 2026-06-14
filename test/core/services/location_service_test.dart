import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobi_app/core/services/app_permission_service.dart';
import 'package:mobi_app/core/services/location_access_state.dart';
import 'package:mobi_app/core/services/location_service.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

void main() {
  late GeolocatorPlatform originalGeolocator;
  late _FakeGeolocatorPlatform fakeGeolocator;

  setUp(() {
    originalGeolocator = GeolocatorPlatform.instance;
    fakeGeolocator = _FakeGeolocatorPlatform();
    GeolocatorPlatform.instance = fakeGeolocator;
  });

  tearDown(() {
    GeolocatorPlatform.instance = originalGeolocator;
  });

  group('LocationAccessState', () {
    test('maps denied permission state', () async {
      final service = _permissionService(permissions.PermissionStatus.denied);

      expect(await service.locationAccessState(), LocationAccessState.denied);
    });

    test('maps permanently denied permission state', () async {
      final service = _permissionService(
        permissions.PermissionStatus.permanentlyDenied,
      );

      expect(
        await service.locationAccessState(),
        LocationAccessState.permanentlyDenied,
      );
    });

    test('maps restricted permission state', () async {
      final service = _permissionService(
        permissions.PermissionStatus.restricted,
      );

      expect(
        await service.locationAccessState(),
        LocationAccessState.restricted,
      );
    });

    test('treats limited or approximate permission as granted', () async {
      final service = _permissionService(permissions.PermissionStatus.limited);

      expect(await service.locationAccessState(), LocationAccessState.granted);
    });

    test('reports service disabled and clears cached coordinates', () async {
      fakeGeolocator.serviceEnabled = false;
      final locationService =
          LocationService(
            permissionService: _permissionService(
              permissions.PermissionStatus.granted,
            ),
          )..setCachedPositionForTesting(
            _position(latitude: -1.95, longitude: 30.06),
            DateTime.now(),
          );

      expect(
        await locationService.accessState(),
        LocationAccessState.serviceDisabled,
      );
      expect(locationService.cachedPosition, isNull);
      expect(locationService.hasFreshCachedPosition, isFalse);
    });

    test('reports unavailable when platform access check fails', () async {
      fakeGeolocator.throwOnServiceCheck = true;
      final locationService = LocationService(
        permissionService: _permissionService(
          permissions.PermissionStatus.granted,
        ),
      );

      expect(
        await locationService.accessState(),
        LocationAccessState.unavailable,
      );
    });
  });

  group('LocationService cache freshness', () {
    test('does not expose stale cached coordinates', () {
      final locationService =
          LocationService(
            permissionService: _permissionService(
              permissions.PermissionStatus.granted,
            ),
          )..setCachedPositionForTesting(
            _position(latitude: -1.95, longitude: 30.06),
            DateTime.now().subtract(LocationService.cacheTtl * 2),
          );

      expect(locationService.hasFreshCachedPosition, isFalse);
      expect(locationService.cachedPosition, isNull);
      expect(locationService.hasPosition, isFalse);
    });

    test('clears cache and returns null when permission is denied', () async {
      fakeGeolocator.currentPosition = _position(
        latitude: -1.95,
        longitude: 30.06,
      );
      final locationService =
          LocationService(
            permissionService: _permissionService(
              permissions.PermissionStatus.denied,
            ),
          )..setCachedPositionForTesting(
            _position(latitude: -1.94, longitude: 30.05),
            DateTime.now(),
          );

      final position = await locationService.getCurrentPosition();

      expect(position, isNull);
      expect(locationService.cachedPosition, isNull);
    });
  });
}

AppPermissionService _permissionService(permissions.PermissionStatus status) {
  return AppPermissionService(
    readStatus: (_) async => status,
    requestPermission: (_) async => status,
    openSettings: () async => true,
    supportsRuntimePermissions: true,
  );
}

Position _position({required double latitude, required double longitude}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.now(),
    accuracy: 15,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  bool serviceEnabled = true;
  bool throwOnServiceCheck = false;
  Position? currentPosition;

  @override
  Future<bool> isLocationServiceEnabled() async {
    if (throwOnServiceCheck) {
      throw StateError('location service unavailable');
    }
    return serviceEnabled;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    final position = currentPosition;
    if (position == null) {
      throw StateError('no current position');
    }
    return Future.value(position);
  }

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) {
    return Future.value(currentPosition);
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    return const Stream<Position>.empty();
  }
}
