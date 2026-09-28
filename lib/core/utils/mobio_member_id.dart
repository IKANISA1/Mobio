const int mobioMemberIdLength = 6;

final RegExp _mobioMemberIdPattern = RegExp(r'^\d{6}$');

String mobioMemberIdDigits(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}

String? normalizeMobioMemberId(String? value) {
  if (value == null) return null;
  final digits = mobioMemberIdDigits(value);
  if (digits.length == mobioMemberIdLength) return digits;
  return null;
}

bool isValidMobioMemberId(String? value) {
  if (value == null) return false;
  return _mobioMemberIdPattern.hasMatch(value.trim());
}

String? mobioMemberIdInputError(String value) {
  final digits = mobioMemberIdDigits(value);
  if (digits.isEmpty) return 'Enter the receiver 6-digit Mobio ID.';
  if (digits.length < mobioMemberIdLength) {
    final missing = mobioMemberIdLength - digits.length;
    return 'Mobio ID needs $missing more digit${missing == 1 ? '' : 's'}.';
  }
  if (digits.length > mobioMemberIdLength) {
    return 'Mobio ID must be exactly 6 digits.';
  }
  return null;
}

String? displayMobioMemberId(String? memberId) {
  return normalizeMobioMemberId(memberId);
}
