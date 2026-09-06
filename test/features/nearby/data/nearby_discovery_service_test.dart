import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobi_app/core/location/location_access_state.dart';
import 'package:mobi_app/core/location/location_service.dart';
import 'package:mobi_app/features/nearby/data/driver_location_service.dart';
import 'package:mobi_app/features/nearby/data/nearby_discovery_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late _Location location;
  late _Drivers drivers;
  late NearbyDiscoveryService service;

  setUp(() {
    location = _Location();
    drivers = _Drivers();
    service = NearbyDiscoveryService(
      locationService: location,
      driverLocationService: drivers,
    );
  });

  for (final state in [
    LocationAccessState.denied,
    LocationAccessState.permanentlyDenied,
    LocationAccessState.restricted,
    LocationAccessState.serviceDisabled,
  ]) {
    test('$state does not query drivers or request a position', () async {
      location.state = state;
      final result = await service.load(preferCachedLocation: true);
      expect(result.accessState, state);
      expect(result.latitude, isNull);
      expect(result.longitude, isNull);
      expect(result.drivers, isEmpty);
      expect(location.positionReads, 0);
      expect(location.cachedReads, 0);
      expect(location.cacheClears, 1);
      expect(drivers.calls, 0);
    });
  }

  test('no position is unavailable, not a successful empty search', () async {
    location.position = null;
    final result = await service.load();
    expect(result.accessState, LocationAccessState.unavailable);
    expect(result.latitude, isNull);
    expect(result.drivers, isEmpty);
    expect(drivers.calls, 0);
  });

  test(
    'a successful empty query stays ready and preserves its origin',
    () async {
      final result = await service.load(vehicleType: 'bus');
      expect(result.accessState, LocationAccessState.granted);
      expect(result.drivers, isEmpty);
      expect(result.latitude, -1.95);
      expect(result.longitude, 30.06);
      expect(drivers.calls, 1);
      expect(drivers.vehicleType, 'bus');
    },
  );

  test(
    'revoked access replaces populated results without stale coordinates',
    () async {
      drivers.result = [_driver];
      var result = await service.load();
      expect(result.drivers, hasLength(1));
      location.state = LocationAccessState.denied;
      result = await service.load();
      expect(result.accessState, LocationAccessState.denied);
      expect(result.drivers, isEmpty);
      expect(result.latitude, isNull);
      expect(result.longitude, isNull);
      expect(drivers.calls, 1);
    },
  );

  test('lost position also replaces previously populated results', () async {
    drivers.result = [_driver];
    await service.load();
    location.position = null;
    final result = await service.load();
    expect(result.accessState, LocationAccessState.unavailable);
    expect(result.drivers, isEmpty);
    expect(result.latitude, isNull);
    expect(result.longitude, isNull);
    expect(drivers.calls, 1);
  });

  test(
    'permission revoked during the query discards its late results',
    () async {
      final pending = Completer<List<NearbyDriver>>();
      drivers.pending = pending.future;
      final load = service.load();
      await drivers.started.future;
      location.state = LocationAccessState.denied;
      pending.complete([_driver]);
      final result = await load;
      expect(result.accessState, LocationAccessState.denied);
      expect(result.drivers, isEmpty);
      expect(result.latitude, isNull);
    },
  );

  test(
    'cached Home location is used only after checking current access',
    () async {
      location.cached = _position;
      final result = await service.load(preferCachedLocation: true);
      expect(result.accessState, LocationAccessState.granted);
      expect(location.cachedReads, 1);
      expect(location.positionReads, 0);
    },
  );

  test('backend errors propagate instead of becoming zero drivers', () async {
    drivers.error = const PostgrestException(message: 'Query unavailable');
    await expectLater(service.load(), throwsA(isA<PostgrestException>()));
  });
}

final _position = Position(
  latitude: -1.95,
  longitude: 30.06,
  timestamp: DateTime(2026, 9, 6),
  accuracy: 10,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

const _driver = NearbyDriver(
  driverId: 'test-driver',
  memberId: '123456',
  vehicleTypeId: 'cab',
  latitude: -1.951,
  longitude: 30.061,
  distanceKm: 0.2,
);

class _Location extends LocationService {
  LocationAccessState state = LocationAccessState.granted;
  Position? position = _position;
  Position? cached;
  int positionReads = 0;
  int cachedReads = 0;
  int cacheClears = 0;

  @override
  Future<LocationAccessState> accessState({bool background = false}) async =>
      state;

  @override
  Future<Position?> getCurrentPosition({
    bool allowCachedFallbackOnError = true,
    bool requireFresh = false,
  }) async {
    positionReads++;
    return position;
  }

  @override
  Future<Position?> getLastKnownOrCached() async {
    cachedReads++;
    return cached;
  }

  @override
  void clearCache() {
    cacheClears++;
    cached = null;
  }
}

class _Drivers implements DriverLocationService {
  int calls = 0;
  Object? error;
  String? vehicleType;
  List<NearbyDriver> result = [];
  Future<List<NearbyDriver>>? pending;
  final started = Completer<void>();

  @override
  Future<List<NearbyDriver>> findNearbyDrivers({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    String? vehicleType,
    int limit = 20,
  }) async {
    calls++;
    if (error != null) throw error!;
    this.vehicleType = vehicleType;
    if (!started.isCompleted) started.complete();
    return pending ?? result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
