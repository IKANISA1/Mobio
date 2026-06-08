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

  static Future<bool> _open(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static String _coordinate(double lat, double lng) => '$lat,$lng';
}
