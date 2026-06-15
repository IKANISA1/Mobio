import 'package:url_launcher/url_launcher.dart';

class GoogleMapsLocation {
  final double latitude;
  final double longitude;
  final String? label;
  final String? placeId;

  const GoogleMapsLocation({
    required this.latitude,
    required this.longitude,
    this.label,
    this.placeId,
  });

  String get coordinate =>
      GoogleMapsDeepLinkService.coordinate(latitude, longitude);

  String get routeValue {
    final cleanLabel = label?.trim();
    if (cleanLabel != null &&
        cleanLabel.isNotEmpty &&
        GoogleMapsDeepLinkService.isGooglePlaceId(placeId)) {
      return cleanLabel;
    }
    return coordinate;
  }
}

class GoogleMapsDeepLinkService {
  const GoogleMapsDeepLinkService._();

  static Uri routeUri({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String? originLabel,
    String? originPlaceId,
    String? destLabel,
    String? destPlaceId,
  }) {
    return routeUriForLocations(
      origin: GoogleMapsLocation(
        latitude: originLat,
        longitude: originLng,
        label: originLabel,
        placeId: originPlaceId,
      ),
      destination: GoogleMapsLocation(
        latitude: destLat,
        longitude: destLng,
        label: destLabel,
        placeId: destPlaceId,
      ),
    );
  }

  static Uri routeUriForLocations({
    required GoogleMapsLocation origin,
    required GoogleMapsLocation destination,
  }) {
    final params = <String, String>{
      'api': '1',
      'origin': origin.routeValue,
      'destination': destination.routeValue,
      'travelmode': 'driving',
    };
    if (isGooglePlaceId(origin.placeId)) {
      params['origin_place_id'] = origin.placeId!.trim();
    }
    if (isGooglePlaceId(destination.placeId)) {
      params['destination_place_id'] = destination.placeId!.trim();
    }

    return Uri.https('www.google.com', '/maps/dir/', params);
  }

  static Uri liveLocationUri({
    required double vehicleLat,
    required double vehicleLng,
  }) {
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': coordinate(vehicleLat, vehicleLng),
    });
  }

  static Uri nearbyDriverLocationsUri({
    required double originLat,
    required double originLng,
    required Iterable<GoogleMapsLocation> drivers,
  }) {
    final driverLocations = drivers.toList(growable: false);
    if (driverLocations.isEmpty) {
      return liveLocationUri(vehicleLat: originLat, vehicleLng: originLng);
    }

    final origin = GoogleMapsLocation(
      latitude: originLat,
      longitude: originLng,
    );
    if (driverLocations.length == 1) {
      return routeUriForLocations(
        origin: origin,
        destination: driverLocations.first,
      );
    }

    final destination = driverLocations.last;
    final waypointStops = driverLocations
        .take(driverLocations.length - 1)
        .map((driver) => driver.coordinate);

    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': origin.coordinate,
      'destination': destination.coordinate,
      'travelmode': 'driving',
      'waypoints': waypointStops.join('|'),
    });
  }

  static Future<bool> openRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String? originLabel,
    String? originPlaceId,
    String? destLabel,
    String? destPlaceId,
  }) {
    return _open(
      routeUri(
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
        originLabel: originLabel,
        originPlaceId: originPlaceId,
        destLabel: destLabel,
        destPlaceId: destPlaceId,
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
    required Iterable<GoogleMapsLocation> drivers,
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

  static bool isGooglePlaceId(String? placeId) {
    final value = placeId?.trim();
    if (value == null || value.isEmpty) {
      return false;
    }
    const localPrefixes = [
      'current-location-preview',
      'home-preview',
      'work-preview',
      'airport-preview',
      'trip-origin-',
      'trip-destination-',
    ];
    return !localPrefixes.any(value.startsWith);
  }

  static String coordinate(double lat, double lng) => '$lat,$lng';
}
