import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/services/driver_location_service.dart';

void main() {
  group('DriverDemandZone.fromJson', () {
    test('parses RPC demand zone payload', () {
      final zone = DriverDemandZone.fromJson({
        'zone_id': 'event:1',
        'label': 'Kigali Arena',
        'latitude': -1.954,
        'longitude': 30.104,
        'probability': 0.82,
        'reason': 'Event demand signal',
        'source': 'events',
        'starts_at': '2026-05-01T18:00:00Z',
      });

      expect(zone.zoneId, 'event:1');
      expect(zone.label, 'Kigali Arena');
      expect(zone.latitude, -1.954);
      expect(zone.longitude, 30.104);
      expect(zone.probability, 0.82);
      expect(zone.reason, 'Event demand signal');
      expect(zone.source, 'events');
      expect(zone.startsAt, '2026-05-01T18:00:00Z');
    });

    test('applies safe defaults for sparse payloads', () {
      final zone = DriverDemandZone.fromJson({});

      expect(zone.zoneId, '');
      expect(zone.label, '');
      expect(zone.latitude, 0);
      expect(zone.longitude, 0);
      expect(zone.probability, 0);
      expect(zone.reason, '');
      expect(zone.source, '');
      expect(zone.startsAt, isNull);
    });
  });
}
