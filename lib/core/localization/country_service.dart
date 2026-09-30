import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_shared_types/models/country.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for fetching countries from Supabase `countries` table.
///
/// Caches the result in memory after first fetch. Falls back to
/// hardcoded list if Supabase is unreachable.
class CountryService {
  final SupabaseClient _supabase;

  CountryService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  List<Country>? _cached;

  /// Get all active countries, sorted by sort_order.
  Future<List<Country>> getCountries() async {
    if (_cached != null) return _cached!;

    try {
      final response = await RequestDeadline.read(
        _supabase
            .from('countries')
            .select()
            .eq('is_active', true)
            .order('sort_order'),
      );

      final rows = response as List<dynamic>;
      final countries = rows
          .map((r) => Country.fromJson(r as Map<String, dynamic>))
          .toList();
      _cached = countries.isEmpty ? Country.fallbackCountries : countries;
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
    if (countries.isEmpty) {
      return Country.fallbackCountries.first;
    }

    return countries.firstWhere(
      (c) => c.dialingCode == code,
      orElse: () => countries.firstWhere(
        (c) => c.dialingCode == '+250', // Rwanda default
        orElse: () => countries.first,
      ),
    );
  }

  Country? findByDialingCodeSync(String code) {
    final cached = _cached;
    if (cached == null || cached.isEmpty) return null;
    final matches = cached.where((c) => c.dialingCode == code);
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

  /// Clear cache (e.g. after admin updates countries).
  void clearCache() => _cached = null;
}
