import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobi_app/core/location/location_service.dart';
import 'package:mobi_app/core/permissions/app_permission_service.dart';
import 'package:mobi_app/features/nearby/data/driver_location_sharing_service.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

void main() {
  test('does not publish when driver profile is not eligible', () async {
    var published = 0;
    var offline = false;
    final sharing = DriverLocationSharingService.test(
      locationService: _FakeLocationService(position: _position()),
      canShareAsDriver: () async => false,
      publishLocation: (_, _) async => published++,
      setOffline: () async => offline = true,
    );

    expect(await sharing.start(), isFalse);
    expect(published, 0);
    expect(sharing.isSharing, isFalse);

    await sharing.stop();
    expect(offline, isTrue);
  });

  test('does not go online without a fresh first location', () async {
    var published = 0;
    final sharing = DriverLocationSharingService.test(
      locationService: _FakeLocationService(position: null),
      canShareAsDriver: () async => true,
      publishLocation: (_, _) async => published++,
      setOffline: () async {},
    );

    expect(await sharing.start(), isFalse);
    expect(published, 0);
    expect(sharing.isSharing, isFalse);
  });

  test('publishes first fresh location and stops offline', () async {
    var published = 0;
    var offline = false;
    final stream = StreamController<Position>();
    final sharing = DriverLocationSharingService.test(
      locationService: _FakeLocationService(
        position: _position(latitude: -1.95, longitude: 30.06),
        stream: stream.stream,
      ),
      canShareAsDriver: () async => true,
      publishLocation: (_, _) async => published++,
      setOffline: () async => offline = true,
    );

    expect(await sharing.start(), isTrue);
    expect(sharing.isSharing, isTrue);
    expect(published, 1);

    stream.add(_position(latitude: -1.96, longitude: 30.07));
    await Future<void>.delayed(Duration.zero);
    expect(published, 2);

    await sharing.stop();
    await stream.close();
    expect(sharing.isSharing, isFalse);
    expect(offline, isTrue);
  });
}

Position _position({double latitude = -1.95, double longitude = 30.06}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.now(),
    accuracy: 10,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

class _FakeLocationService extends LocationService {
  _FakeLocationService({required this.position, Stream<Position>? stream})
    : _stream = stream ?? const Stream<Position>.empty(),
      super(
        permissionService: AppPermissionService(
          readStatus: (_) async => permissions.PermissionStatus.granted,
          requestPermission: (_) async => permissions.PermissionStatus.granted,
          openSettings: () async => true,
          supportsRuntimePermissions: true,
        ),
      );

  final Position? position;
  final Stream<Position> _stream;

  @override
  Future<Position?> getCurrentPosition({
    bool allowCachedFallbackOnError = true,
    bool requireFresh = false,
  }) async {
    return position;
  }

  @override
  Stream<Position> backgroundPositionStream() => _stream;
}
