import 'package:mobi_app/features/admin/domain/admin_user_protocol.dart';

enum AdminRoleRecoveryPhase {
  checking,
  ready,
  reserving,
  submitting,
  reconciling,
  sealing,
  unresolved,
  blocked,
}

/// Local recovery scope. Identity is checked against the live account separately;
/// this record is a pointer and contains no credential or authorization grant.
class AdminRoleRecoveryOwner {
  const AdminRoleRecoveryOwner({
    required this.actorId,
    required this.hostIdentity,
  });
  final String actorId;
  final String hostIdentity;
}

class AdminRoleRecoveryPointer {
  const AdminRoleRecoveryPointer({
    required this.owner,
    required this.reservationId,
    this.batchId,
    this.operationId,
  });
  final AdminRoleRecoveryOwner owner;
  final String reservationId;
  final String? batchId;
  final String? operationId;

  Map<String, Object?> toJson() => {
    'version': 1,
    'actor_id': owner.actorId,
    'host_identity': owner.hostIdentity,
    'reservation_id': reservationId,
    'batch_id': batchId,
    'operation_id': operationId,
  };

  factory AdminRoleRecoveryPointer.parse(
    Object? value, {
    required AdminRoleRecoveryOwner owner,
  }) {
    final row = AdminUserProtocol.object(value, 'role recovery pointer');
    if (AdminUserProtocol.integer(row, 'version', minimum: 1, maximum: 1) !=
            1 ||
        AdminUserProtocol.id(row, 'actor_id') != owner.actorId ||
        AdminUserProtocol.text(row, 'host_identity') != owner.hostIdentity) {
      throw const FormatException('Admin recovery pointer owner mismatch.');
    }
    final batch = AdminUserProtocol.nullableId(row, 'batch_id');
    final operation = AdminUserProtocol.nullableId(row, 'operation_id');
    if (operation != null && batch == null) {
      throw const FormatException(
        'Admin operation pointer is missing its batch.',
      );
    }
    return AdminRoleRecoveryPointer(
      owner: owner,
      reservationId: AdminUserProtocol.id(row, 'reservation_id'),
      batchId: batch,
      operationId: operation,
    );
  }

  AdminRoleRecoveryPointer withOperation(String batch, String? operation) =>
      AdminRoleRecoveryPointer(
        owner: owner,
        reservationId: reservationId,
        batchId: batch,
        operationId: operation,
      );
}
