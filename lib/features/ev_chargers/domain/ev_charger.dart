import 'dart:math' as math;

class EvCharger {
  const EvCharger({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.connectorTypes,
    required this.isActive,
    this.operatorName,
    this.phone,
    this.powerKw,
    this.priceNote,
    this.placeId,
    this.distanceKm,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final List<String> connectorTypes;
  final bool isActive;
  final String? operatorName;
  final String? phone;
  final double? powerKw;
  final String? priceNote;
  final String? placeId;
  final double? distanceKm;

  factory EvCharger.fromJson(Map<String, dynamic> json) {
    return EvCharger(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      connectorTypes: _stringList(json['connector_types']),
      isActive: json['is_active'] != false,
      operatorName: _optionalString(json['operator_name']),
      phone: _optionalString(json['phone']),
      powerKw: (json['power_kw'] as num?)?.toDouble(),
      priceNote: _optionalString(json['price_note']),
      placeId: _optionalString(json['place_id']),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }

  static List<EvCharger> previewChargers({
    double originLat = -1.9441,
    double originLng = 30.0619,
  }) {
    const chargers = [
      EvCharger(
        id: 'ev-preview-1',
        name: 'Kigali Heights EV Hub',
        address: 'KG 7 Ave, Kigali Heights',
        latitude: -1.9536,
        longitude: 30.0927,
        connectorTypes: ['CCS2', 'Type 2'],
        isActive: true,
        operatorName: 'Mobio Energy',
        powerKw: 60,
        priceNote: 'Pay at charger',
      ),
      EvCharger(
        id: 'ev-preview-2',
        name: 'Convention Centre Charger',
        address: 'KG 2 Roundabout, Kigali',
        latitude: -1.9539,
        longitude: 30.0929,
        connectorTypes: ['CCS2'],
        isActive: true,
        operatorName: 'Green Mobility Rwanda',
        powerKw: 120,
        priceNote: 'Fast DC charging',
      ),
      EvCharger(
        id: 'ev-preview-3',
        name: 'Airport Road EV Stop',
        address: 'KN 5 Rd, Kigali',
        latitude: -1.9612,
        longitude: 30.1308,
        connectorTypes: ['Type 2'],
        isActive: true,
        operatorName: 'Kigali Charge',
        powerKw: 22,
      ),
      EvCharger(
        id: 'ev-preview-4',
        name: 'Kacyiru Charge Point',
        address: 'KG 563 St, Kacyiru',
        latitude: -1.9359,
        longitude: 30.0827,
        connectorTypes: ['CCS2', 'CHAdeMO'],
        isActive: true,
        powerKw: 50,
      ),
      EvCharger(
        id: 'ev-preview-5',
        name: 'Nyamirambo EV Charger',
        address: 'KN 2 Ave, Nyamirambo',
        latitude: -1.9821,
        longitude: 30.0441,
        connectorTypes: ['Type 2'],
        isActive: true,
        powerKw: 11,
      ),
    ];

    return chargers
        .map(
          (charger) => EvCharger(
            id: charger.id,
            name: charger.name,
            address: charger.address,
            latitude: charger.latitude,
            longitude: charger.longitude,
            connectorTypes: charger.connectorTypes,
            isActive: charger.isActive,
            operatorName: charger.operatorName,
            phone: charger.phone,
            powerKw: charger.powerKw,
            priceNote: charger.priceNote,
            placeId: charger.placeId,
            distanceKm: _distanceKm(
              originLat,
              originLng,
              charger.latitude,
              charger.longitude,
            ),
          ),
        )
        .where(
          (charger) => charger.distanceKm == null || charger.distanceKm! <= 30,
        )
        .toList()
      ..sort((a, b) => (a.distanceKm ?? 0).compareTo(b.distanceKm ?? 0));
  }
}

String? _optionalString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return const [];
  return text
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

double _distanceKm(double fromLat, double fromLng, double toLat, double toLng) {
  const earthRadiusKm = 6371.0;
  final dLat = _radians(toLat - fromLat);
  final dLng = _radians(toLng - fromLng);
  final lat1 = _radians(fromLat);
  final lat2 = _radians(toLat);
  final a =
      _sinSquared(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * _sinSquared(dLng / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _radians(double degrees) => degrees * 0.017453292519943295;

double _sinSquared(double value) {
  final sin = math.sin(value);
  return sin * sin;
}
