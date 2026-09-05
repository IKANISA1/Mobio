import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_shared_types/models/country.dart';

void main() {
  group('Country fallback catalog', () {
    test('covers the full active African country-code seed', () {
      expect(Country.fallbackCountries.length, 48);
      expect(
        Country.fallbackCountries.map((country) => country.dialingCode),
        containsAll(<String>[
          '+211',
          '+220',
          '+221',
          '+229',
          '+233',
          '+234',
          '+244',
          '+250',
          '+254',
          '+255',
          '+256',
          '+260',
          '+263',
          '+27',
        ]),
      );
    });
  });
}
