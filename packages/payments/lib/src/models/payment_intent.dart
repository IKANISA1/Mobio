class PaymentIntent {
  final String id;
  final String payerId;
  final String payeeId;
  final String? tripId;
  final double amount;
  final String currency;
  final String status;
  final String paymentMethod;
  final String? transactionId;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentIntent({
    required this.id,
    required this.payerId,
    required this.payeeId,
    this.tripId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.paymentMethod,
    this.transactionId,
    required this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentIntent.fromJson(Map<String, dynamic> json) {
    return PaymentIntent(
      id: json['id'] as String,
      payerId: json['payer_id'] as String,
      payeeId: json['payee_id'] as String,
      tripId: json['trip_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      status: json['status'] as String,
      paymentMethod: json['payment_method'] as String,
      transactionId: json['transaction_id'] as String?,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
