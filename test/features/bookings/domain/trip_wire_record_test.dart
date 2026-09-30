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
    'is_recurring': false,
    'recurring_days': <int>[],
    'recurrence_end_date': null,
    'recurrence_skip_dates': <String>[],
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
  test(
    'recurrence flags and day indices do not inherit generated defaults',
    () {
      for (final invalid in [
        {...row}..remove('is_recurring'),
        {...row}..remove('recurring_days'),
        {...row}..remove('recurrence_skip_dates'),
        {...row, 'is_recurring': true},
        {
          ...row,
          'recurring_days': [0.5],
        },
        {
          ...row,
          'recurring_days': [7],
        },
        {
          ...row,
          'recurring_days': [0, 0],
        },
        {...row, 'recurrence_end_date': '2026-02-31'},
        {
          ...row,
          'recurrence_skip_dates': ['2026-02-31'],
        },
      ]) {
        expect(() => TripWireRecord.parse(invalid), throwsFormatException);
      }
    },
  );

  test(
    'optional coordinates stay nullable but reject nonfinite/out-of-range values',
    () {
      expect(
        TripWireRecord.parse({...row, 'origin_lat': null}).originLat,
        isNull,
      );
      for (final invalid in [
        {...row, 'origin_lat': double.nan},
        {...row, 'dest_lat': 91},
        {...row, 'dest_lng': -181},
        {...row, 'origin_lng': '30'},
      ]) {
        expect(() => TripWireRecord.parse(invalid), throwsFormatException);
      }
    },
  );

  test(
    'pool occurrence uses its declared projection without losing original identity',
    () {
      final projection =
          <String, dynamic>{
              ...row,
              'trip_id': row['id'],
              'score': 85.4,
              'reason': 'Same travel day',
            }
            ..remove('id')
            ..remove('is_recurring')
            ..remove('recurring_days')
            ..remove('recurrence_skip_dates');
      final occurrence = TripWireRecord.parsePoolOccurrence(projection);
      expect(occurrence.id, row['id']);
      expect(occurrence.isRecurring, false);
      expect(occurrence.isActive, true);
      expect(occurrence.whatsapp, isEmpty);
      expect(
        () =>
            TripWireRecord.parsePoolOccurrence({...projection, 'score': null}),
        throwsFormatException,
      );
    },
  );
}
