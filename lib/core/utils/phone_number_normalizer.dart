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

  static PhoneValidationResult validateForCountry({
    required String phone,
    required String countryCode,
  }) {
    final normalizedCountryCode = countryCode.trim().replaceAll(
      RegExp(r'\s+'),
      '',
    );
    final countryDigits = normalizedCountryCode.replaceAll(RegExp(r'\D'), '');
    if (countryDigits.isEmpty) {
      return const PhoneValidationResult.invalid(
        message: 'Select a country code.',
      );
    }

    final normalized = normalizeForCountry(
      phone: phone,
      countryCode: countryCode,
    );
    final digits = normalized.replaceAll(RegExp(r'\D'), '');
    if (!normalized.startsWith('+') || !digits.startsWith(countryDigits)) {
      return PhoneValidationResult.invalid(
        normalized: normalized,
        message: 'Use the selected country code.',
      );
    }

    final localDigits = digits.substring(countryDigits.length);
    final rule = _rulesByDialingCode['+$countryDigits'];
    if (rule != null) {
      return rule.validate(normalized: normalized, localDigits: localDigits);
    }

    if (localDigits.length < 4 || localDigits.length > 12) {
      return PhoneValidationResult.invalid(
        normalized: normalized,
        localDigits: localDigits,
        message: 'Enter a valid local phone number.',
      );
    }

    if (digits.length < 8 || digits.length > 15) {
      return PhoneValidationResult.invalid(
        normalized: normalized,
        localDigits: localDigits,
        message: 'Enter a valid international phone number.',
      );
    }

    return PhoneValidationResult.valid(
      normalized: normalized,
      localDigits: localDigits,
    );
  }

  static bool isValidForCountry({
    required String phone,
    required String countryCode,
  }) => validateForCountry(phone: phone, countryCode: countryCode).isValid;
}

class PhoneValidationResult {
  const PhoneValidationResult._({
    required this.isValid,
    required this.message,
    this.normalized = '',
    this.localDigits = '',
  });

  const PhoneValidationResult.valid({
    required String normalized,
    required String localDigits,
  }) : this._(
         isValid: true,
         normalized: normalized,
         localDigits: localDigits,
         message: null,
       );

  const PhoneValidationResult.invalid({
    String? normalized,
    String? localDigits,
    required String message,
  }) : this._(
         isValid: false,
         normalized: normalized ?? '',
         localDigits: localDigits ?? '',
         message: message,
       );

  final bool isValid;
  final String normalized;
  final String localDigits;
  final String? message;
}

class _CountryPhoneRule {
  const _CountryPhoneRule({
    required this.localLength,
    required this.pattern,
    required this.message,
  });

  final int localLength;
  final RegExp pattern;
  final String message;

  PhoneValidationResult validate({
    required String normalized,
    required String localDigits,
  }) {
    if (localDigits.length != localLength || !pattern.hasMatch(localDigits)) {
      return PhoneValidationResult.invalid(
        normalized: normalized,
        localDigits: localDigits,
        message: message,
      );
    }

    return PhoneValidationResult.valid(
      normalized: normalized,
      localDigits: localDigits,
    );
  }
}

final Map<String, _CountryPhoneRule> _rulesByDialingCode = {
  '+1': _CountryPhoneRule(
    localLength: 10,
    pattern: RegExp(r'^[2-9]\d{9}$'),
    message: 'Enter a 10-digit North American phone number.',
  ),
  '+44': _CountryPhoneRule(
    localLength: 10,
    pattern: RegExp(r'^7\d{9}$'),
    message: 'Enter a 10-digit UK mobile number starting with 7.',
  ),
  '+250': _CountryPhoneRule(
    localLength: 9,
    pattern: RegExp(r'^7\d{8}$'),
    message: 'Rwanda numbers must be 9 digits and start with 7.',
  ),
  '+254': _CountryPhoneRule(
    localLength: 9,
    pattern: RegExp(r'^(?:1|7)\d{8}$'),
    message: 'Kenya numbers must be 9 digits and start with 1 or 7.',
  ),
  '+255': _CountryPhoneRule(
    localLength: 9,
    pattern: RegExp(r'^(?:6|7)\d{8}$'),
    message: 'Tanzania numbers must be 9 digits and start with 6 or 7.',
  ),
  '+256': _CountryPhoneRule(
    localLength: 9,
    pattern: RegExp(r'^7\d{8}$'),
    message: 'Uganda numbers must be 9 digits and start with 7.',
  ),
  '+257': _CountryPhoneRule(
    localLength: 8,
    pattern: RegExp(r'^(?:6|7)\d{7}$'),
    message: 'Burundi numbers must be 8 digits and start with 6 or 7.',
  ),
  '+356': _CountryPhoneRule(
    localLength: 8,
    pattern: RegExp(r'^(?:7|9)\d{7}$'),
    message: 'Malta numbers must be 8 digits and start with 7 or 9.',
  ),
};
