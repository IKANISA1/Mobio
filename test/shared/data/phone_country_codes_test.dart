import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/shared/data/phone_country_codes.dart';

void main() {
  group('globalPhoneCountryCodes', () {
    test('covers the full global calling-code catalog', () {
      expect(globalPhoneCountryCodes.length, greaterThanOrEqualTo(240));

      final byIsoCode = {
        for (final country in globalPhoneCountryCodes) country.isoCode: country,
      };

      expect(byIsoCode, contains('BR'));
      expect(byIsoCode['BR']?.dialingCode, '+55');
      expect(byIsoCode, contains('CN'));
      expect(byIsoCode['CN']?.dialingCode, '+86');
      expect(byIsoCode, contains('GB'));
      expect(byIsoCode['GB']?.dialingCode, '+44');
      expect(byIsoCode, contains('IN'));
      expect(byIsoCode['IN']?.dialingCode, '+91');
      expect(byIsoCode, contains('MT'));
      expect(byIsoCode['MT']?.dialingCode, '+356');
      expect(byIsoCode, contains('RW'));
      expect(byIsoCode['RW']?.dialingCode, '+250');
      expect(byIsoCode, contains('US'));
      expect(byIsoCode['US']?.dialingCode, '+1');
    });

    test('keeps one picker row per ISO region', () {
      final isoCodes = globalPhoneCountryCodes
          .map((country) => country.isoCode)
          .toSet();

      expect(isoCodes.length, globalPhoneCountryCodes.length);
    });
  });
}
