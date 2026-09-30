import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/profile/domain/profile_wire_record.dart';

void main() {
  const id = '00000000-0000-4000-8000-000000000001';
  Map<String, dynamic> valid() => {
    'id': id,
    'member_id': '482913',
    'role': 'passenger',
    'is_driver': false,
  };

  test('valid profile preserves a six-digit member ID', () {
    final profile = ProfileWireRecord.parse(valid(), expectedId: id);
    expect(profile.memberId, '482913');
  });

  test('invalid or mismatched identity is rejected', () {
    expect(
      () => ProfileWireRecord.parse(valid(), expectedId: 'other'),
      throwsFormatException,
    );
    expect(
      () => ProfileWireRecord.parse(valid()..['member_id'] = '48291'),
      throwsFormatException,
    );
  });

  test('missing role and driver status cannot silently default', () {
    expect(
      () => ProfileWireRecord.parse(valid()..remove('role')),
      throwsFormatException,
    );
    expect(
      () => ProfileWireRecord.parse(valid()..remove('is_driver')),
      throwsFormatException,
    );
  });
}
