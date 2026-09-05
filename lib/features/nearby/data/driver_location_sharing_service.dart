import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobi_app/core/location/location_service.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/nearby/data/driver_location_service.dart';
import 'package:mobi_app/features/profile/data/profile_service.dart';

typedef DriverEligibilityReader = Future<bool> Function();
typedef DriverLocationPublisher =
    Future<void> Function(Position position, String? vehicleTypeId);
typedef DriverOfflineSetter = Future<void> Function();

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
       );

  @visibleForTesting
  DriverLocationSharingService.test({
    required LocationService locationService,
    required DriverEligibilityReader canShareAsDriver,
    required DriverLocationPublisher publishLocation,
    required DriverOfflineSetter setOffline,
  }) : this._(
         locationService: locationService,
         canShareAsDriver: canShareAsDriver,
         publishLocation: publishLocation,
         setOffline: setOffline,
       );

  DriverLocationSharingService._({
    required this._locationService,
    required this._canShareAsDriver,
    required this._publishLocation,
    required this._setOffline,
  });

  final LocationService _locationService;
  final DriverEligibilityReader _canShareAsDriver;
  final DriverLocationPublisher _publishLocation;
  final DriverOfflineSetter _setOffline;

  StreamSubscription<Position>? _subscription;
  String? _vehicleTypeId;

  bool get isSharing => _subscription != null;

  Future<bool> start({String? vehicleTypeId}) async {
    _vehicleTypeId = vehicleTypeId;
    if (_subscription != null) {
      return true;
    }

    final canShare = await _canShareAsDriver();
    if (!canShare) {
      AppLogger.warning('Driver live sharing blocked for non-driver profile.');
      return false;
    }

    final initialPosition = await _locationService.getCurrentPosition(
      allowCachedFallbackOnError: false,
      requireFresh: true,
    );
    if (initialPosition == null) {
      AppLogger.warning('Driver live sharing could not get a fresh location.');
      return false;
    }

    await _publish(initialPosition);
    // The subscription is owned by this service and cancelled in stop().
    // ignore: cancel_subscriptions
    final subscription = _locationService.backgroundPositionStream().listen(
      (position) => unawaited(_publish(position)),
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.error('Driver live sharing stream failed: $error');
      },
      cancelOnError: false,
    );
    _subscription = subscription;
    return true;
  }

  Future<void> stop() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    await _setOffline();
  }

  Future<void> _publish(Position position) {
    return _publishLocation(position, _vehicleTypeId);
  }
}
