import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/utils/money_formatting.dart';

void main() {
  test('formats whole amount digits with comma grouping', () {
    expect(formatGroupedDigits('12345'), '12,345');
    expect(formatGroupedDigits('787665'), '787,665');
    expect(formatWholeAmount(1500), '1,500');
    expect(formatCurrencyAmount('RWF', 12345), 'RWF 12,345');
  });

  test('parses grouped amount back to numeric value', () {
    expect(parseGroupedAmount('12,345'), 12345);
    expect(parseGroupedAmount('787,665'), 787665);
  });

  test('input formatter groups typed whole amounts', () {
    const formatter = GroupedWholeNumberTextInputFormatter();
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '12345'),
    );

    expect(result.text, '12,345');
    expect(result.selection.baseOffset, '12,345'.length);
  });
}
