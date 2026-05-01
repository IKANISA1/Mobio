import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/payments/services/payment_service.dart';

void main() {
  group('PaymentService external USSD contract', () {
    const service = PaymentService();

    test('extracts USSD instruction from tel QR payload', () {
      final instruction = service.instructionFromPayload(
        'tel:*182*1*1*0788123456*1500%23',
      );

      expect(instruction, isNotNull);
      expect(instruction!.ussdString, '*182*1*1*0788123456*1500#');
      expect(instruction.isDialable, isTrue);
    });

    test('extracts USSD instruction from deep-link payload', () {
      final instruction = service.instructionFromPayload(
        'mobi://pay?ussd=*182*8*1*AGENT42*3000%23',
      );

      expect(instruction, isNotNull);
      expect(instruction!.ussdString, '*182*8*1*AGENT42*3000#');
    });

    test('ignores non-USSD payment payloads', () {
      expect(service.instructionFromPayload('https://example.com/pay'), isNull);
      expect(service.instructionFromPayload(''), isNull);
    });

    test('does not create in-app payment intents', () async {
      await expectLater(
        service.createIntent(
          payeeId: 'payee',
          amount: 1000,
          currency: 'RWF',
          paymentMethod: 'ussd_momo',
        ),
        throwsA(isA<UnsupportedFlowException>()),
      );
    });

    test('does not verify payment status in-app', () async {
      await expectLater(
        service.verifyStatus('intent-id'),
        throwsA(isA<UnsupportedFlowException>()),
      );
    });
  });
}
