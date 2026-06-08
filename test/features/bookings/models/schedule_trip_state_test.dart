import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/bookings/models/schedule_trip_state.dart';
import 'package:mobi_app/models/place.dart';
import 'package:mobi_app/models/trip.dart';

void main() {
  group('ScheduleTripState.copyWith', () {
    test('can clear nullable place fields', () {
      const origin = PlaceDetails(
        placeId: 'origin',
        formattedAddress: 'Kigali Heights',
        latitude: -1.95,
        longitude: 30.06,
      );
      const destination = PlaceDetails(
        placeId: 'destination',
        formattedAddress: 'Kigali Arena',
        latitude: -1.94,
        longitude: 30.1,
      );
      final state = ScheduleTripState(
        originDetails: origin,
        destDetails: destination,
        userLat: -1.95,
        userLng: 30.06,
        validationMessage: 'Old error',
      );

      final cleared = state.copyWith(
        originDetails: null,
        destDetails: null,
        userLat: null,
        userLng: null,
        validationMessage: null,
      );

      expect(cleared.originDetails, isNull);
      expect(cleared.destDetails, isNull);
      expect(cleared.userLat, isNull);
      expect(cleared.userLng, isNull);
      expect(cleared.validationMessage, isNull);
    });
  });

  group('ScheduleTripState.validateForSubmit', () {
    test(
      'requires role, route, future time, and repeat days when recurring',
      () {
        final now = DateTime(2026, 5, 1, 12);
        final base = ScheduleTripState(
          date: DateTime(2026, 5, 1),
          time: const TimeOfDay(hour: 13, minute: 0),
        );

        expect(
          base.validateForSubmit(now),
          'Choose whether this trip is for a passenger or driver.',
        );

        final withRole = base.copyWith(selectedRole: 'passenger');
        expect(withRole.validateForSubmit(now), 'Choose a pickup location.');

        final withOrigin = withRole.copyWith(
          originDetails: const PlaceDetails(
            placeId: 'origin',
            formattedAddress: 'Kigali Heights',
            latitude: -1.95,
            longitude: 30.06,
          ),
        );
        expect(withOrigin.validateForSubmit(now), 'Choose a destination.');

        final withDestination = withOrigin.copyWith(
          destDetails: const PlaceDetails(
            placeId: 'destination',
            formattedAddress: 'Kigali Arena',
            latitude: -1.94,
            longitude: 30.1,
          ),
        );
        expect(withDestination.validateForSubmit(now), isNull);

        final past = withDestination.copyWith(
          date: DateTime(2026, 5, 1),
          time: const TimeOfDay(hour: 11, minute: 59),
        );
        expect(past.validateForSubmit(now), 'Choose a future departure time.');

        final recurring = withDestination.copyWith(isRecurring: true);
        expect(
          recurring.validateForSubmit(now),
          'Choose at least one repeat day or turn repeat off.',
        );
      },
    );
  });

  group('ScheduleTripState.fromTrip', () {
    test('prefills edit mode from an existing scheduled trip', () {
      final trip = Trip.fromJson({
        'id': 'trip-1',
        'author_id': 'user-1',
        'origin': 'Kigali Heights',
        'origin_lat': -1.95,
        'origin_lng': 30.06,
        'destination': 'Kigali Arena',
        'dest_lat': -1.94,
        'dest_lng': 30.1,
        'departure_date': '2026-06-09',
        'departure_time': '03:45 PM',
        'role': 'driver',
        'vehicle_type': 'private',
        'is_recurring': true,
        'recurring_days': [0, 2, 4],
        'note': 'Two bags',
      });

      final state = ScheduleTripState.fromTrip(trip);

      expect(state.isEditMode, isTrue);
      expect(state.editingTrip?.id, 'trip-1');
      expect(state.selectedRole, 'driver');
      expect(state.originDetails?.formattedAddress, 'Kigali Heights');
      expect(state.originDetails?.latitude, -1.95);
      expect(state.destDetails?.formattedAddress, 'Kigali Arena');
      expect(state.destDetails?.longitude, 30.1);
      expect(state.date, DateTime(2026, 6, 9));
      expect(state.time, const TimeOfDay(hour: 15, minute: 45));
      expect(state.vehicleId, 'private_');
      expect(state.isRecurring, isTrue);
      expect(state.recurringDays, [0, 2, 4]);
    });
  });
}
