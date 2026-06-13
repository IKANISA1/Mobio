import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/profile/models/edit_profile_state.dart';
import 'package:mobi_app/models/country.dart';

void main() {
  group('EditProfileState', () {
    test('selectedCountry falls back when country list is empty', () {
      const state = EditProfileState(countries: []);

      expect(state.selectedCountry, Country.fallbackCountries.first);
    });

    test('selectedCountry uses matching dialing code', () {
      const state = EditProfileState(
        countries: Country.fallbackCountries,
        countryCode: '+254',
      );

      expect(state.selectedCountry.id, 'KE');
    });

    test('copyWith preserves bus onboarding fields', () {
      const state = EditProfileState(
        initialMomoNumber: '0788767816',
        initialMomoPayCode: '123456',
        initialBusAgencyName: 'Volcano Express',
        initialBusPassengerCapacity: '58',
      );

      final copied = state.copyWith(isDriver: true, vehicleTypeId: 'bus');

      expect(copied.initialMomoNumber, '0788767816');
      expect(copied.initialMomoPayCode, '123456');
      expect(copied.initialBusAgencyName, 'Volcano Express');
      expect(copied.initialBusPassengerCapacity, '58');
      expect(copied.isDriver, isTrue);
      expect(copied.vehicleTypeId, 'bus');
    });
  });
}
