import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/utils/mobio_member_id.dart';

void main() {
  group('Mobio member ID validation', () {
    test('accepts exactly six digits', () {
      expect(isValidMobioMemberId('482913'), isTrue);
      expect(normalizeMobioMemberId('482913'), '482913');
    });

    test('sanitizes pasted separators before normalization', () {
      expect(mobioMemberIdDigits('482 913'), '482913');
      expect(normalizeMobioMemberId('482-913'), '482913');
    });

    test('rejects short and long values with helpful errors', () {
      expect(normalizeMobioMemberId('48291'), isNull);
      expect(mobioMemberIdInputError('48291'), 'Mobio ID needs 1 more digit.');
      expect(normalizeMobioMemberId('4829137'), isNull);
      expect(
        mobioMemberIdInputError('4829137'),
        'Mobio ID must be exactly 6 digits.',
      );
    });

    test('displays only authoritative six-digit member IDs', () {
      expect(displayMobioMemberId('482913'), '482913');
      expect(displayMobioMemberId('M00042'), isNull);
      expect(displayMobioMemberId(null), isNull);
    });
  });
}
