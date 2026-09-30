import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/bookings/domain/public_transport_wire_record.dart';

Map<String, dynamic> confirmation() => {
  'booking_id': 'booking-1',
  'ticket_reference': 'MB-123',
  'status': 'confirmed',
  'payment_status': 'paid',
  'amount': 7000,
  'currency': 'RWF',
};

void main() {
  test('confirmed booking retains authoritative amounts and states', () {
    final result = PublicTransportWireRecord.confirmation(
      confirmation(),
      bookingId: 'booking-1',
    );
    expect(result.amount, 7000);
    expect(result.status, 'confirmed');
  });

  for (final missing in ['booking_id', 'status', 'payment_status', 'amount']) {
    test('missing $missing cannot fabricate a confirmed booking', () {
      expect(
        () => PublicTransportWireRecord.confirmation(
          confirmation()..remove(missing),
          bookingId: 'booking-1',
        ),
        throwsFormatException,
      );
    });
  }

  test('wrong booking reply cannot confirm the requested booking', () {
    expect(
      () => PublicTransportWireRecord.confirmation(
        confirmation(),
        bookingId: 'booking-2',
      ),
      throwsFormatException,
    );
  });

  test('multiple write receipts cannot discard an extra booking', () {
    expect(
      () => PublicTransportWireRecord.single([confirmation(), confirmation()]),
      throwsFormatException,
    );
  });

  test('malformed list entry cannot disappear', () {
    expect(() => PublicTransportWireRecord.rows([7]), throwsFormatException);
  });
}
