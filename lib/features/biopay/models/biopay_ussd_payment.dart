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
      _ => BioPayRequestStatus.draft,
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
    final value = amountMinor / 100;
    final compact = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '$currency $compact';
  }

  factory BioPayUssdPaymentRequest.fromJson(Map<String, dynamic> json) {
    final channelValue = json['channel'] as String? ?? 'qr';
    return BioPayUssdPaymentRequest(
      id: json['id'] as String,
      token: json['token'] as String? ?? json['id'] as String,
      channel: BioPayRequestChannel.values.firstWhere(
        (value) => value.wireName == channelValue,
        orElse: () => BioPayRequestChannel.qr,
      ),
      providerCode: json['provider_code'] as String? ?? 'mtn_rw',
      payeeLabel: json['payee_label'] as String? ?? 'BioPay merchant',
      amountMinor: (json['amount_minor'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'RWF',
      reference: json['reference'] as String? ?? '',
      ussdCode: json['ussd_code'] as String? ?? '',
      status: BioPayRequestStatus.fromWireName(json['status'] as String?),
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
      confirmedAt: DateTime.tryParse(json['confirmed_at'] as String? ?? ''),
      confirmationSource: json['confirmation_source'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

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
