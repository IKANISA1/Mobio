import 'package:mobi_app/core/utils/money_formatting.dart';

/// Validates fields returned by BioPay RPCs before they can become instructions
/// or operational states. Nullable metadata remains explicitly nullable.
abstract final class BioPayWireRecord {
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
  );

  static Map<String, dynamic> object(Object? value) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw const FormatException('Invalid BioPay RPC object');
    }
    return Map<String, dynamic>.from(value);
  }

  static Object? field(Map<String, dynamic> row, String key) {
    if (!row.containsKey(key)) {
      throw FormatException('Missing BioPay field: $key');
    }
    return row[key];
  }

  static String text(Map<String, dynamic> row, String key) {
    final value = field(row, key);
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid BioPay field: $key');
    }
    return value;
  }

  static String id(Map<String, dynamic> row, String key) {
    final value = text(row, key);
    if (!_uuid.hasMatch(value)) {
      throw FormatException('Invalid BioPay ID: $key');
    }
    return value;
  }

  static String? optionalText(Map<String, dynamic> row, String key) {
    final value = field(row, key);
    if (value != null && value is! String) {
      throw FormatException('Invalid BioPay field: $key');
    }
    return value as String?;
  }

  static int integer(Map<String, dynamic> row, String key) {
    final value = field(row, key);
    if (value is! int || value < 0 || value > 9007199254740991) {
      throw FormatException('Invalid BioPay integer: $key');
    }
    return value;
  }

  static bool flag(Map<String, dynamic> row, String key) {
    final value = field(row, key);
    if (value is! bool) throw FormatException('Invalid BioPay flag: $key');
    return value;
  }

  static DateTime date(Map<String, dynamic> row, String key) {
    final value = DateTime.tryParse(text(row, key));
    if (value == null) throw FormatException('Invalid BioPay date: $key');
    return value;
  }

  static DateTime? optionalDate(Map<String, dynamic> row, String key) {
    if (field(row, key) == null) return null;
    return date(row, key);
  }
}

enum BioPayRequestStatus {
  draft,
  readyToDial,
  dialerOpened,
  userMarkedPaid,
  confirmed,
  expired,
  cancelled,
  failed;

  String get wireName => switch (this) {
    BioPayRequestStatus.readyToDial => 'ready_to_dial',
    BioPayRequestStatus.dialerOpened => 'dialer_opened',
    BioPayRequestStatus.userMarkedPaid => 'user_marked_paid',
    _ => name,
  };

  static BioPayRequestStatus fromWireName(String? value) {
    return switch (value) {
      'ready_to_dial' => BioPayRequestStatus.readyToDial,
      'dialer_opened' => BioPayRequestStatus.dialerOpened,
      'user_marked_paid' => BioPayRequestStatus.userMarkedPaid,
      'confirmed' => BioPayRequestStatus.confirmed,
      'expired' => BioPayRequestStatus.expired,
      'cancelled' => BioPayRequestStatus.cancelled,
      'failed' => BioPayRequestStatus.failed,
      'draft' => BioPayRequestStatus.draft,
      _ => throw const FormatException('Invalid BioPay request status'),
    };
  }
}

enum BioPayRequestChannel {
  qr,
  nfc,
  face;

  String get wireName => name;
}

class BioPayUssdPaymentRequest {
  const BioPayUssdPaymentRequest({
    required this.id,
    required this.token,
    required this.channel,
    required this.providerCode,
    required this.payeeLabel,
    required this.amountMinor,
    required this.currency,
    required this.reference,
    required this.ussdCode,
    required this.status,
    this.expiresAt,
    this.confirmedAt,
    this.confirmationSource,
    this.createdAt,
  });

  final String id;
  final String token;
  final BioPayRequestChannel channel;
  final String providerCode;
  final String payeeLabel;
  final int amountMinor;
  final String currency;
  final String reference;
  final String ussdCode;
  final BioPayRequestStatus status;
  final DateTime? expiresAt;
  final DateTime? confirmedAt;
  final String? confirmationSource;
  final DateTime? createdAt;

  String get dialerCode => ussdCode;

  BioPayUssdPaymentRequest copyWith({
    BioPayRequestStatus? status,
    DateTime? expiresAt,
    DateTime? confirmedAt,
    String? confirmationSource,
  }) {
    return BioPayUssdPaymentRequest(
      id: id,
      token: token,
      channel: channel,
      providerCode: providerCode,
      payeeLabel: payeeLabel,
      amountMinor: amountMinor,
      currency: currency,
      reference: reference,
      ussdCode: ussdCode,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      confirmationSource: confirmationSource ?? this.confirmationSource,
      createdAt: createdAt,
    );
  }

  String get amountLabel {
    if (amountMinor <= 0) return 'Open amount';
    return formatCurrencyAmount(currency, amountMinor / 100);
  }

  factory BioPayUssdPaymentRequest.fromJson(Map<String, dynamic> json) =>
      _parse(json, resolvedProjection: false);

  factory BioPayUssdPaymentRequest.fromResolvedJson(
    Map<String, dynamic> json, {
    required String token,
  }) {
    final request = _parse(json, resolvedProjection: true);
    if (request.token != token ||
        !const {
          BioPayRequestStatus.readyToDial,
          BioPayRequestStatus.dialerOpened,
          BioPayRequestStatus.userMarkedPaid,
        }.contains(request.status)) {
      throw const FormatException('Resolved BioPay request mismatch');
    }
    return request;
  }

  static BioPayUssdPaymentRequest _parse(
    Map<String, dynamic> json, {
    required bool resolvedProjection,
  }) {
    final channelName = BioPayWireRecord.text(json, 'channel');
    final channel = BioPayRequestChannel.values.firstWhere(
      (value) => value.wireName == channelName,
      orElse: () => throw const FormatException('Invalid BioPay channel'),
    );
    final token = BioPayWireRecord.text(json, 'token');
    if (!RegExp(r'^[A-Za-z0-9_-]{24,128}$').hasMatch(token)) {
      throw const FormatException('Invalid BioPay request token');
    }
    final status = BioPayRequestStatus.fromWireName(
      BioPayWireRecord.text(json, 'status'),
    );
    final confirmedAt = resolvedProjection
        ? null
        : BioPayWireRecord.optionalDate(json, 'confirmed_at');
    final source = resolvedProjection
        ? null
        : BioPayWireRecord.optionalText(json, 'confirmation_source');
    if (status == BioPayRequestStatus.confirmed &&
        (confirmedAt == null || source == null || source.trim().isEmpty)) {
      throw const FormatException('Missing BioPay confirmation evidence');
    }
    return BioPayUssdPaymentRequest(
      id: BioPayWireRecord.id(json, 'id'),
      token: token,
      channel: channel,
      providerCode: BioPayWireRecord.text(json, 'provider_code'),
      payeeLabel: BioPayWireRecord.text(json, 'payee_label'),
      amountMinor: BioPayWireRecord.integer(json, 'amount_minor'),
      currency: BioPayWireRecord.text(json, 'currency'),
      reference: BioPayWireRecord.text(json, 'reference'),
      ussdCode: BioPayWireRecord.text(json, 'ussd_code'),
      status: status,
      expiresAt: BioPayWireRecord.date(json, 'expires_at'),
      confirmedAt: confirmedAt,
      confirmationSource: source,
      createdAt: resolvedProjection
          ? null
          : BioPayWireRecord.date(json, 'created_at'),
    );
  }

  bool hasSameInstruction(BioPayUssdPaymentRequest other) =>
      id == other.id &&
      token == other.token &&
      channel == other.channel &&
      providerCode == other.providerCode &&
      payeeLabel == other.payeeLabel &&
      amountMinor == other.amountMinor &&
      currency == other.currency &&
      reference == other.reference &&
      ussdCode == other.ussdCode;

  Map<String, dynamic> toJson() => {
    'id': id,
    'token': token,
    'channel': channel.wireName,
    'provider_code': providerCode,
    'payee_label': payeeLabel,
    'amount_minor': amountMinor,
    'currency': currency,
    'reference': reference,
    'ussd_code': ussdCode,
    'status': status.wireName,
    'expires_at': expiresAt?.toIso8601String(),
    'confirmed_at': confirmedAt?.toIso8601String(),
    'confirmation_source': confirmationSource,
    'created_at': createdAt?.toIso8601String(),
  };
}
