import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobi_app/core/location/location_access_state.dart';
import 'package:mobi_app/core/location/location_service.dart';
import 'package:mobi_app/core/permissions/app_permission_service.dart';
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

    test('unavailable access clears an earlier permitted cache', () async {
      final service = LocationService(
        permissionService: _permissionService(
          permissions.PermissionStatus.granted,
        ),
      );
      final fix = _position(latitude: -1.95, longitude: 30.06);
      service.setCachedPositionForTesting(fix, fix.timestamp);
      fakeGeolocator.throwOnServiceCheck = true;
      expect(await service.accessState(), LocationAccessState.unavailable);
      expect(service.cachedPosition, isNull);
    });
  });

  group('LocationService cache freshness', () {
    test(
      'unknown permission cannot use a previously permitted cache',
      () async {
        final service = LocationService(
          permissionService: AppPermissionService(
            supportsRuntimePermissions: true,
            readStatus: (_) => Future.error(StateError('consent unavailable')),
          ),
        );
        final fix = _position(latitude: -1.95, longitude: 30.06);
        service.setCachedPositionForTesting(fix, fix.timestamp);
        expect(await service.getCurrentPosition(), isNull);
        expect(service.cachedPosition, isNull);
      },
    );
    test('cached fallback rechecks permission and disabled services', () async {
      var permission = permissions.PermissionStatus.granted;
      final service = LocationService(
        permissionService: AppPermissionService(
          supportsRuntimePermissions: true,
          readStatus: (_) async => permission,
          requestPermission: (_) async => permission,
        ),
      );
      final fix = _position(latitude: -1.95, longitude: 30.06);
      service.setCachedPositionForTesting(fix, fix.timestamp);
      permission = permissions.PermissionStatus.denied;
      expect(await service.getLastKnownOrCached(), isNull);
      expect(service.cachedPosition, isNull);

      permission = permissions.PermissionStatus.granted;
      service.setCachedPositionForTesting(fix, fix.timestamp);
      fakeGeolocator.serviceEnabled = false;
      expect(await service.getLastKnownOrCached(), isNull);
      expect(service.cachedPosition, isNull);
    });

    test(
      'account replacement hides cached fix and discards late GPS fix',
      () async {
        var revision = 1;
        final service = LocationService(
          permissionService: _permissionService(
            permissions.PermissionStatus.granted,
          ),
          accountRevision: () => revision,
        );
        final fix = _position(latitude: -1.95, longitude: 30.06);
        service.setCachedPositionForTesting(fix, fix.timestamp);
        revision++;
        expect(service.cachedPosition, isNull);
        final pending = Completer<Position>();
        fakeGeolocator.currentRequest = pending.future;
        final request = service.getCurrentPosition();
        await Future<void>.delayed(Duration.zero);
        revision++;
        pending.complete(fix);
        expect(await request, isNull);
        expect(service.cachedPosition, isNull);

        fakeGeolocator.currentRequest = null;
        fakeGeolocator.currentPosition = fix;
        expect(await service.getCurrentPosition(), fix);
      },
    );

    test('account replacement discards late OS last-known fix', () async {
      var revision = 1;
      final service = LocationService(
        permissionService: _permissionService(
          permissions.PermissionStatus.granted,
        ),
        accountRevision: () => revision,
      );
      final pending = Completer<Position?>();
      fakeGeolocator.lastKnownRequest = pending.future;
      final request = service.getLastKnownOrCached();
      await Future<void>.delayed(Duration.zero);
      revision++;
      pending.complete(_position(latitude: -1.95, longitude: 30.06));
      expect(await request, isNull);
      expect(service.cachedPosition, isNull);
    });

    test('retains the OS fix timestamp and expires from acquisition', () async {
      var now = DateTime.utc(2026, 10, 1, 10);
      final acquiredAt = now.subtract(const Duration(seconds: 110));
      fakeGeolocator.currentPosition = _position(
        latitude: -1.95,
        longitude: 30.06,
        timestamp: acquiredAt,
      );
      final service = LocationService(
        permissionService: _permissionService(
          permissions.PermissionStatus.granted,
        ),
        now: () => now,
      );

      expect(
        await service.getLastKnownOrCached(),
        fakeGeolocator.currentPosition,
      );
      expect(service.cachedAt, acquiredAt);
      now = now.add(const Duration(seconds: 11));
      expect(service.cachedPosition, isNull);
      expect(await service.getLastKnownOrCached(), isNull);
    });

    final invalidFixes = <String, Position>{
      'old': _position(
        latitude: -1.95,
        longitude: 30.06,
        timestamp: DateTime.utc(2026, 10, 1, 9, 57),
      ),
      'future': _position(
        latitude: -1.95,
        longitude: 30.06,
        timestamp: DateTime.utc(2026, 10, 1, 10, 0, 1),
      ),
      'inaccurate': _position(
        latitude: -1.95,
        longitude: 30.06,
        timestamp: DateTime.utc(2026, 10, 1, 10),
        accuracy: 5000,
      ),
      'negative accuracy': _position(
        latitude: -1.95,
        longitude: 30.06,
        timestamp: DateTime.utc(2026, 10, 1, 10),
        accuracy: -1,
      ),
      'nonfinite accuracy': _position(
        latitude: -1.95,
        longitude: 30.06,
        timestamp: DateTime.utc(2026, 10, 1, 10),
        accuracy: double.nan,
      ),
      'invalid coordinates': _position(
        latitude: 91,
        longitude: 181,
        timestamp: DateTime.utc(2026, 10, 1, 10),
      ),
    };
    for (final entry in invalidFixes.entries) {
      test('${entry.key} OS fix cannot become a current bias', () async {
        fakeGeolocator.currentPosition = entry.value;
        final service = LocationService(
          permissionService: _permissionService(
            permissions.PermissionStatus.granted,
          ),
          now: () => DateTime.utc(2026, 10, 1, 10),
        );

        expect(await service.getLastKnownOrCached(), isNull);
        expect(await service.getCurrentPosition(requireFresh: true), isNull);
        expect(service.cachedAt, isNull);
        expect(service.hasPosition, isFalse);
      });
    }

    test(
      'usable approximate fix and fresh fallback retain their true age',
      () async {
        var now = DateTime.utc(2026, 10, 1, 10);
        fakeGeolocator.currentPosition = _position(
          latitude: -1.95,
          longitude: 30.06,
          timestamp: now,
          accuracy: 800,
        );
        final service = LocationService(
          permissionService: _permissionService(
            permissions.PermissionStatus.granted,
          ),
          now: () => now,
        );
        final acquired = await service.getCurrentPosition();
        expect(acquired, isNotNull);
        fakeGeolocator.currentPosition = null;
        now = now.add(const Duration(seconds: 60));
        expect(await service.getCurrentPosition(), acquired);
        expect(await service.getCurrentPosition(requireFresh: true), isNull);
        now = now.add(const Duration(seconds: 61));
        expect(await service.getCurrentPosition(), isNull);
      },
    );

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

Position _position({
  required double latitude,
  required double longitude,
  DateTime? timestamp,
  double accuracy = 15,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp ?? DateTime.now(),
    accuracy: accuracy,
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
  Future<Position>? currentRequest;
  Future<Position?>? lastKnownRequest;

  @override
  Future<bool> isLocationServiceEnabled() async {
    if (throwOnServiceCheck) {
      throw StateError('location service unavailable');
    }
    return serviceEnabled;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    if (currentRequest != null) return currentRequest!;
    final position = currentPosition;
    if (position == null) {
      throw StateError('no current position');
    }
    return Future.value(position);
  }

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) {
    if (lastKnownRequest != null) return lastKnownRequest!;
    return Future.value(currentPosition);
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    return const Stream<Position>.empty();
  }
}
