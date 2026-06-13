import 'package:url_launcher/url_launcher.dart';

class GoogleMapsDeepLinkService {
  const GoogleMapsDeepLinkService._();

  static Uri routeUri({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) {
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': _coordinate(originLat, originLng),
      'destination': _coordinate(destLat, destLng),
      'travelmode': 'driving',
    });
  }

  static Uri liveLocationUri({
    required double vehicleLat,
    required double vehicleLng,
  }) {
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': _coordinate(vehicleLat, vehicleLng),
    });
  }

  static Uri nearbyDriverLocationsUri({
    required double originLat,
    required double originLng,
    required Iterable<({double latitude, double longitude})> drivers,
  }) {
    final coordinates = drivers.toList(growable: false);
    if (coordinates.isEmpty) {
      return liveLocationUri(vehicleLat: originLat, vehicleLng: originLng);
    }
    if (coordinates.length == 1) {
      final driver = coordinates.first;
      return routeUri(
        originLat: originLat,
        originLng: originLng,
        destLat: driver.latitude,
        destLng: driver.longitude,
      );
    }

    final stops = coordinates.take(10).toList(growable: false);
    final destination = stops.last;
    final waypointStops = stops
        .take(stops.length - 1)
        .map((driver) => _coordinate(driver.latitude, driver.longitude));

    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': _coordinate(originLat, originLng),
      'destination': _coordinate(destination.latitude, destination.longitude),
      'travelmode': 'driving',
      'waypoints': waypointStops.join('|'),
    });
  }

  static Future<bool> openRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) {
    return _open(
      routeUri(
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
      ),
    );
  }

  static Future<bool> openLiveLocation({
    required double vehicleLat,
    required double vehicleLng,
  }) {
    return _open(
      liveLocationUri(vehicleLat: vehicleLat, vehicleLng: vehicleLng),
    );
  }

  static Future<bool> openNearbyDriverLocations({
    required double originLat,
    required double originLng,
    required Iterable<({double latitude, double longitude})> drivers,
  }) {
    return _open(
      nearbyDriverLocationsUri(
        originLat: originLat,
        originLng: originLng,
        drivers: drivers,
      ),
    );
  }

  static Future<bool> _open(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static String _coordinate(double lat, double lng) => '$lat,$lng';
}
