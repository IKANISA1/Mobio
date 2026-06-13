class PhoneNumberNormalizer {
  const PhoneNumberNormalizer._();

  static String normalizeForCountry({
    required String phone,
    required String countryCode,
  }) {
    final normalizedCountryCode = countryCode.trim().replaceAll(
      RegExp(r'\s+'),
      '',
    );
    final countryDigits = normalizedCountryCode.replaceAll(RegExp(r'\D'), '');
    if (countryDigits.isEmpty) {
      return '+${phone.replaceAll(RegExp(r'\D'), '')}';
    }

    final trimmedPhone = phone.trim();
    if (trimmedPhone.startsWith('+')) {
      return '+${trimmedPhone.replaceAll(RegExp(r'\D'), '')}';
    }
    if (trimmedPhone.startsWith('00')) {
      return '+${trimmedPhone.substring(2).replaceAll(RegExp(r'\D'), '')}';
    }

    final rawDigits = trimmedPhone.replaceAll(RegExp(r'\D'), '');
    final nationalDigits =
        (rawDigits.startsWith(countryDigits)
                ? rawDigits.substring(countryDigits.length)
                : rawDigits)
            .replaceFirst(RegExp(r'^0+'), '');

    return '+$countryDigits$nationalDigits';
  }

  static bool isValidCanonical(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return phone.startsWith('+') && digits.length >= 8 && digits.length <= 15;
  }
}
