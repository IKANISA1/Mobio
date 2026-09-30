import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/location/location_service.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/nearby/data/driver_location_service.dart';
import 'package:mobi_app/features/profile/data/profile_service.dart';

typedef DriverEligibilityReader = Future<bool> Function();
typedef DriverLocationPublisher =
    Future<void> Function(Position position, String? vehicleTypeId);
typedef DriverOfflineSetter = Future<void> Function();

class SharingAuthority {
  const SharingAuthority({required this.identity, required this.isCurrent});

  final String identity;
  final bool Function() isCurrent;
}

class DriverLocationSharingService {
  DriverLocationSharingService({
    required LocationService locationService,
    required DriverLocationService driverLocationService,
    required ProfileService profileService,
  }) : this._(
         locationService: locationService,
         canShareAsDriver: () async {
           final profile = await profileService.getMyProfile();
           return profile?.isDriver == true;
         },
         publishLocation: (position, vehicleTypeId) {
           return driverLocationService.updateLocation(
             latitude: position.latitude,
             longitude: position.longitude,
             heading: position.heading.isNaN ? null : position.heading,
             speed: position.speed.isNaN ? null : position.speed,
             vehicleTypeId: vehicleTypeId,
           );
         },
         setOffline: () => driverLocationService.setDriverOnlineStatus(false),
         captureAuthority: () {
           final account = AccountContext.capture();
           return SharingAuthority(
             identity: account.identity,
             isCurrent: () => AccountContext.isCurrent(account),
           );
         },
       );

  @visibleForTesting
  DriverLocationSharingService.test({
    required LocationService locationService,
    required DriverEligibilityReader canShareAsDriver,
    required DriverLocationPublisher publishLocation,
    required DriverOfflineSetter setOffline,
    SharingAuthority Function()? captureAuthority,
  }) : this._(
         locationService: locationService,
         canShareAsDriver: canShareAsDriver,
         publishLocation: publishLocation,
         setOffline: setOffline,
         captureAuthority:
             captureAuthority ??
             () => SharingAuthority(identity: 'test', isCurrent: () => true),
       );

  DriverLocationSharingService._({
    required this._locationService,
    required this._canShareAsDriver,
    required this._publishLocation,
    required this._setOffline,
    required this._captureAuthority,
  });

  final LocationService _locationService;
  final DriverEligibilityReader _canShareAsDriver;
  final DriverLocationPublisher _publishLocation;
  final DriverOfflineSetter _setOffline;
  final SharingAuthority Function() _captureAuthority;

  StreamSubscription<Position>? _subscription;
  String? _vehicleTypeId;
  SharingAuthority? _authority;
  int _revision = 0;
  Future<void> _mutationTail = Future<void>.value();

  bool get isSharing =>
      _subscription != null && _authority?.isCurrent() == true;

  Future<bool> start({String? vehicleTypeId}) async {
    final authority = _captureAuthority();
    if (!authority.isCurrent()) return false;
    if (_authority?.identity == authority.identity &&
        isSharing &&
        _vehicleTypeId == vehicleTypeId) {
      return true;
    }

    // Invalidate synchronously, before cancelling the previous subscription.
    // A pending start belongs to this authority too, so stop() can capture it.
    final revision = ++_revision;
    final oldSubscription = _subscription;
    final oldAuthority = _authority;
    _subscription = null;
    _authority = authority;
    _vehicleTypeId = vehicleTypeId;
    final retireOldSharing = oldSubscription == null
        ? Future<void>.value()
        : _serializeMutation(() async {
            if (oldAuthority?.isCurrent() == true) await _setOffline();
          });
    await Future.wait<void>([
      if (oldSubscription != null) oldSubscription.cancel(),
      retireOldSharing,
    ]);
    bool current() => revision == _revision && authority.isCurrent();
    if (!current()) return false;

    final canShare = await _canShareAsDriver();
    if (!current() || !canShare) {
      AppLogger.warning('Driver live sharing blocked for non-driver profile.');
      return false;
    }

    final initialPosition = await _locationService.getCurrentPosition(
      allowCachedFallbackOnError: false,
      requireFresh: true,
    );
    if (!current() || initialPosition == null) {
      AppLogger.warning('Driver live sharing could not get a fresh location.');
      return false;
    }

    if (!await _publishCurrent(
      initialPosition,
      vehicleTypeId,
      authority,
      revision,
    )) {
      return false;
    }
    if (!current()) return false;
    // The subscription is owned by this service and cancelled in stop().
    // ignore: cancel_subscriptions
    final subscription = _locationService.backgroundPositionStream().listen(
      (position) => unawaited(
        _publishSafely(position, vehicleTypeId, authority, revision),
      ),
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.error('Driver live sharing stream failed: $error');
      },
      cancelOnError: false,
    );
    _subscription = subscription;
    return true;
  }

  Future<void> stop() async {
    _revision++;
    final subscription = _subscription;
    var authority = _authority;
    _subscription = null;
    _authority = null;
    _vehicleTypeId = null;
    if (authority == null) {
      try {
        authority = _captureAuthority();
      } on Object {
        // There is no verified account to take offline during logout.
      }
    }
    final stoppedAuthority = authority;
    // Queue before awaiting cancellation. A later start's publish must follow
    // this offline write, and queued old stream events must be discarded.
    final offline = _serializeMutation(() async {
      if (stoppedAuthority?.isCurrent() == true) await _setOffline();
    });
    await Future.wait<void>([
      if (subscription != null) subscription.cancel(),
      offline,
    ]);
  }

  Future<T> _serializeMutation<T>(Future<T> Function() operation) {
    final work = _mutationTail.then((_) => operation());
    _mutationTail = work.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return work;
  }

  Future<bool> _publishCurrent(
    Position position,
    String? vehicleTypeId,
    SharingAuthority authority,
    int revision,
  ) {
    return _serializeMutation(() async {
      bool current() => revision == _revision && authority.isCurrent();
      if (!current()) return false;
      try {
        await _publishLocation(position, vehicleTypeId);
      } finally {
        // Compensation is part of this queued operation. It must finish before
        // a newer start can publish, or the older cleanup could disable it.
        if (!current() && authority.isCurrent()) await _setOffline();
      }
      return current();
    });
  }

  Future<void> _publishSafely(
    Position position,
    String? vehicleTypeId,
    SharingAuthority authority,
    int revision,
  ) async {
    try {
      await _publishCurrent(position, vehicleTypeId, authority, revision);
    } on Object catch (error) {
      AppLogger.error('Driver live sharing update unconfirmed: $error');
    }
  }
}
