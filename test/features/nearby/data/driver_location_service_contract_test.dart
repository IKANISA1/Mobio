import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/nearby/data/driver_location_service.dart';

void main() {
  const validDriver = <String, dynamic>{
    'driver_id': '11111111-1111-4111-8111-111111111111',
    'member_id': '123456',
    'vehicle_type_id': 'cab',
    'latitude': -1.95,
    'longitude': 30.06,
    'distance_km': 0.4,
  };

  test('nearby driver keeps a verified six-digit member ID', () {
    final driver = NearbyDriver.fromJson(validDriver);
    expect(driver.memberId, '123456');
    expect(driver.distanceKm, 0.4);
  });

  test(
    'nearby driver rejects missing or malformed identity and coordinates',
    () {
      for (final row in [
        {...validDriver, 'member_id': null},
        {...validDriver, 'member_id': '12345'},
        {...validDriver, 'driver_id': 'not-a-uuid'},
        {...validDriver, 'latitude': 91},
        {...validDriver, 'longitude': double.nan},
        {...validDriver, 'distance_km': -1},
      ]) {
        expect(() => NearbyDriver.fromJson(row), throwsFormatException);
      }
    },
  );

  test('discover summary requires confirmed nonnegative RPC counts', () {
    final summary = DiscoverSummary.fromJson(const {
      'nearby_driver_count': 2,
      'scheduled_trip_count': 3,
    });
    expect(summary.nearbyDriverCount, 2);
    expect(summary.scheduledTripCount, 3);
    expect(
      () => DiscoverSummary.fromJson(const {'nearby_driver_count': 0}),
      throwsFormatException,
    );
    expect(
      () => DiscoverSummary.fromJson(const {
        'nearby_driver_count': -1,
        'scheduled_trip_count': 2,
      }),
      throwsFormatException,
    );
  });
}
