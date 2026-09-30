import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/bookings/domain/trip_wire_record.dart';

void main() {
  const row = <String, dynamic>{
    'id': '11111111-1111-4111-8111-111111111111',
    'author_id': '22222222-2222-4222-8222-222222222222',
    'origin': 'Kigali',
    'destination': 'Musanze',
    'departure_date': '2026-10-01',
    'departure_time': '09:00',
    'role': 'driver',
    'vehicle_type': 'cab',
    'status': 'active',
    'is_active': true,
    'whatsapp': '+250788123456',
  };

  test('public trip parser validates identity and redacts contact', () {
    final trip = TripWireRecord.parse(row);
    expect(trip.id, row['id']);
    expect(trip.authorId, row['author_id']);
    expect(trip.whatsapp, isEmpty);
    expect(
      TripWireRecord.parse(row, redactWhatsApp: false).whatsapp,
      '+250788123456',
    );
  });

  test('trip parser rejects missing or lossy required fields', () {
    for (final invalid in [
      {...row, 'id': null},
      {...row, 'author_id': 'not-a-uuid'},
      {...row, 'origin': ''},
      {...row, 'destination': null},
      {...row, 'departure_date': '2026-02-31'},
      {...row, 'departure_time': ''},
      {...row, 'role': 'unknown'},
      {...row, 'vehicle_type': 'rocket'},
      {...row, 'status': null},
      {...row, 'is_active': null},
    ]) {
      expect(() => TripWireRecord.parse(invalid), throwsFormatException);
    }
    expect(() => TripWireRecord.requireId('not-a-uuid'), throwsFormatException);
  });
}
