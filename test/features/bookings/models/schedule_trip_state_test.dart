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
        expect(withDestination.canSubmit(now), isTrue);

        final busWithoutAgency = withDestination.copyWith(
          vehicleId: 'bus',
          transportAgencyNames: const ['Volcano Express', 'Ritco'],
        );
        expect(
          busWithoutAgency.validateForSubmit(now),
          'Select the bus agency.',
        );
        expect(busWithoutAgency.canSubmit(now), isFalse);

        final busWithAgency = busWithoutAgency.copyWith(
          busAgencyName: 'volcano express',
        );
        expect(busWithAgency.normalizedBusAgencyName, 'Volcano Express');
        expect(busWithAgency.validateForSubmit(now), isNull);
        expect(busWithAgency.canSubmit(now), isTrue);

        final rentalWithoutModel = withDestination.copyWith(
          vehicleId: 'rentals',
        );
        expect(
          rentalWithoutModel.validateForSubmit(now),
          'Select the rental vehicle model.',
        );
        expect(rentalWithoutModel.canSubmit(now), isFalse);

        final rentalWithModel = rentalWithoutModel.copyWith(
          rentalVehicleModel: 'suv',
        );
        expect(rentalWithModel.normalizedRentalVehicleModel, 'SUV');
        expect(rentalWithModel.validateForSubmit(now), isNull);
        expect(rentalWithModel.canSubmit(now), isTrue);

        final otherWithoutModel = withDestination.copyWith(
          vehicleId: 'private',
        );
        expect(
          otherWithoutModel.validateForSubmit(now),
          'Select the vehicle model.',
        );
        expect(otherWithoutModel.canSubmit(now), isFalse);

        final otherWithModel = otherWithoutModel.copyWith(
          rentalVehicleModel: 'van',
        );
        expect(otherWithModel.normalizedRentalVehicleModel, 'Van');
        expect(otherWithModel.validateForSubmit(now), isNull);
        expect(otherWithModel.canSubmit(now), isTrue);

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
        'origin_place_id': 'origin-place',
        'destination': 'Kigali Arena',
        'dest_lat': -1.94,
        'dest_lng': 30.1,
        'destination_place_id': 'destination-place',
        'departure_date': '2026-06-09',
        'departure_time': '03:45 PM',
        'role': 'driver',
        'vehicle_type': 'private',
        'is_recurring': true,
        'recurring_days': [0, 2, 4],
        'client_request_id': 'trip-request-1',
        'note': 'Two bags',
      });

      final state = ScheduleTripState.fromTrip(trip);

      expect(state.isEditMode, isTrue);
      expect(state.editingTrip?.id, 'trip-1');
      expect(state.selectedRole, 'driver');
      expect(state.originDetails?.formattedAddress, 'Kigali Heights');
      expect(state.originDetails?.placeId, 'origin-place');
      expect(state.originDetails?.latitude, -1.95);
      expect(state.destDetails?.formattedAddress, 'Kigali Arena');
      expect(state.destDetails?.placeId, 'destination-place');
      expect(state.destDetails?.longitude, 30.1);
      expect(state.date, DateTime(2026, 6, 9));
      expect(state.time, const TimeOfDay(hour: 15, minute: 45));
      expect(state.vehicleId, 'private_');
      expect(state.isRecurring, isTrue);
      expect(state.recurringDays, [0, 2, 4]);
      expect(state.clientRequestId, 'trip-request-1');
    });

    test('prefills rental vehicle model from a scheduled trip note', () {
      final trip = Trip.fromJson({
        'id': 'trip-2',
        'author_id': 'user-1',
        'origin': 'Kigali Heights',
        'origin_lat': -1.95,
        'origin_lng': 30.06,
        'origin_place_id': 'origin-place',
        'destination': 'Kigali Arena',
        'dest_lat': -1.94,
        'dest_lng': 30.1,
        'destination_place_id': 'destination-place',
        'departure_date': '2026-06-09',
        'departure_time': '03:45 PM',
        'role': 'passenger',
        'vehicle_type': 'rentals',
        'is_recurring': false,
        'recurring_days': [],
        'client_request_id': 'trip-request-2',
        'note': 'Rental model: Van\nAirport pickup',
      });

      final state = ScheduleTripState.fromTrip(trip);

      expect(state.vehicleId, 'rentals');
      expect(state.rentalVehicleModel, 'Van');
      expect(state.normalizedRentalVehicleModel, 'Van');
    });

    test('prefills other vehicle model from a scheduled trip note', () {
      final trip = Trip.fromJson({
        'id': 'trip-4',
        'author_id': 'user-1',
        'origin': 'Kigali Heights',
        'origin_lat': -1.95,
        'origin_lng': 30.06,
        'origin_place_id': 'origin-place',
        'destination': 'Kigali Arena',
        'dest_lat': -1.94,
        'dest_lng': 30.1,
        'destination_place_id': 'destination-place',
        'departure_date': '2026-06-09',
        'departure_time': '03:45 PM',
        'role': 'passenger',
        'vehicle_type': 'private',
        'is_recurring': false,
        'recurring_days': [],
        'client_request_id': 'trip-request-4',
        'note': 'Vehicle model: SUV\nFlexible option',
      });

      final state = ScheduleTripState.fromTrip(trip);

      expect(state.vehicleId, 'private_');
      expect(state.rentalVehicleModel, 'SUV');
      expect(state.normalizedRentalVehicleModel, 'SUV');
    });

    test('prefills bus agency from a scheduled trip note', () {
      final trip = Trip.fromJson({
        'id': 'trip-3',
        'author_id': 'user-1',
        'origin': 'Kigali Heights',
        'origin_lat': -1.95,
        'origin_lng': 30.06,
        'origin_place_id': 'origin-place',
        'destination': 'Kigali Arena',
        'dest_lat': -1.94,
        'dest_lng': 30.1,
        'destination_place_id': 'destination-place',
        'departure_date': '2026-06-09',
        'departure_time': '03:45 PM',
        'role': 'passenger',
        'vehicle_type': 'bus',
        'is_recurring': false,
        'recurring_days': [],
        'client_request_id': 'trip-request-3',
        'note': 'Bus agency: Ritco\nWindow seat',
      });

      final state = ScheduleTripState.fromTrip(
        trip,
        transportAgencyNames: const ['Volcano Express', 'Ritco'],
      );

      expect(state.vehicleId, 'bus');
      expect(state.busAgencyName, 'Ritco');
      expect(state.normalizedBusAgencyName, 'Ritco');
    });
  });
}
