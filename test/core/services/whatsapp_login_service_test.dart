import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/services/whatsapp_login_service.dart';

void main() {
  group('WhatsAppLoginService phone normalization', () {
    test('removes local trunk zero for Rwanda numbers', () {
      expect(
        WhatsAppLoginService.normalizePhoneForCountry(
          phone: '0788 123 456',
          countryCode: '+250',
        ),
        '+250788123456',
      );
    });

    test('keeps canonical E.164 phone numbers', () {
      expect(
        WhatsAppLoginService.normalizePhoneForCountry(
          phone: '+250788123456',
          countryCode: '+250',
        ),
        '+250788123456',
      );
    });

    test('handles pasted country code without plus', () {
      expect(
        WhatsAppLoginService.normalizePhoneForCountry(
          phone: '250788123456',
          countryCode: '+250',
        ),
        '+250788123456',
      );
    });

    test('rejects short canonical numbers for send readiness', () {
      expect(WhatsAppLoginService.isValidCanonicalPhone('+25012'), false);
      expect(WhatsAppLoginService.isValidCanonicalPhone('+250788123456'), true);
    });

    test('uses selected-country semantics for send readiness', () {
      expect(
        WhatsAppLoginService.isValidCanonicalPhone(
          '788123456',
          countryCode: '+250',
        ),
        true,
      );
      expect(
        WhatsAppLoginService.isValidCanonicalPhone(
          '356123456',
          countryCode: '+250',
        ),
        false,
      );
    });
  });
}
