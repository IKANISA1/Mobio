class PaymentSessionResolution {
  const PaymentSessionResolution({
    required this.sessionId,
    this.intentId,
    required this.paymentMethod,
    required this.payeeId,
    this.payeeMemberId,
    required this.payeeDisplayName,
    this.amount,
    required this.currency,
    required this.status,
    required this.expiresAt,
  });

  final String sessionId;
  final String? intentId;
  final String paymentMethod;
  final String payeeId;
  final String? payeeMemberId;
  final String payeeDisplayName;
  final double? amount;
  final String currency;
  final String status;
  final DateTime expiresAt;

  factory PaymentSessionResolution.fromJson(Map<String, dynamic> json) {
    return PaymentSessionResolution(
      sessionId: json['session_id'] as String,
      intentId: json['intent_id'] as String?,
      paymentMethod: json['payment_method'] as String,
      payeeId: json['payee_id'] as String,
      payeeMemberId: json['payee_member_id'] as String?,
      payeeDisplayName: json['payee_display_name'] as String,
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String,
      status: json['status'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}
