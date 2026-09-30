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

  test('account switch during eligibility cannot publish a location', () async {
    final eligibility = Completer<bool>();
    var current = true;
    var published = 0;
    final sharing = DriverLocationSharingService.test(
      locationService: _FakeLocationService(position: _position()),
      canShareAsDriver: () => eligibility.future,
      publishLocation: (_, _) async => published++,
      setOffline: () async {},
      captureAuthority: () =>
          SharingAuthority(identity: 'old-account', isCurrent: () => current),
    );

    final started = sharing.start();
    current = false;
    eligibility.complete(true);
    expect(await started, isFalse);
    expect(published, 0);
    expect(sharing.isSharing, isFalse);
  });

  test('stop during first publish compensates after late completion', () async {
    final publish = Completer<void>();
    var offlineCalls = 0;
    final sharing = DriverLocationSharingService.test(
      locationService: _FakeLocationService(position: _position()),
      canShareAsDriver: () async => true,
      publishLocation: (_, _) => publish.future,
      setOffline: () async => offlineCalls++,
    );

    final started = sharing.start();
    await Future<void>.delayed(Duration.zero);
    final stopped = sharing.stop();
    publish.complete();
    await stopped;
    expect(await started, isFalse);
    expect(sharing.isSharing, isFalse);
    expect(offlineCalls, greaterThanOrEqualTo(2));
  });

  test('older start cleanup finishes before a newer start publishes', () async {
    final firstPublish = Completer<void>();
    final events = <String>[];
    var publications = 0;
    final stream = StreamController<Position>();
    final sharing = DriverLocationSharingService.test(
      locationService: _FakeLocationService(
        position: _position(),
        stream: stream.stream,
      ),
      canShareAsDriver: () async => true,
      publishLocation: (_, type) async {
        events.add('publish-$type');
        if (++publications == 1) await firstPublish.future;
        events.add('online-$type');
      },
      setOffline: () async => events.add('offline'),
    );

    final oldStart = sharing.start(vehicleTypeId: 'old');
    await Future<void>.delayed(Duration.zero);
    final newStart = sharing.start(vehicleTypeId: 'new');
    await Future<void>.delayed(Duration.zero);
    expect(publications, 1);
    firstPublish.complete();
    expect(await oldStart, isFalse);
    expect(await newStart, isTrue);
    expect(events, [
      'publish-old',
      'online-old',
      'offline',
      'publish-new',
      'online-new',
    ]);
    expect(sharing.isSharing, isTrue);
    await sharing.stop();
    await stream.close();
  });

  test(
    'start during a pending stop publishes after the offline write',
    () async {
      final offline = Completer<void>();
      final events = <String>[];
      final stream = StreamController<Position>.broadcast();
      var blockOffline = false;
      final sharing = DriverLocationSharingService.test(
        locationService: _FakeLocationService(
          position: _position(),
          stream: stream.stream,
        ),
        canShareAsDriver: () async => true,
        publishLocation: (_, type) async => events.add('online-$type'),
        setOffline: () async {
          events.add('offline-start');
          if (blockOffline) await offline.future;
          events.add('offline-end');
        },
      );

      expect(await sharing.start(vehicleTypeId: 'old'), isTrue);
      blockOffline = true;
      final stopped = sharing.stop();
      final restarted = sharing.start(vehicleTypeId: 'new');
      await Future<void>.delayed(Duration.zero);
      expect(events, ['online-old', 'offline-start']);
      offline.complete();
      await stopped;
      expect(await restarted, isTrue);
      expect(events, [
        'online-old',
        'offline-start',
        'offline-end',
        'online-new',
      ]);
      expect(sharing.isSharing, isTrue);
      await sharing.stop();
      await stream.close();
    },
  );

  test('queued stream positions cannot publish after stop', () async {
    final publish = Completer<void>();
    final stream = StreamController<Position>();
    final positions = <double>[];
    final sharing = DriverLocationSharingService.test(
      locationService: _FakeLocationService(
        position: _position(),
        stream: stream.stream,
      ),
      canShareAsDriver: () async => true,
      publishLocation: (position, _) async {
        positions.add(position.latitude);
        if (positions.length == 2) await publish.future;
      },
      setOffline: () async {},
    );

    expect(await sharing.start(), isTrue);
    stream.add(_position(latitude: -1));
    await Future<void>.delayed(Duration.zero);
    stream.add(_position(latitude: -2));
    await Future<void>.delayed(Duration.zero);
    final stopped = sharing.stop();
    publish.complete();
    await stopped;
    await stream.close();
    expect(positions, [-1.95, -1]);
    expect(sharing.isSharing, isFalse);
  });

  test(
    'late old-account publication cannot take a new account offline',
    () async {
      final publish = Completer<void>();
      var current = true;
      var offlineCalls = 0;
      final sharing = DriverLocationSharingService.test(
        locationService: _FakeLocationService(position: _position()),
        canShareAsDriver: () async => true,
        publishLocation: (_, _) => publish.future,
        setOffline: () async => offlineCalls++,
        captureAuthority: () =>
            SharingAuthority(identity: 'old', isCurrent: () => current),
      );

      final started = sharing.start();
      await Future<void>.delayed(Duration.zero);
      current = false;
      final stopped = sharing.stop();
      publish.complete();
      expect(await started, isFalse);
      await stopped;
      expect(offlineCalls, 0);
      expect(sharing.isSharing, isFalse);
    },
  );

  test('failed replacement start retires the previous live sharing', () async {
    var eligible = true;
    var offlineCalls = 0;
    final stream = StreamController<Position>();
    final sharing = DriverLocationSharingService.test(
      locationService: _FakeLocationService(
        position: _position(),
        stream: stream.stream,
      ),
      canShareAsDriver: () async => eligible,
      publishLocation: (_, _) async {},
      setOffline: () async => offlineCalls++,
    );
    expect(await sharing.start(vehicleTypeId: 'old'), isTrue);
    eligible = false;
    expect(await sharing.start(vehicleTypeId: 'new'), isFalse);
    expect(sharing.isSharing, isFalse);
    expect(offlineCalls, 1);
    await sharing.stop();
    await stream.close();
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
