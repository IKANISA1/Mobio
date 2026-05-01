class Transaction {
  final String id;
  final String profileId;
  final String agentId;
  final String? transactionRef;
  final String? payerName;
  final String? payerNumber;
  final double amount;
  final String currency;
  final String network;
  final double? balanceAfter;
  final String direction; // 'IN' or 'OUT'
  final DateTime txnTimestamp;
  final String rawSms;
  final String smsHash;
  final double? parseConfidence;
  final String country;
  final DateTime? parsedAt;
  final DateTime createdAt;

  const Transaction({
    required this.id,
    required this.profileId,
    required this.agentId,
    this.transactionRef,
    this.payerName,
    this.payerNumber,
    required this.amount,
    required this.currency,
    required this.network,
    this.balanceAfter,
    required this.direction,
    required this.txnTimestamp,
    required this.rawSms,
    required this.smsHash,
    this.parseConfidence,
    required this.country,
    this.parsedAt,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      agentId: json['agent_id'] as String,
      transactionRef: json['transaction_ref'] as String?,
      payerName: json['payer_name'] as String?,
      payerNumber: json['payer_number'] as String?,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      network: json['network'] as String,
      balanceAfter: (json['balance_after'] as num?)?.toDouble(),
      direction: json['direction'] as String,
      txnTimestamp: DateTime.parse(json['txn_timestamp'] as String),
      rawSms: json['raw_sms'] as String,
      smsHash: json['sms_hash'] as String,
      parseConfidence: (json['parse_confidence'] as num?)?.toDouble(),
      country: json['country'] as String,
      parsedAt: json['parsed_at'] != null ? DateTime.parse(json['parsed_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
