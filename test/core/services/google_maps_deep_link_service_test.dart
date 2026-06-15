import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/services/google_maps_deep_link_service.dart';

void main() {
  group('GoogleMapsDeepLinkService', () {
    test('builds a Google Maps route deep link', () {
      final uri = GoogleMapsDeepLinkService.routeUri(
        originLat: -1.9503,
        originLng: 30.0588,
        destLat: -1.4997,
        destLng: 29.6347,
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['origin'], '-1.9503,30.0588');
      expect(uri.queryParameters['destination'], '-1.4997,29.6347');
      expect(uri.queryParameters['travelmode'], 'driving');
    });

    test('adds Google place IDs when the route has real Google places', () {
      final uri = GoogleMapsDeepLinkService.routeUri(
        originLat: -1.9503,
        originLng: 30.0588,
        originLabel: 'Kigali Heights',
        originPlaceId: 'ChIJoriginGooglePlaceId',
        destLat: -1.4997,
        destLng: 29.6347,
        destLabel: 'Musanze Bus Park',
        destPlaceId: 'ChIJdestinationGooglePlaceId',
      );

      expect(uri.queryParameters['origin'], 'Kigali Heights');
      expect(uri.queryParameters['origin_place_id'], 'ChIJoriginGooglePlaceId');
      expect(uri.queryParameters['destination'], 'Musanze Bus Park');
      expect(
        uri.queryParameters['destination_place_id'],
        'ChIJdestinationGooglePlaceId',
      );
      expect(uri.toString(), isNot(contains('/maps/dir/?api=1&origin=%2F')));
    });

    test('does not send local preview IDs as Google place IDs', () {
      final uri = GoogleMapsDeepLinkService.routeUri(
        originLat: -1.9503,
        originLng: 30.0588,
        originLabel: 'Kigali Heights',
        originPlaceId: 'current-location-preview',
        destLat: -1.4997,
        destLng: 29.6347,
        destLabel: 'Musanze Bus Park',
        destPlaceId: 'trip-destination-preview',
      );

      expect(uri.queryParameters['origin'], '-1.9503,30.0588');
      expect(uri.queryParameters['origin_place_id'], isNull);
      expect(uri.queryParameters['destination'], '-1.4997,29.6347');
      expect(uri.queryParameters['destination_place_id'], isNull);
    });

    test('builds a Google Maps live vehicle location deep link', () {
      final uri = GoogleMapsDeepLinkService.liveLocationUri(
        vehicleLat: -1.9441,
        vehicleLng: 30.0619,
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/search/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['query'], '-1.9441,30.0619');
    });

    test('builds a Google Maps multi-driver deep link', () {
      final uri = GoogleMapsDeepLinkService.nearbyDriverLocationsUri(
        originLat: -1.9503,
        originLng: 30.0588,
        drivers: const [
          GoogleMapsLocation(latitude: -1.9441, longitude: 30.0619),
          GoogleMapsLocation(latitude: -1.9428, longitude: 30.0654),
        ],
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['origin'], '-1.9503,30.0588');
      expect(uri.queryParameters['destination'], '-1.9428,30.0654');
      expect(uri.queryParameters['waypoints'], '-1.9441,30.0619');
      expect(uri.queryParameters['travelmode'], 'driving');
    });

    test('sends every nearby driver location as a route stop', () {
      final drivers = List.generate(
        12,
        (index) => GoogleMapsLocation(
          latitude: -1.94 - (index * 0.001),
          longitude: 30.06 + (index * 0.001),
          label: 'Driver ${index + 1}',
        ),
      );

      final uri = GoogleMapsDeepLinkService.nearbyDriverLocationsUri(
        originLat: -1.9503,
        originLng: 30.0588,
        drivers: drivers,
      );
      final waypointStops = uri.queryParameters['waypoints']!.split('|');

      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['origin'], '-1.9503,30.0588');
      expect(uri.queryParameters['destination'], drivers.last.coordinate);
      expect(waypointStops, hasLength(11));
      expect(waypointStops.first, drivers.first.coordinate);
      expect(waypointStops.last, drivers[10].coordinate);
      for (final driver in drivers) {
        expect(
          uri.toString(),
          contains(Uri.encodeComponent(driver.coordinate)),
        );
      }
    });
  });
}
