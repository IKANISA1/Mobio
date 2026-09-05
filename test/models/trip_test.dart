import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_shared_types/models/trip.dart';
import 'package:mobi_shared_types/models/vehicle_type.dart';

void main() {
  group('Trip model', () {
    test('fromJson parses valid JSON', () {
      final json = <String, dynamic>{
        'id': 'trip-1',
        'author_id': 'user-1',
        'author_name': 'Jean',
        'origin': 'Downtown',
        'destination': 'Airport',
        'departure_date': '2026-03-25',
        'departure_time': '08:30 AM',
        'date': '2026-03-25',
        'time': '08:30 AM',
        'role': 'driver',
        'whatsapp': '+250788123456',
        'seats': 3,
        'price': '0.4 km',
        'is_active': true,
        'status': 'active',
        'vehicle_type': 'cab',
        'origin_lat': -1.9503,
        'origin_lng': 29.8839,
        'dest_lat': -1.9603,
        'dest_lng': 29.8939,
        'is_recurring': false,
        'recurring_days': <int>[],
      };

      final trip = Trip.fromJson(json);

      expect(trip.id, 'trip-1');
      expect(trip.authorId, 'user-1');
      expect(trip.authorName, 'Jean');
      expect(trip.origin, 'Downtown');
      expect(trip.destination, 'Airport');
      expect(trip.departureDate, '2026-03-25');
      expect(trip.departureTime, '08:30 AM');
      expect(trip.role, 'driver');
      expect(trip.isActive, true);
      expect(trip.originLat, -1.9503);
      expect(trip.originLng, 29.8839);
      expect(trip.destLat, -1.9603);
      expect(trip.destLng, 29.8939);
      expect(trip.isRecurring, false);
      expect(trip.recurringDays, isEmpty);
    });

    test('fromJson handles minimal JSON with only required fields', () {
      final json = <String, dynamic>{
        'author_id': 'user-1',
        'origin': 'A',
        'destination': 'B',
      };

      final trip = Trip.fromJson(json);
      expect(trip.authorId, 'user-1');
      expect(trip.origin, 'A');
      expect(trip.destination, 'B');
      // Check defaults
      expect(trip.role, 'passenger');
      expect(trip.isActive, true);
      expect(trip.seats, 1);
      expect(trip.isRecurring, false);
      expect(trip.vehicleTypeStr, 'cab');
    });

    test('TripStatus enum stays limited to scheduled-post states', () {
      expect(TripStatus.active.name, 'active');
      expect(TripStatus.cancelled.name, 'cancelled');
      expect(
        TripStatus.values.map((status) => status.name),
        isNot(contains('completed')),
      );
    });
  });

  group('Trip.effectiveVehicleType', () {
    test('returns enum when explicitly set', () {
      const trip = Trip(
        authorId: 'u1',
        origin: 'A',
        destination: 'B',
        vehicleType: VehicleType.moto,
        vehicleTypeStr: 'cab', // should be ignored
      );
      expect(trip.effectiveVehicleType, VehicleType.moto);
    });

    test('falls back to vehicleTypeStr when enum is null', () {
      const trip = Trip(
        authorId: 'u1',
        origin: 'A',
        destination: 'B',
        vehicleTypeStr: 'truck',
      );
      expect(trip.effectiveVehicleType, VehicleType.truck);
    });

    test('defaults to cab for unknown vehicleTypeStr', () {
      const trip = Trip(
        authorId: 'u1',
        origin: 'A',
        destination: 'B',
        vehicleTypeStr: 'unknown_type',
      );
      expect(trip.effectiveVehicleType, VehicleType.cab);
    });

    test('maps all known vehicle type strings correctly', () {
      final mapping = {
        'cab': VehicleType.cab,
        'moto': VehicleType.moto,
        'bus': VehicleType.bus,
        'trike': VehicleType.trike,
        'truck': VehicleType.truck,
        'private': VehicleType.private_,
        'rentals': VehicleType.rentals,
      };

      for (final entry in mapping.entries) {
        final trip = Trip(
          authorId: 'u1',
          origin: 'A',
          destination: 'B',
          vehicleTypeStr: entry.key,
        );
        expect(
          trip.effectiveVehicleType,
          entry.value,
          reason: 'vehicleTypeStr=${entry.key}',
        );
      }
    });
  });
}
