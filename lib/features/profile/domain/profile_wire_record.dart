import 'package:mobi_shared_types/models/profile.dart';

/// Validates identity and role fields before legacy display defaults apply.
abstract final class ProfileWireRecord {
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
  );
  static final _memberId = RegExp(r'^\d{6}$');
  static const _roles = {'passenger', 'driver', 'admin'};

  static Profile parse(Map<String, dynamic> row, {String? expectedId}) {
    final id = row['id'];
    final memberId = row['member_id'];
    final role = row['role'];
    final isDriver = row['is_driver'];
    if (id is! String ||
        !_uuid.hasMatch(id) ||
        (expectedId != null && id != expectedId) ||
        (memberId != null &&
            (memberId is! String || !_memberId.hasMatch(memberId))) ||
        role is! String ||
        !_roles.contains(role) ||
        isDriver is! bool) {
      throw const FormatException('Invalid profile response');
    }
    return Profile.fromJson(row);
  }
}
