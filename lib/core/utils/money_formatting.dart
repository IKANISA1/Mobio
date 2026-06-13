import 'package:flutter/services.dart';

String formatGroupedDigits(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  final normalized = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  final buffer = StringBuffer();
  for (var i = 0; i < normalized.length; i += 1) {
    final fromEnd = normalized.length - i;
    buffer.write(normalized[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

String formatWholeAmount(num amount) {
  return formatGroupedDigits(amount.round().toString());
}

String formatFlexibleAmount(num amount) {
  final value = amount.toDouble();
  if (value == value.roundToDouble()) {
    return formatWholeAmount(value);
  }
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  return '${formatGroupedDigits(parts.first)}.${parts.last}';
}

String formatCurrencyAmount(String currency, num amount) {
  return '$currency ${formatFlexibleAmount(amount)}';
}

double parseGroupedAmount(String value) {
  final normalized = value.replaceAll(',', '').trim();
  return double.tryParse(normalized) ?? 0;
}

class GroupedWholeNumberTextInputFormatter extends TextInputFormatter {
  const GroupedWholeNumberTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = formatGroupedDigits(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
