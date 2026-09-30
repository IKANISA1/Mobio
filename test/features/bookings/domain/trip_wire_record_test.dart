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

  test('departure clock retains canonical SQL and valid historical AM/PM', () {
    for (final entry in <String, ({int hour, int minute})>{
      '00:00': (hour: 0, minute: 0),
      '09:00': (hour: 9, minute: 0),
      '23:59': (hour: 23, minute: 59),
      '03:45 PM': (hour: 15, minute: 45),
      '3:45 pm': (hour: 15, minute: 45),
      '12:00 AM': (hour: 0, minute: 0),
      '12:00 PM': (hour: 12, minute: 0),
    }.entries) {
      expect(TripWireRecord.parseDepartureTime(entry.key), entry.value);
      expect(
        TripWireRecord.parse({
          ...row,
          'departure_time': entry.key,
        }).departureTime,
        entry.key,
      );
    }
  });

  test('impossible and partial departure clocks never enter a trip row', () {
    for (final value in <Object?>[
      null,
      900,
      '',
      'nonsense',
      '99:99',
      '09:99',
      '24:00',
      '00:30 AM',
      '13:30 PM',
      '09:00 garbage',
      '09:00:01',
      '03:45 PM trailing',
      '3:45',
      '09:00 AM PM',
    ]) {
      expect(
        () => TripWireRecord.parseDepartureTime(value),
        throwsFormatException,
      );
      expect(
        () => TripWireRecord.parse({...row, 'departure_time': value}),
        throwsFormatException,
      );
    }
  });

  test('departure date never rolls invalid values into another date', () {
    expect(
      TripWireRecord.parseDepartureDate('2026-10-01'),
      DateTime(2026, 10, 1),
    );
    for (final value in [null, '0000-01-01', '2026-02-31', 'today']) {
      expect(
        () => TripWireRecord.parseDepartureDate(value),
        throwsFormatException,
      );
    }
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
