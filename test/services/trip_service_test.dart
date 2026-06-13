import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/services/trip_service.dart';
import 'package:mobi_app/models/trip.dart';

/// Unit tests for Trip model serialization and TripService data contracts.
/// These verify that JSON from Supabase is correctly parsed into Trip objects
/// and that the effectiveVehicleType getter works as expected.
void main() {
  group('Trip.fromJson', () {
    test('parses complete trip row from Supabase', () {
      final json = {
        'id': '550e8400-e29b-41d4-a716-446655440000',
        'author_id': 'abc123',
        'author_name': 'Jean',
        'origin': 'Kigali',
        'origin_lat': -1.9403,
        'origin_lng': 29.8739,
        'destination': 'Musanze',
        'dest_lat': -1.4997,
        'dest_lng': 29.6347,
        'departure_date': '2026-03-25',
        'departure_time': '08:30',
        'date': '2026-03-25',
        'time': '08:30',
        'role': 'passenger',
        'whatsapp': '+250788000000',
        'seats': 2,
        'price': null,
        'note': 'Airport pickup',
        'description': null,
        'is_active': true,
        'status': 'active',
        'vehicle_type': 'cab',
        'is_recurring': false,
        'recurring_days': <int>[],
        'starts_at': '2026-03-25T08:30:00Z',
        'origin_place_id': 'origin-place',
        'destination_place_id': 'destination-place',
        'client_request_id': 'trip-request-1',
        'recurrence_end_date': null,
        'recurrence_skip_dates': <String>[],
        'cancelled_at': null,
        'joined_date': null,
        'created_at': '2026-03-25T08:00:00Z',
        'updated_at': '2026-03-25T08:00:00Z',
      };

      final trip = Trip.fromJson(json);

      expect(trip.id, '550e8400-e29b-41d4-a716-446655440000');
      expect(trip.authorId, 'abc123');
      expect(trip.authorName, 'Jean');
      expect(trip.origin, 'Kigali');
      expect(trip.originLat, -1.9403);
      expect(trip.originLng, 29.8739);
      expect(trip.destination, 'Musanze');
      expect(trip.destLat, -1.4997);
      expect(trip.destLng, 29.6347);
      expect(trip.departureDate, '2026-03-25');
      expect(trip.departureTime, '08:30');
      expect(trip.role, 'passenger');
      expect(trip.whatsapp, '+250788000000');
      expect(trip.seats, 2);
      expect(trip.note, 'Airport pickup');
      expect(trip.isActive, true);
      expect(trip.status, 'active');
      expect(trip.vehicleTypeStr, 'cab');
      expect(trip.isRecurring, false);
      expect(trip.recurringDays, isEmpty);
      expect(trip.startsAt, '2026-03-25T08:30:00Z');
      expect(trip.originPlaceId, 'origin-place');
      expect(trip.destinationPlaceId, 'destination-place');
      expect(trip.clientRequestId, 'trip-request-1');
      expect(trip.recurrenceSkipDates, isEmpty);
    });

    test('applies defaults for missing optional fields', () {
      final json = {'author_id': 'user-1', 'origin': 'A', 'destination': 'B'};

      final trip = Trip.fromJson(json);

      expect(trip.id, isNull);
      expect(trip.authorName, '');
      expect(trip.originLat, isNull);
      expect(trip.departureDate, '');
      expect(trip.departureTime, '');
      expect(trip.role, 'passenger');
      expect(trip.whatsapp, '');
      expect(trip.seats, 1);
      expect(trip.isActive, true);
      expect(trip.vehicleTypeStr, 'cab');
      expect(trip.isRecurring, false);
      expect(trip.recurringDays, isEmpty);
    });

    test('parses recurring trip with day indices', () {
      final json = {
        'author_id': 'user-2',
        'origin': 'Kigali',
        'destination': 'Huye',
        'is_recurring': true,
        'recurring_days': [0, 2, 4], // Mon, Wed, Fri
      };

      final trip = Trip.fromJson(json);

      expect(trip.isRecurring, true);
      expect(trip.recurringDays, [0, 2, 4]);
    });

    test('parses coordinates as doubles from integer values', () {
      final json = {
        'author_id': 'user-3',
        'origin': 'A',
        'destination': 'B',
        'origin_lat': -2, // int, not double
        'origin_lng': 30,
        'dest_lat': -1,
        'dest_lng': 29,
      };

      final trip = Trip.fromJson(json);

      expect(trip.originLat, -2.0);
      expect(trip.originLng, 30.0);
      expect(trip.destLat, -1.0);
      expect(trip.destLng, 29.0);
    });
  });

  group('Trip.effectiveVehicleType', () {
    test('returns cab for default vehicle_type string', () {
      final trip = Trip.fromJson({
        'author_id': 'u1',
        'origin': 'A',
        'destination': 'B',
        'vehicle_type': 'cab',
      });
      expect(trip.effectiveVehicleType.name, 'cab');
    });

    test('returns moto for moto vehicle_type string', () {
      final trip = Trip.fromJson({
        'author_id': 'u1',
        'origin': 'A',
        'destination': 'B',
        'vehicle_type': 'moto',
      });
      expect(trip.effectiveVehicleType.name, 'moto');
    });

    test('returns bus for bus vehicle_type string', () {
      final trip = Trip.fromJson({
        'author_id': 'u1',
        'origin': 'Kigali',
        'destination': 'Musanze',
        'vehicle_type': 'bus',
      });
      expect(trip.effectiveVehicleType.name, 'bus');
    });

    test('returns cab for unknown vehicle_type string', () {
      final trip = Trip.fromJson({
        'author_id': 'u1',
        'origin': 'A',
        'destination': 'B',
        'vehicle_type': 'spaceship',
      });
      expect(trip.effectiveVehicleType.name, 'cab');
    });
  });

  group('Trip cancelled state', () {
    test('cancelled trip has correct status', () {
      final trip = Trip.fromJson({
        'author_id': 'u1',
        'origin': 'A',
        'destination': 'B',
        'status': 'cancelled',
        // Now correctly mapped via @JsonKey(name: 'is_active')
        'is_active': false,
      });

      expect(trip.status, 'cancelled');
      expect(trip.isActive, false);
    });

    test('active trip defaults is_active to true', () {
      final trip = Trip.fromJson({
        'author_id': 'u1',
        'origin': 'A',
        'destination': 'B',
        'status': 'active',
      });

      expect(trip.status, 'active');
      expect(trip.isActive, true);
    });
  });

  group('expandTripsForScheduleWindow', () {
    test('expands recurring trips into upcoming bounded occurrences', () {
      final rows = [
        Trip.fromJson({
          'id': 'recurring-1',
          'author_id': 'u1',
          'origin': 'A',
          'destination': 'B',
          'departure_date': '2026-06-01',
          'departure_time': '08:30',
          'is_recurring': true,
          'recurring_days': [0, 2],
          'recurrence_end_date': '2026-06-17',
          'recurrence_skip_dates': ['2026-06-15'],
        }),
        Trip.fromJson({
          'id': 'single-1',
          'author_id': 'u1',
          'origin': 'C',
          'destination': 'D',
          'departure_date': '2026-06-15',
          'departure_time': '07:15',
        }),
      ];

      final expanded = expandTripsForScheduleWindow(
        rows,
        DateTime(2026, 6, 13, 12),
      );

      expect(
        expanded.map((trip) => '${trip.id}:${trip.departureDate}').toList(),
        ['single-1:2026-06-15', 'recurring-1:2026-06-17'],
      );
      expect(expanded[1].startsAt, '2026-06-17T08:30:00.000Z');
    });

    test('does not keep expired single or recurring trips', () {
      final rows = [
        Trip.fromJson({
          'id': 'past-single',
          'author_id': 'u1',
          'origin': 'A',
          'destination': 'B',
          'departure_date': '2026-06-01',
          'departure_time': '08:30',
        }),
        Trip.fromJson({
          'id': 'past-recurring',
          'author_id': 'u1',
          'origin': 'A',
          'destination': 'B',
          'departure_date': '2026-05-01',
          'departure_time': '08:30',
          'is_recurring': true,
          'recurring_days': [0],
          'recurrence_end_date': '2026-06-01',
        }),
      ];

      expect(
        expandTripsForScheduleWindow(rows, DateTime(2026, 6, 13)),
        isEmpty,
      );
    });
  });
}
