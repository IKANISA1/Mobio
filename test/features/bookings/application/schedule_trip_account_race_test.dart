import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/location/location_providers.dart';
import 'package:mobi_app/core/location/location_service.dart';
import 'package:mobi_app/core/location/places_service.dart';
import 'package:mobi_app/core/permissions/app_permission_service.dart';
import 'package:mobi_app/core/permissions/permission_providers.dart';
import 'package:mobi_app/features/bookings/application/booking_services.dart';
import 'package:mobi_app/features/bookings/application/schedule_trip_provider.dart';
import 'package:mobi_app/features/bookings/data/public_transport_service.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_app/features/profile/data/favorite_address_service.dart';
import 'package:mobi_app/features/profile/data/vehicle_type_service.dart';
import 'package:mobi_app/shared/models/vehicle_type_model.dart';
import 'package:mobi_shared_types/models/favorite_address.dart';
import 'package:mobi_shared_types/models/place.dart';

const _oldPlace = PlaceDetails(
  placeId: 'old',
  formattedAddress: 'Old pickup',
  latitude: -1,
  longitude: 30,
);
const _newPlace = PlaceDetails(
  placeId: 'new',
  formattedAddress: 'New pickup',
  latitude: -2,
  longitude: 30,
);

class _Location extends Fake implements LocationService {
  final requests = <Completer<Position?>>[];
  @override
  Future<Position?> getCurrentPosition({
    bool allowCachedFallbackOnError = true,
    bool requireFresh = false,
  }) {
    final request = Completer<Position?>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<Position?> getLastKnownOrCached() async => null;
}

class _Places extends Fake implements PlacesService {
  final requests = <Completer<PlaceDetails?>>[];
  @override
  Future<PlaceDetails?> reverseGeocode(double lat, double lng) {
    final request = Completer<PlaceDetails?>();
    requests.add(request);
    return request.future;
  }
}

class _Permissions extends Fake implements AppPermissionService {
  bool granted = false;
  @override
  Future<bool> hasLocationAccess() async => granted;
}

class _Types extends Fake implements VehicleTypeService {
  @override
  Future<List<VehicleTypeModel>> getAll({bool includeInactive = false}) async =>
      VehicleTypeModel.fallbackTypes;
}

class _Favorites extends Fake implements FavoriteAddressService {
  @override
  Future<List<FavoriteAddress>> list({bool activeOnly = true}) async => [];
}

class _Transport extends Fake implements PublicTransportService {
  @override
  Future<List<String>> getAgencyNames({bool includeInactive = false}) async => [
    'VOLCANO',
  ];
}

Position _position() => Position(
  latitude: -1,
  longitude: 30,
  timestamp: DateTime.now(),
  accuracy: 10,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);
Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Location location;
  late _Places places;
  late _Permissions permissions;
  var generation = 0;
  setUp(() {
    generation = 0;
    location = _Location();
    places = _Places();
    permissions = _Permissions();
    container = ProviderContainer(
      overrides: [
        scheduleTripProvider.overrideWith(
          () => ScheduleTripController.test(
            captureAccount: () =>
                AccountSnapshot('user', 'session', generation),
            isCurrent: (account) => account?.generation == generation,
          ),
        ),
        locationServiceProvider.overrideWithValue(location),
        placesServiceProvider.overrideWithValue(places),
        appPermissionServiceProvider.overrideWithValue(permissions),
        vehicleTypeServiceProvider.overrideWithValue(_Types()),
        favoriteAddressServiceProvider.overrideWithValue(_Favorites()),
        publicTransportServiceProvider.overrideWithValue(_Transport()),
      ],
    )..listen(scheduleTripProvider, (_, _) {});
    addTearDown(container.dispose);
  });

  test(
    'account change during location cannot start reverse geocoding',
    () async {
      await container.read(scheduleTripProvider.future);
      await _tick();
      final pending = container
          .read(scheduleTripProvider.notifier)
          .handleCurrentLocation();
      generation++;
      location.requests.single.complete(_position());
      await pending;
      expect(places.requests, isEmpty);
      expect(container.read(scheduleTripProvider).value?.originDetails, isNull);
    },
  );

  test(
    'late reverse geocode cannot replace a manually selected pickup',
    () async {
      await container.read(scheduleTripProvider.future);
      await _tick();
      final controller = container.read(scheduleTripProvider.notifier);
      final pending = controller.handleCurrentLocation();
      location.requests.single.complete(_position());
      await _tick();
      controller.setOrigin(_newPlace);
      places.requests.single.complete(_oldPlace);
      await pending;
      expect(
        container.read(scheduleTripProvider).value?.originDetails,
        _newPlace,
      );
      expect(
        container.read(scheduleTripProvider).value?.isLoadingLocation,
        isFalse,
      );
    },
  );

  test('older location callback cannot overwrite the newer request', () async {
    await container.read(scheduleTripProvider.future);
    await _tick();
    final controller = container.read(scheduleTripProvider.notifier);
    final oldRequest = controller.handleCurrentLocation();
    location.requests.first.complete(_position());
    await _tick();
    final newRequest = controller.handleCurrentLocation();
    location.requests.last.complete(_position());
    await _tick();
    places.requests.last.complete(_newPlace);
    await newRequest;
    places.requests.first.complete(_oldPlace);
    await oldRequest;
    expect(
      container.read(scheduleTripProvider).value?.originDetails,
      _newPlace,
    );
    expect(
      container.read(scheduleTripProvider).value?.isLoadingLocation,
      isFalse,
    );
  });

  test(
    'initial pickup prefill cannot commit after account invalidation',
    () async {
      permissions.granted = true;
      await container.read(scheduleTripProvider.future);
      await _tick();
      expect(location.requests, hasLength(1));
      generation++;
      location.requests.single.complete(_position());
      await _tick();
      expect(places.requests, isEmpty);
      expect(container.read(scheduleTripProvider).value?.userLat, isNull);
    },
  );

  test('disposed controller discards pending location work', () async {
    await container.read(scheduleTripProvider.future);
    await _tick();
    final pending = container
        .read(scheduleTripProvider.notifier)
        .handleCurrentLocation();
    container.dispose();
    location.requests.single.complete(_position());
    await pending;
    expect(places.requests, isEmpty);
  });
}
