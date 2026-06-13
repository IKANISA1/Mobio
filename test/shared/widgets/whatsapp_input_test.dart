import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/country_service.dart';
import 'package:mobi_app/core/theme/app_theme.dart';
import 'package:mobi_app/models/country.dart';
import 'package:mobi_app/shared/widgets/whatsapp_input.dart';

void main() {
  testWidgets('WhatsApp input has native phone field and on-screen keypad', (
    tester,
  ) async {
    var phone = '';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          countryServiceProvider.overrideWithValue(_TestCountryService()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: WhatsAppInput(
              value: phone,
              onChanged: (value) => phone = value,
              countryCode: '+250',
              onCountryCodeChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final phoneField = tester.widget<TextField>(find.byType(TextField).first);
    expect(phoneField.keyboardType, TextInputType.phone);
    expect(phoneField.autofillHints, contains(AutofillHints.telephoneNumber));

    await tester.tap(find.text('7'));
    await tester.tap(find.text('8').first);
    await tester.tap(find.text('8').first);
    await tester.pump();

    expect(phone, '788');
    expect(find.text('788'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();

    expect(phone, '78');
    expect(find.text('78'), findsOneWidget);
  });
}

class _TestCountryService implements CountryService {
  static final _countries = Country.fallbackCountries
      .where((country) => country.id == 'RW')
      .toList();

  @override
  Future<List<Country>> getCountries() async => _countries;

  @override
  Future<List<Country>> getAfricanCountries() async => _countries;

  @override
  Future<Country?> findById(String id) async =>
      _countries.where((country) => country.id == id).firstOrNull;

  @override
  Future<Country> findByDialingCode(String code) async =>
      findByDialingCodeSync(code) ?? _countries.first;

  @override
  Country? findByDialingCodeSync(String code) =>
      _countries.where((country) => country.dialingCode == code).firstOrNull;

  @override
  Future<String> currencyForCode(String dialingCode) async =>
      currencyForCodeSync(dialingCode);

  @override
  String currencyForCodeSync(String dialingCode) =>
      findByDialingCodeSync(dialingCode)?.currency ?? 'RWF';

  @override
  String momoBrandForCodeSync(String dialingCode) =>
      findByDialingCodeSync(dialingCode)?.momoBrand ?? 'MoMo';

  @override
  String buildUssdForNumber(
    String dialingCode,
    String phone, [
    String? amount,
  ]) =>
      findByDialingCodeSync(dialingCode)?.buildUssdForNumber(phone, amount) ??
      '';

  @override
  String buildUssdForCode(String dialingCode, String code, [String? amount]) =>
      findByDialingCodeSync(dialingCode)?.buildUssdForCode(code, amount) ?? '';

  @override
  String normalizeLocalPhoneDisplay({
    required String dialingCode,
    required String rawValue,
    Country? country,
  }) => rawValue.replaceAll(RegExp(r'[^0-9]'), '');

  @override
  Future<void> warmCache() async {}

  @override
  void clearCache() {}
}
