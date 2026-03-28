/// Country model — maps to `public.countries` Supabase table.
///
/// Includes USSD/MoMo data for African mobile money markets.
/// The `ussdNumberFormat` and `ussdCodeFormat` use `{PHONE}` and `{CODE}`
/// placeholders that should be replaced at runtime.
class Country {
  final String id; // ISO 3166-1 alpha-2 ('KE', 'RW')
  final String name; // 'Kenya'
  final String flag; // '🇰🇪'
  final String dialingCode; // '+254'
  final String currency; // 'KES'
  final String currencyName; // 'Kenyan Shilling'
  final String phonePlaceholder; // '712 345 678'
  final String telecomProvider; // 'Safaricom'
  final String momoBrand; // 'M-Pesa'
  final String ussdNumberFormat; // '*334*1*{PHONE}#'
  final String ussdCodeFormat; // '*334*0*{CODE}#'
  final bool isActive;
  final int sortOrder;

  const Country({
    required this.id,
    required this.name,
    this.flag = '',
    required this.dialingCode,
    this.currency = 'RWF',
    this.currencyName = '',
    this.phonePlaceholder = '780 000 000',
    this.telecomProvider = '',
    this.momoBrand = '',
    this.ussdNumberFormat = '',
    this.ussdCodeFormat = '',
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      flag: json['flag'] as String? ?? '',
      dialingCode: json['dialing_code'] as String? ?? '+250',
      currency: json['currency'] as String? ?? 'RWF',
      currencyName: json['currency_name'] as String? ?? '',
      phonePlaceholder: json['phone_placeholder'] as String? ?? '780 000 000',
      telecomProvider: json['telecom_provider'] as String? ?? '',
      momoBrand: json['momo_brand'] as String? ?? '',
      ussdNumberFormat: json['ussd_number_format'] as String? ?? '',
      ussdCodeFormat: json['ussd_code_format'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'flag': flag,
    'dialing_code': dialingCode,
    'currency': currency,
    'currency_name': currencyName,
    'phone_placeholder': phonePlaceholder,
    'telecom_provider': telecomProvider,
    'momo_brand': momoBrand,
    'ussd_number_format': ussdNumberFormat,
    'ussd_code_format': ussdCodeFormat,
    'is_active': isActive,
    'sort_order': sortOrder,
  };

  /// Whether this country has mobile money USSD support.
  bool get hasMoMo => ussdNumberFormat.isNotEmpty;

  /// Build a USSD string for sending money to a phone number.
  /// Replaces `{PHONE}` with the actual phone number.
  String buildUssdForNumber(String phone) {
    if (ussdNumberFormat.isEmpty) return '';
    return ussdNumberFormat.replaceAll('{PHONE}', phone);
  }

  /// Build a USSD string for a code-based transaction (merchant/agent).
  /// Replaces `{CODE}` with the actual merchant/agent code.
  String buildUssdForCode(String code) {
    if (ussdCodeFormat.isEmpty) return '';
    return ussdCodeFormat.replaceAll('{CODE}', code);
  }

  /// Offline-only fallback. The definitive list of supported countries is
  /// managed in the Supabase `countries` table and fetched at runtime by
  /// [CountryService]. This static list is used only when the network is
  /// unreachable (e.g. first launch with no connectivity).
  static const List<Country> fallbackCountries = [
    Country(
      id: 'KE',
      name: 'Kenya',
      flag: '🇰🇪',
      dialingCode: '+254',
      currency: 'KES',
      currencyName: 'Kenyan Shilling',
      phonePlaceholder: '712 345 678',
      telecomProvider: 'Safaricom',
      momoBrand: 'M-Pesa',
      ussdNumberFormat: '*334*1*{PHONE}#',
      ussdCodeFormat: '*334*0*{CODE}#',
      sortOrder: 1,
    ),
    Country(
      id: 'UG',
      name: 'Uganda',
      flag: '🇺🇬',
      dialingCode: '+256',
      currency: 'UGX',
      currencyName: 'Ugandan Shilling',
      phonePlaceholder: '770 000 000',
      telecomProvider: 'MTN Uganda',
      momoBrand: 'MTN MoMo',
      ussdNumberFormat: '*165*1*{PHONE}#',
      ussdCodeFormat: '*165*5*{CODE}#',
      sortOrder: 2,
    ),
    Country(
      id: 'TZ',
      name: 'Tanzania',
      flag: '🇹🇿',
      dialingCode: '+255',
      currency: 'TZS',
      currencyName: 'Tanzanian Shilling',
      phonePlaceholder: '700 000 000',
      telecomProvider: 'Vodacom Tanzania',
      momoBrand: 'M-Pesa',
      ussdNumberFormat: '*150*00*1*{PHONE}#',
      ussdCodeFormat: '*150*00*5*{CODE}#',
      sortOrder: 3,
    ),
    Country(
      id: 'RW',
      name: 'Rwanda',
      flag: '🇷🇼',
      dialingCode: '+250',
      currency: 'RWF',
      currencyName: 'Rwandan Franc',
      phonePlaceholder: '788 767 816',
      telecomProvider: 'MTN Rwanda',
      momoBrand: 'MTN MoMo',
      ussdNumberFormat: '*182*1*1*{PHONE}#',
      ussdCodeFormat: '*182*8*1*{CODE}#',
      sortOrder: 4,
    ),
    Country(
      id: 'GH',
      name: 'Ghana',
      flag: '🇬🇭',
      dialingCode: '+233',
      currency: 'GHS',
      currencyName: 'Ghanaian Cedi',
      phonePlaceholder: '240 000 000',
      telecomProvider: 'MTN Ghana',
      momoBrand: 'MTN MoMo',
      ussdNumberFormat: '*170*1*{PHONE}#',
      ussdCodeFormat: '*170*2*{CODE}#',
      sortOrder: 6,
    ),
    Country(
      id: 'NG',
      name: 'Nigeria',
      flag: '🇳🇬',
      dialingCode: '+234',
      currency: 'NGN',
      currencyName: 'Nigerian Naira',
      phonePlaceholder: '703 000 000',
      telecomProvider: 'MTN Nigeria',
      momoBrand: 'MoMo PSB',
      ussdNumberFormat: '*671*1*{PHONE}#',
      ussdCodeFormat: '*671*5*{CODE}#',
      sortOrder: 7,
    ),
  ];
}
