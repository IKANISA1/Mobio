import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile keeps authenticated WhatsApp number read-only', () {
    final contactSection = File(
      'lib/features/profile/presentation/widgets/profile_contact_section.dart',
    ).readAsStringSync();
    final editProfileScreen = File(
      'lib/features/profile/presentation/edit_profile_screen.dart',
    ).readAsStringSync();
    final editProfileProvider = File(
      'lib/features/profile/application/edit_profile_provider.dart',
    ).readAsStringSync();
    final profileService = File(
      'lib/features/profile/data/profile_service.dart',
    ).readAsStringSync();

    expect(contactSection, contains('Authenticated WhatsApp number'));
    expect(contactSection, contains('TextField('));
    expect(contactSection, contains('readOnly: true'));
    expect(contactSection, contains('canRequestFocus: false'));
    expect(contactSection, contains('enableInteractiveSelection: false'));
    expect(contactSection, contains('showCursor: false'));
    expect(contactSection, contains('TextInputType.none'));
    expect(contactSection, isNot(contains('TextFormField(')));
    expect(contactSection, isNot(contains('onCountryTap')));

    expect(editProfileScreen, contains('ProfileContactSection'));
    expect(editProfileScreen, isNot(contains('_showCountryPicker')));
    expect(editProfileScreen, isNot(contains('onCountryTap:')));
    expect(
      editProfileScreen,
      isNot(contains('whatsApp: _whatsAppController.text')),
    );

    expect(editProfileProvider, isNot(contains('required String whatsApp')));
    expect(editProfileProvider, contains('s.initialWhatsApp'));
    expect(editProfileProvider, isNot(contains('whatsapp: whatsApp.trim()')));
    expect(editProfileProvider, isNot(contains('countryCode: s.countryCode')));

    final saveSettingsSignature = RegExp(
      r'Future<void> saveProfileSettings\(\{[\s\S]*?\}\) async',
    ).firstMatch(profileService)?.group(0);
    expect(saveSettingsSignature, isNotNull);
    expect(saveSettingsSignature, isNot(contains('required String whatsapp')));
    expect(
      saveSettingsSignature,
      isNot(contains('required String countryCode')),
    );
    expect(saveSettingsSignature, isNot(contains('whatsapp: whatsapp')));
    expect(saveSettingsSignature, isNot(contains('countryCode: countryCode')));
  });
}
