import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/constants/app_constants.dart';

void main() {
  group('AppConstants.getDriverId', () {
    test('returns a 6-digit string', () {
      final result = AppConstants.getDriverId('test-uuid-1234');
      expect(result.length, 6);
      expect(int.tryParse(result), isNotNull);
    });

    test('returns value between 100000 and 999999', () {
      final ids = [
        'a',
        'abc',
        'test-uuid',
        '00000000-0000-0000-0000-000000000000',
        'ffffffff-ffff-ffff-ffff-ffffffffffff',
        '中文测试',
      ];
      for (final id in ids) {
        final result = int.parse(AppConstants.getDriverId(id));
        expect(result, greaterThanOrEqualTo(100000), reason: 'id=$id');
        expect(result, lessThanOrEqualTo(999999), reason: 'id=$id');
      }
    });

    test('is deterministic (same input = same output)', () {
      final a = AppConstants.getDriverId('my-uuid');
      final b = AppConstants.getDriverId('my-uuid');
      expect(a, equals(b));
    });

    test('different inputs produce different outputs (collision unlikely)', () {
      final a = AppConstants.getDriverId('uuid-1');
      final b = AppConstants.getDriverId('uuid-2');
      // Not guaranteed, but statistically near-certain for distinct inputs
      expect(a, isNot(equals(b)));
    });

    test('handles empty string', () {
      final result = AppConstants.getDriverId('');
      expect(result.length, 6);
      expect(int.tryParse(result), isNotNull);
    });
  });
}
