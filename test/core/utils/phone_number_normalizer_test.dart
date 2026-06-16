import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/utils/phone_number_normalizer.dart';

void main() {
  group('PhoneNumberNormalizer', () {
    test('removes local trunk zero for Rwanda numbers', () {
      expect(
        PhoneNumberNormalizer.normalizeForCountry(
          phone: '0788 123 456',
          countryCode: '+250',
        ),
        '+250788123456',
      );
    });

    test('normalizes non-Rwanda local numbers with selected country code', () {
      expect(
        PhoneNumberNormalizer.normalizeForCountry(
          phone: '0999 971 114',
          countryCode: '+356',
        ),
        '+356999971114',
      );
      expect(
        PhoneNumberNormalizer.normalizeForCountry(
          phone: '020 7946 0958',
          countryCode: '+44',
        ),
        '+442079460958',
      );
    });

    test('keeps canonical E.164 and 00-prefixed numbers canonical', () {
      expect(
        PhoneNumberNormalizer.normalizeForCountry(
          phone: '+14155550100',
          countryCode: '+1',
        ),
        '+14155550100',
      );
      expect(
        PhoneNumberNormalizer.normalizeForCountry(
          phone: '004915112345678',
          countryCode: '+49',
        ),
        '+4915112345678',
      );
    });

    test('rejects too-short or too-long canonical values', () {
      expect(PhoneNumberNormalizer.isValidCanonical('+25012'), false);
      expect(PhoneNumberNormalizer.isValidCanonical('+250788123456'), true);
      expect(
        PhoneNumberNormalizer.isValidCanonical('+1234567890123456'),
        false,
      );
    });

    test('validates Rwanda local mobile semantics for selected country', () {
      expect(
        PhoneNumberNormalizer.isValidForCountry(
          phone: '0788 123 456',
          countryCode: '+250',
        ),
        true,
      );
      expect(
        PhoneNumberNormalizer.isValidForCountry(
          phone: '788123456',
          countryCode: '+250',
        ),
        true,
      );
      expect(
        PhoneNumberNormalizer.isValidForCountry(
          phone: '356123456',
          countryCode: '+250',
        ),
        false,
      );
      expect(
        PhoneNumberNormalizer.validateForCountry(
          phone: '356123456',
          countryCode: '+250',
        ).message,
        'Rwanda numbers must be 9 digits and start with 7.',
      );
    });

    test('validates Malta local mobile semantics for selected country', () {
      expect(
        PhoneNumberNormalizer.isValidForCountry(
          phone: '7718 6134',
          countryCode: '+356',
        ),
        true,
      );
      expect(
        PhoneNumberNormalizer.isValidForCountry(
          phone: '7718613',
          countryCode: '+356',
        ),
        false,
      );
      expect(
        PhoneNumberNormalizer.validateForCountry(
          phone: '7718613',
          countryCode: '+356',
        ).message,
        'Malta numbers must be 8 digits and start with 7 or 9.',
      );
    });
  });
}
