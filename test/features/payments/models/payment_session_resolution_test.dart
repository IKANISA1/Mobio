import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/payments/models/payment_session_resolution.dart';

void main() {
  group('PaymentSessionResolution', () {
    test('parses QR resolver payload', () {
      final resolution = PaymentSessionResolution.fromJson({
        'session_id': '11111111-1111-1111-1111-111111111111',
        'intent_id': '22222222-2222-2222-2222-222222222222',
        'payment_method': 'qr',
        'payee_id': '33333333-3333-3333-3333-333333333333',
        'payee_member_id': '123456',
        'payee_display_name': 'Driver One',
        'amount': 1500,
        'currency': 'RWF',
        'status': 'active',
        'expires_at': '2026-05-01T12:00:00Z',
      });

      expect(resolution.sessionId, '11111111-1111-1111-1111-111111111111');
      expect(resolution.intentId, '22222222-2222-2222-2222-222222222222');
      expect(resolution.paymentMethod, 'qr');
      expect(resolution.payeeMemberId, '123456');
      expect(resolution.amount, 1500);
      expect(resolution.currency, 'RWF');
      expect(resolution.expiresAt, DateTime.utc(2026, 5, 1, 12));
    });

    test('allows resolver payload without amount or intent', () {
      final resolution = PaymentSessionResolution.fromJson({
        'session_id': '11111111-1111-1111-1111-111111111111',
        'intent_id': null,
        'payment_method': 'nfc',
        'payee_id': '33333333-3333-3333-3333-333333333333',
        'payee_member_id': null,
        'payee_display_name': 'MOBI member',
        'amount': null,
        'currency': 'RWF',
        'status': 'active',
        'expires_at': '2026-05-01T12:00:00Z',
      });

      expect(resolution.intentId, isNull);
      expect(resolution.paymentMethod, 'nfc');
      expect(resolution.amount, isNull);
    });
  });
}
