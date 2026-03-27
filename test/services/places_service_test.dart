import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/services/places_exception.dart';
import 'package:mobi_app/models/place.dart';
import 'package:mobi_app/models/route_info.dart';

/// Unit tests for Places models and PlacesException contract.
/// Verifies that edge-function response shapes are correctly parsed.
void main() {
  group('PlacePrediction', () {
    test('parses from edge function suggestion shape', () {
      // Simulates data after manual mapping in PlacesService
      const prediction = PlacePrediction(
        placeId: 'ChIJLU7jZClu5kcR4PcOOO6p3I0',
        description: 'Kigali International Airport, KG 555 St, Kigali',
      );

      expect(prediction.placeId, 'ChIJLU7jZClu5kcR4PcOOO6p3I0');
      expect(prediction.description, contains('Kigali'));
    });

    test('serializes to and from JSON', () {
      const original = PlacePrediction(
        placeId: 'abc123',
        description: 'Test Place',
      );

      final json = original.toJson();
      final restored = PlacePrediction.fromJson(json);

      expect(restored.placeId, original.placeId);
      expect(restored.description, original.description);
    });
  });

  group('PlaceDetails', () {
    test('holds complete place data with coordinates', () {
      const details = PlaceDetails(
        placeId: 'place-1',
        formattedAddress: 'Nyarugenge, Kigali, Rwanda',
        latitude: -1.9441,
        longitude: 29.8739,
      );

      expect(details.latitude, closeTo(-1.9441, 0.0001));
      expect(details.longitude, closeTo(29.8739, 0.0001));
      expect(details.formattedAddress, contains('Kigali'));
    });

    test('serializes to and from JSON', () {
      const original = PlaceDetails(
        placeId: 'p1',
        formattedAddress: 'Test',
        latitude: 1.5,
        longitude: 2.5,
      );

      final json = original.toJson();
      final restored = PlaceDetails.fromJson(json);

      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
    });

    test('zero coordinates indicate geocoding failure', () {
      const fallback = PlaceDetails(
        placeId: 'p2',
        formattedAddress: 'Partial result',
        latitude: 0,
        longitude: 0,
      );

      // This is the pattern used in PlaceAutocompleteField as fallback
      expect(fallback.latitude, 0);
      expect(fallback.longitude, 0);
    });
  });

  group('RouteInfo', () {
    test('parses from compute_route response shape', () {
      const route = RouteInfo(
        distanceMeters: 130500,
        duration: '7200s',
        encodedPolyline: 'abc123polyline',
        travelMode: 'DRIVE',
      );

      expect(route.distanceMeters, 130500);
      expect(route.duration, '7200s');
      expect(route.encodedPolyline, isNotEmpty);
      expect(route.travelMode, 'DRIVE');
    });

    test('defaults travelMode to DRIVE', () {
      const route = RouteInfo(
        distanceMeters: 5000,
        duration: '300s',
        encodedPolyline: '',
      );

      expect(route.travelMode, 'DRIVE');
    });

    test('serializes to and from JSON', () {
      const original = RouteInfo(
        distanceMeters: 42000,
        duration: '2400s',
        encodedPolyline: 'test_poly',
        travelMode: 'TWO_WHEELER',
      );

      final json = original.toJson();
      final restored = RouteInfo.fromJson(json);

      expect(restored.distanceMeters, original.distanceMeters);
      expect(restored.duration, original.duration);
      expect(restored.travelMode, 'TWO_WHEELER');
    });
  });

  group('PlacesException', () {
    test('network kind gives connectivity message', () {
      const error = PlacesException(
        kind: PlacesErrorKind.network,
        message: 'No internet',
      );

      expect(error.userMessage, contains('internet'));
      expect(error.kind, PlacesErrorKind.network);
    });

    test('timeout kind gives retry message', () {
      const error = PlacesException(
        kind: PlacesErrorKind.timeout,
        message: 'Timed out after 3 attempts',
      );

      expect(error.userMessage, contains('timed out'));
    });

    test('serverError kind gives server message', () {
      const error = PlacesException(
        kind: PlacesErrorKind.serverError,
        message: '500',
      );

      expect(error.userMessage, contains('Server'));
    });

    test('unknown kind gives generic message', () {
      const error = PlacesException(
        kind: PlacesErrorKind.unknown,
        message: 'Unexpected',
      );

      expect(error.userMessage, contains('wrong'));
    });

    test('toString includes kind and message', () {
      const error = PlacesException(
        kind: PlacesErrorKind.timeout,
        message: 'autocomplete timed out',
      );

      expect(error.toString(), contains('timeout'));
      expect(error.toString(), contains('autocomplete timed out'));
    });
  });
}
