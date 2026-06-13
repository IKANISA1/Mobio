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
          (latitude: -1.9441, longitude: 30.0619),
          (latitude: -1.9428, longitude: 30.0654),
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
  });
}
