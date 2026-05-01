enum ExternalPaymentStatus {
  instruction,
  pending,
  manuallyConfirmed,
  paid,
  disputed,
  refunded,
  cancelled,
}

class UssdPaymentInstruction {
  const UssdPaymentInstruction({
    required this.ussdString,
    this.payeeDisplayName,
    this.amount,
    this.currency,
    this.reference,
    this.status = ExternalPaymentStatus.instruction,
  });

  final String ussdString;
  final String? payeeDisplayName;
  final double? amount;
  final String? currency;
  final String? reference;
  final ExternalPaymentStatus status;

  String get telUri => Uri(scheme: 'tel', path: ussdString).toString();

  bool get isDialable => ussdString.startsWith('*') && ussdString.endsWith('#');

  UssdPaymentInstruction copyWith({
    String? ussdString,
    String? payeeDisplayName,
    double? amount,
    String? currency,
    String? reference,
    ExternalPaymentStatus? status,
  }) {
    return UssdPaymentInstruction(
      ussdString: ussdString ?? this.ussdString,
      payeeDisplayName: payeeDisplayName ?? this.payeeDisplayName,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      reference: reference ?? this.reference,
      status: status ?? this.status,
    );
  }

  static String normalizeUssd(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), '');
  }
}
