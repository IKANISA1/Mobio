import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/services/otp_service.dart';

void main() {
  group('OtpResult', () {
    test('creates successful result', () {
      const result = OtpResult(success: true, message: 'Sent');
      expect(result.success, true);
      expect(result.message, 'Sent');
      expect(result.retryAfterSeconds, isNull);
      expect(result.attemptsRemaining, isNull);
    });

    test('creates failure result with retry info', () {
      const result = OtpResult(
        success: false,
        message: 'Rate limited',
        retryAfterSeconds: 45,
      );
      expect(result.success, false);
      expect(result.retryAfterSeconds, 45);
    });

    test('creates failure result with attempts remaining', () {
      const result = OtpResult(
        success: false,
        message: 'Invalid code',
        attemptsRemaining: 3,
      );
      expect(result.success, false);
      expect(result.attemptsRemaining, 3);
    });
  });
}
