import 'package:mobi_app/features/biopay/models/biopay_handle.dart';
import 'package:mobi_app/models/country.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for fetching countries from Supabase `countries` table.
///
/// Caches the result in memory after first fetch. Falls back to
/// hardcoded list if Supabase is unreachable.
class CountryService {
  // Singleton
  static final CountryService _instance = CountryService._();
  factory CountryService() => _instance;
  CountryService._();

  List<Country>? _cached;

  /// Get all active countries, sorted by sort_order.
  Future<List<Country>> getCountries() async {
    if (_cached != null) return _cached!;

    try {
      final response = await Supabase.instance.client
          .from('countries')
          .select()
          .eq('is_active', true)
          .order('sort_order');

      final rows = response as List<dynamic>;
      _cached = rows
          .map((r) => Country.fromJson(r as Map<String, dynamic>))
          .toList();
      return _cached!;
    } on Object catch (_) {
      // Offline fallback
      _cached = Country.fallbackCountries;
      return _cached!;
    }
  }

  Future<void> warmCache() async {
    await getCountries();
  }

  /// Get only African countries (those with MoMo support).
  Future<List<Country>> getAfricanCountries() async {
    final countries = await getCountries();
    return countries.where((c) => c.hasMoMo).toList();
  }

  /// Find country by ISO code (e.g. 'RW').
  Future<Country?> findById(String id) async {
    final countries = await getCountries();
    final matches = countries.where((c) => c.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  /// Find country by dialing code (e.g. '+254').
  Future<Country> findByDialingCode(String code) async {
    final countries = await getCountries();
    return countries.firstWhere(
      (c) => c.dialingCode == code,
      orElse: () => countries.firstWhere(
        (c) => c.dialingCode == '+250', // Rwanda default
        orElse: () => countries.first,
      ),
    );
  }

  Country? findByDialingCodeSync(String code) {
    if (_cached == null) return null;
    final matches = _cached!.where((c) => c.dialingCode == code);
    return matches.isNotEmpty ? matches.first : null;
  }

  /// Get currency for a dialing code.
  Future<String> currencyForCode(String dialingCode) async {
    final country = await findByDialingCode(dialingCode);
    return country.currency;
  }

  /// Synchronous currency lookup (uses cache, falls back to RWF).
  String currencyForCodeSync(String dialingCode) {
    if (_cached == null) return 'RWF';
    final match = _cached!.where((c) => c.dialingCode == dialingCode);
    return match.isNotEmpty ? match.first.currency : 'RWF';
  }

  /// Synchronous Momo Brand lookup (uses cache, falls back to MoMo).
  String momoBrandForCodeSync(String dialingCode) {
    if (_cached == null) return 'MoMo';
    final match = _cached!.where((c) => c.dialingCode == dialingCode);
    return match.isNotEmpty ? match.first.momoBrand : 'MoMo';
  }

  /// Build a USSD string for sending money to a phone number.
  /// Returns empty string if the country has no MoMo support.
  String buildUssdForNumber(
    String dialingCode,
    String phone, [
    String? amount,
  ]) {
    if (_cached == null) return '';
    final match = _cached!.where((c) => c.dialingCode == dialingCode);
    if (match.isEmpty) return '';
    return match.first.buildUssdForNumber(phone, amount);
  }

  /// Build a USSD string for a code-based transaction.
  /// Returns empty string if the country has no MoMo support.
  String buildUssdForCode(String dialingCode, String code, [String? amount]) {
    if (_cached == null) return '';
    final match = _cached!.where((c) => c.dialingCode == dialingCode);
    if (match.isEmpty) return '';
    return match.first.buildUssdForCode(code, amount);
  }

  Future<String?> buildBiopayUssd({
    required String dialingCode,
    required BiopayHandleType handleType,
    required String handleValue,
    String? amount,
  }) async {
    final countries = await getCountries();
    final matches = countries.where((c) => c.dialingCode == dialingCode);
    if (matches.isEmpty) return null;

    final country = matches.first;
    if (!country.hasMoMo) return null;

    final normalizedValue = handleType == BiopayHandleType.number
        ? normalizeLocalPhoneDisplay(
            dialingCode: dialingCode,
            rawValue: handleValue,
            country: country,
          )
        : normalizeCodeValue(handleValue);
    if (normalizedValue.isEmpty) return null;

    return handleType == BiopayHandleType.number
        ? country.buildUssdForNumber(normalizedValue, amount)
        : country.buildUssdForCode(normalizedValue, amount);
  }

  Future<BiopayHandle?> parseBiopayUssd(String? ussdString) async {
    final candidate = _compactUssd(ussdString);
    if (candidate.isEmpty) return null;

    final countries = await getAfricanCountries();
    for (final country in countries) {
      final phoneTokens = _matchTokens(candidate, country.ussdNumberFormat);
      if (phoneTokens != null && phoneTokens.containsKey('PHONE')) {
        final rawPhone = phoneTokens['PHONE']!;
        return BiopayHandle(
          type: BiopayHandleType.number,
          value: normalizeLocalPhoneDisplay(
            dialingCode: country.dialingCode,
            rawValue: rawPhone,
            country: country,
          ),
          countryCode: country.dialingCode,
          countryId: country.id,
          amount: phoneTokens['AMOUNT'],
          momoBrand: country.momoBrand,
        );
      }

      final codeTokens = _matchTokens(candidate, country.ussdCodeFormat);
      if (codeTokens != null && codeTokens.containsKey('CODE')) {
        return BiopayHandle(
          type: BiopayHandleType.code,
          value: normalizeCodeValue(codeTokens['CODE']!),
          countryCode: country.dialingCode,
          countryId: country.id,
          amount: codeTokens['AMOUNT'],
          momoBrand: country.momoBrand,
        );
      }
    }

    return null;
  }

  String normalizeLocalPhoneDisplay({
    required String dialingCode,
    required String rawValue,
    Country? country,
  }) {
    final digits = rawValue.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';

    final resolvedCountry = country ?? findByDialingCodeSync(dialingCode);
    final localPlaceholder = resolvedCountry?.phonePlaceholder.replaceAll(
      RegExp(r'\D'),
      '',
    );
    final localDigitCount = localPlaceholder?.length ?? 9;
    final dialingDigits = dialingCode.replaceAll(RegExp(r'\D'), '');

    var localDigits = digits;
    if (localDigits.startsWith(dialingDigits) &&
        localDigits.length > dialingDigits.length) {
      localDigits = localDigits.substring(dialingDigits.length);
    }

    if (!localDigits.startsWith('0') && localDigits.length == localDigitCount) {
      localDigits = '0$localDigits';
    }

    return localDigits;
  }

  String normalizeCodeValue(String rawValue) {
    return rawValue.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }

  String _compactUssd(String? ussdString) {
    if (ussdString == null) return '';
    var value = ussdString.trim().replaceAll(RegExp(r'\s+'), '');
    if (value.toLowerCase().startsWith('tel:')) {
      value = value.substring(4);
    }
    return value.replaceAll(RegExp(r'%23$', caseSensitive: false), '#');
  }

  Map<String, String>? _matchTokens(String candidate, String format) {
    if (format.isEmpty) return null;

    // We want to handle optional *{AMOUNT} at the end before #.
    // Replace `\*\*\{AMOUNT\}` with `(?:\*([0-9]+))?`
    var patternStr = RegExp.escape(format);

    // Identify tokens in order
    final tokenRegex = RegExp(r'\{([A-Z]+)\}');
    final tokens = <String>[];

    // Extract tokens from the unescaped format
    for (final m in tokenRegex.allMatches(format)) {
      tokens.add(m.group(1)!);
    }

    if (tokens.isEmpty) return null;

    // Build the regex pattern
    // If the format has `\*\*\{AMOUNT\}` (which is `*{AMOUNT}` escaped)
    patternStr = patternStr.replaceAll(
      RegExp.escape(r'*{AMOUNT}'),
      r'(?:\*([0-9]+))?',
    );

    // For other tokens like {PHONE} or {CODE}
    patternStr = patternStr.replaceAll(RegExp.escape(r'{PHONE}'), r'([^#*]+)');
    patternStr = patternStr.replaceAll(RegExp.escape(r'{CODE}'), r'([^#*]+)');

    final regex = RegExp('^$patternStr\$');
    final match = regex.firstMatch(candidate);

    if (match == null) return null;

    final result = <String, String>{};
    for (int i = 0; i < tokens.length; i++) {
      final val = match.group(i + 1);
      if (val != null && val.isNotEmpty) {
        result[tokens[i]] = val;
      }
    }

    return result;
  }

  /// Clear cache (e.g. after admin updates countries).
  void clearCache() => _cached = null;
}
