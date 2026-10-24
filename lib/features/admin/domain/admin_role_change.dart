import 'package:mobi_app/features/admin/domain/admin_user_protocol.dart';

enum AdminRoleSkipReason { self, sameRole }

enum AdminRoleOperationStatus {
  prepared,
  confirmed,
  knownRejected,
  skipped,
  notStarted,
}

enum AdminRoleOutcomeStatus {
  confirmed,
  knownRejected,
  unknown,
  notStarted,
  skipped,
  submitting,
}

enum AdminRoleReservationState { reserved, sealed, sealedBeforeReserve, absent }

enum AdminRoleBatchState { open, sealed }

class AdminRoleReviewEntry {
  const AdminRoleReviewEntry({
    required this.targetId,
    required this.displayLabel,
    required this.memberId,
    required this.expectedRole,
    required this.expectedRevision,
    required this.expectedIsDriver,
    required this.requestedRole,
    required this.requestedIsDriver,
    this.skipReason,
  });
  final String targetId;
  final String displayLabel;
  final String? memberId;
  final String expectedRole;
  final int expectedRevision;
  final bool expectedIsDriver;
  final String requestedRole;
  final bool requestedIsDriver;
  final AdminRoleSkipReason? skipReason;

  Map<String, Object> toReserveTarget() => {
    'target_id': targetId,
    'expected_role': expectedRole,
    'expected_revision': expectedRevision,
    'requested_role': requestedRole,
  };

  bool sameReviewedTuple(AdminRoleReviewEntry other) =>
      targetId == other.targetId &&
      displayLabel == other.displayLabel &&
      memberId == other.memberId &&
      expectedRole == other.expectedRole &&
      expectedRevision == other.expectedRevision &&
      expectedIsDriver == other.expectedIsDriver &&
      requestedRole == other.requestedRole &&
      requestedIsDriver == other.requestedIsDriver &&
      skipReason == other.skipReason;
}

class AdminRoleReview {
  AdminRoleReview({
    required this.reviewId,
    required this.reservationId,
    required this.actorId,
    required this.sessionId,
    required this.snapshotId,
    required this.requestedRole,
    required List<AdminRoleReviewEntry> entries,
  }) : entries = List.unmodifiable(entries);
  final String reviewId;
  final String reservationId;
  final String actorId;
  final String sessionId;
  final String snapshotId;
  final String requestedRole;
  final List<AdminRoleReviewEntry> entries;
  int get eligibleCount =>
      entries.where((entry) => entry.skipReason == null).length;
  int get skippedCount => entries.length - eligibleCount;
}

class AdminRoleReceipt {
  const AdminRoleReceipt({
    required this.actorId,
    required this.sessionId,
    required this.batchId,
    required this.operationId,
    required this.targetId,
    required this.beforeRole,
    required this.afterRole,
    required this.beforeRevision,
    required this.afterRevision,
    required this.beforeIsDriver,
    required this.afterIsDriver,
    required this.auditId,
    required this.committedAt,
  });
  final String actorId;
  final String sessionId;
  final String batchId;
  final String operationId;
  final String targetId;
  final String beforeRole;
  final String afterRole;
  final int beforeRevision;
  final int afterRevision;
  final bool beforeIsDriver;
  final bool afterIsDriver;
  final String auditId;
  final DateTime committedAt;

  bool sameEvidence(AdminRoleReceipt other) =>
      actorId == other.actorId &&
      sessionId == other.sessionId &&
      batchId == other.batchId &&
      operationId == other.operationId &&
      targetId == other.targetId &&
      beforeRole == other.beforeRole &&
      afterRole == other.afterRole &&
      beforeRevision == other.beforeRevision &&
      afterRevision == other.afterRevision &&
      beforeIsDriver == other.beforeIsDriver &&
      afterIsDriver == other.afterIsDriver &&
      auditId == other.auditId &&
      committedAt == other.committedAt;
}

class AdminRoleOperation {
  const AdminRoleOperation({
    required this.operationId,
    required this.ordinal,
    required this.entry,
    required this.status,
    required this.rejectionCode,
    required this.decidedAt,
    required this.receipt,
  });
  final String operationId;
  final int ordinal;
  final AdminRoleReviewEntry entry;
  final AdminRoleOperationStatus status;
  final String? rejectionCode;
  final DateTime? decidedAt;
  final AdminRoleReceipt? receipt;
}

class AdminRoleBatch {
  const AdminRoleBatch({
    required this.batchId,
    required this.reservationId,
    required this.snapshotId,
    required this.originSessionId,
    required this.reservedAt,
    required this.executeExpiresAt,
    required this.inputSha256,
    required this.state,
    required this.sealedAt,
  });
  final String batchId;
  final String reservationId;
  final String snapshotId;
  final String originSessionId;
  final DateTime reservedAt;
  final DateTime executeExpiresAt;
  final String inputSha256;
  final AdminRoleBatchState state;
  final DateTime? sealedAt;

  bool sameImmutableTuple(AdminRoleBatch other) =>
      batchId == other.batchId &&
      reservationId == other.reservationId &&
      snapshotId == other.snapshotId &&
      originSessionId == other.originSessionId &&
      reservedAt == other.reservedAt &&
      executeExpiresAt == other.executeExpiresAt &&
      inputSha256 == other.inputSha256;
}

class AdminRoleBatchEnvelope {
  AdminRoleBatchEnvelope({
    required this.actorId,
    required this.sessionId,
    required this.serverNow,
    required this.reservationId,
    required this.reservationState,
    required this.batch,
    required List<AdminRoleOperation> operations,
  }) : operations = List.unmodifiable(operations);
  final String actorId;

  /// Current caller session; each stored receipt separately binds origin SID.
  final String sessionId;
  final DateTime serverNow;
  final String? reservationId;
  final AdminRoleReservationState reservationState;
  final AdminRoleBatch? batch;
  final List<AdminRoleOperation> operations;
  bool get isSealed =>
      reservationState == AdminRoleReservationState.sealed ||
      reservationState == AdminRoleReservationState.sealedBeforeReserve;

  /// Current caller SID may change during recovery; stored provenance and
  /// every already-decided recipient outcome remain immutable.
  bool continues(AdminRoleBatchEnvelope previous) {
    if (actorId != previous.actorId ||
        reservationId != previous.reservationId ||
        batch == null ||
        previous.batch == null ||
        !batch!.sameImmutableTuple(previous.batch!) ||
        operations.length != previous.operations.length ||
        (previous.batch!.state == AdminRoleBatchState.sealed &&
            (batch!.state != AdminRoleBatchState.sealed ||
                batch!.sealedAt != previous.batch!.sealedAt))) {
      return false;
    }
    for (var index = 0; index < operations.length; index++) {
      final before = previous.operations[index];
      final after = operations[index];
      if (before.operationId != after.operationId ||
          before.ordinal != after.ordinal ||
          !before.entry.sameReviewedTuple(after.entry)) {
        return false;
      }
      if (before.status != AdminRoleOperationStatus.prepared &&
          (before.status != after.status ||
              before.rejectionCode != after.rejectionCode ||
              before.decidedAt != after.decidedAt ||
              (before.receipt == null
                  ? after.receipt != null
                  : after.receipt == null ||
                        !before.receipt!.sameEvidence(after.receipt!)))) {
        return false;
      }
    }
    return true;
  }

  factory AdminRoleBatchEnvelope.parse(
    Object? value, {
    required String actorId,
    required String sessionId,
    String? expectedReservationId,
    String? expectedBatchId,
    AdminRoleReview? review,
  }) {
    final row = AdminUserProtocol.object(value, 'role batch envelope');
    AdminUserProtocol.header(row, actorId: actorId, sessionId: sessionId);
    final now = AdminUserProtocol.date(row, 'server_now');
    final reservation = AdminUserProtocol.nullableId(row, 'reservation_id');
    final state = switch (AdminUserProtocol.choice(row, 'reservation_state', {
      'reserved',
      'sealed',
      'sealed_before_reserve',
      'absent',
    })) {
      'reserved' => AdminRoleReservationState.reserved,
      'sealed' => AdminRoleReservationState.sealed,
      'sealed_before_reserve' => AdminRoleReservationState.sealedBeforeReserve,
      _ => AdminRoleReservationState.absent,
    };
    if (reservation != null &&
        expectedReservationId != null &&
        reservation != expectedReservationId.toLowerCase()) {
      throw const FormatException('Admin reservation binding mismatch.');
    }
    final batchValue = AdminUserProtocol.field(row, 'batch');
    final records = AdminUserProtocol.objects(row, 'operations');
    if (state == AdminRoleReservationState.absent ||
        state == AdminRoleReservationState.sealedBeforeReserve) {
      if (batchValue != null ||
          records.isNotEmpty ||
          (state == AdminRoleReservationState.sealedBeforeReserve &&
              expectedBatchId != null) ||
          (expectedReservationId != null &&
              reservation != expectedReservationId) ||
          (state == AdminRoleReservationState.sealedBeforeReserve &&
              reservation == null)) {
        throw const FormatException(
          'Invalid Admin reservation fence evidence.',
        );
      }
      return AdminRoleBatchEnvelope(
        actorId: actorId,
        sessionId: sessionId,
        serverNow: now,
        reservationId: reservation,
        reservationState: state,
        batch: null,
        operations: const [],
      );
    }
    final data = AdminUserProtocol.object(batchValue, 'role batch');
    final batchId = AdminUserProtocol.id(data, 'batch_id');
    final origin = AdminUserProtocol.id(data, 'origin_session_id');
    final reservedAt = AdminUserProtocol.date(data, 'reserved_at');
    final expires = AdminUserProtocol.date(data, 'execute_expires_at');
    final sealed = AdminUserProtocol.nullableDate(data, 'sealed_at');
    final batchState = AdminUserProtocol.choice(data, 'state', {
      'open',
      'sealed',
    });
    final inputHash = AdminUserProtocol.text(data, 'input_sha256');
    final snapshot = AdminUserProtocol.id(data, 'snapshot_id');
    if (reservation == null ||
        AdminUserProtocol.id(data, 'reservation_id') != reservation ||
        (expectedBatchId != null && batchId != expectedBatchId.toLowerCase()) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(inputHash) ||
        records.isEmpty ||
        reservedAt.isAfter(now) ||
        !expires.isAfter(reservedAt) ||
        expires.difference(reservedAt) > const Duration(minutes: 10) ||
        (batchState == 'sealed') !=
            (state == AdminRoleReservationState.sealed) ||
        (batchState == 'sealed') != (sealed != null) ||
        (sealed != null &&
            (sealed.isBefore(reservedAt) || sealed.isAfter(now))) ||
        (review != null &&
            (review.actorId != actorId ||
                review.reservationId != reservation ||
                review.snapshotId != snapshot ||
                review.sessionId != origin ||
                review.entries.length != records.length))) {
      throw const FormatException('Admin role batch evidence mismatch.');
    }
    final batch = AdminRoleBatch(
      batchId: batchId,
      reservationId: reservation,
      snapshotId: snapshot,
      originSessionId: origin,
      reservedAt: reservedAt,
      executeExpiresAt: expires,
      inputSha256: inputHash,
      state: batchState == 'sealed'
          ? AdminRoleBatchState.sealed
          : AdminRoleBatchState.open,
      sealedAt: sealed,
    );
    final operations = <AdminRoleOperation>[];
    final ids = <String>{};
    final targets = <String>{};
    for (var index = 0; index < records.length; index++) {
      final record = records[index];
      final opId = AdminUserProtocol.id(record, 'operation_id');
      final target = AdminUserProtocol.id(record, 'target_id');
      final ordinal = AdminUserProtocol.integer(
        record,
        'ordinal',
        minimum: 1,
        maximum: 100,
      );
      final label = AdminUserProtocol.text(record, 'display_label');
      final member = AdminUserProtocol.nullableText(record, 'member_id');
      final before = AdminUserProtocol.choice(
        record,
        'expected_role',
        AdminUserProtocol.roles,
      );
      final after = AdminUserProtocol.choice(
        record,
        'requested_role',
        AdminUserProtocol.roles,
      );
      final revision = AdminUserProtocol.integer(record, 'expected_revision');
      final beforeFlag = AdminUserProtocol.flag(record, 'expected_is_driver');
      final afterFlag = AdminUserProtocol.flag(record, 'requested_is_driver');
      final skip = AdminUserProtocol.nullableText(record, 'skip_reason');
      final expectedSkip = target == actorId
          ? 'self'
          : before == after
          ? 'same_role'
          : null;
      final entry = AdminRoleReviewEntry(
        targetId: target,
        displayLabel: label,
        memberId: member,
        expectedRole: before,
        expectedRevision: revision,
        expectedIsDriver: beforeFlag,
        requestedRole: after,
        requestedIsDriver: afterFlag,
        skipReason: switch (skip) {
          'self' => AdminRoleSkipReason.self,
          'same_role' => AdminRoleSkipReason.sameRole,
          _ => null,
        },
      );
      final operationState = switch (AdminUserProtocol.choice(
        record,
        'status',
        {'prepared', 'confirmed', 'known_rejected', 'skipped', 'not_started'},
      )) {
        'prepared' => AdminRoleOperationStatus.prepared,
        'confirmed' => AdminRoleOperationStatus.confirmed,
        'known_rejected' => AdminRoleOperationStatus.knownRejected,
        'skipped' => AdminRoleOperationStatus.skipped,
        _ => AdminRoleOperationStatus.notStarted,
      };
      final code = AdminUserProtocol.nullableText(record, 'rejection_code');
      final decided = AdminUserProtocol.nullableDate(record, 'decided_at');
      final receiptValue = AdminUserProtocol.field(record, 'receipt');
      final isSkipped = operationState == AdminRoleOperationStatus.skipped;
      final isRejected =
          operationState == AdminRoleOperationStatus.knownRejected;
      final isPrepared = operationState == AdminRoleOperationStatus.prepared;
      final isConfirmed = operationState == AdminRoleOperationStatus.confirmed;
      if (!ids.add(opId) ||
          !targets.add(target) ||
          ordinal != index + 1 ||
          (member != null && !RegExp(r'^\d{6}$').hasMatch(member)) ||
          afterFlag != (after == 'driver') ||
          skip != expectedSkip ||
          isSkipped != (skip != null) ||
          (isRejected
              ? !{'target_not_found', 'target_changed'}.contains(code)
              : code != null) ||
          (isPrepared ? decided != null : decided == null) ||
          (decided != null &&
              (decided.isBefore(reservedAt) || decided.isAfter(now))) ||
          (isPrepared && batchState == 'sealed') ||
          (operationState == AdminRoleOperationStatus.notStarted &&
              (batchState != 'sealed' || decided != sealed)) ||
          (review != null && !entry.sameReviewedTuple(review.entries[index])) ||
          (isConfirmed ? receiptValue == null : receiptValue != null)) {
        throw const FormatException(
          'Admin recipient outcome evidence mismatch.',
        );
      }
      AdminRoleReceipt? receipt;
      if (isConfirmed) {
        final proof = AdminUserProtocol.object(receiptValue, 'role receipt');
        receipt = AdminRoleReceipt(
          actorId: AdminUserProtocol.id(proof, 'actor_id'),
          sessionId: AdminUserProtocol.id(proof, 'session_id'),
          batchId: AdminUserProtocol.id(proof, 'batch_id'),
          operationId: AdminUserProtocol.id(proof, 'operation_id'),
          targetId: AdminUserProtocol.id(proof, 'target_id'),
          beforeRole: AdminUserProtocol.choice(
            proof,
            'before_role',
            AdminUserProtocol.roles,
          ),
          afterRole: AdminUserProtocol.choice(
            proof,
            'after_role',
            AdminUserProtocol.roles,
          ),
          beforeRevision: AdminUserProtocol.integer(proof, 'before_revision'),
          afterRevision: AdminUserProtocol.integer(proof, 'after_revision'),
          beforeIsDriver: AdminUserProtocol.flag(proof, 'before_is_driver'),
          afterIsDriver: AdminUserProtocol.flag(proof, 'after_is_driver'),
          auditId: AdminUserProtocol.id(proof, 'audit_id'),
          committedAt: AdminUserProtocol.date(proof, 'committed_at'),
        );
        if (receipt.actorId != actorId ||
            receipt.sessionId != origin ||
            receipt.batchId != batchId ||
            receipt.operationId != opId ||
            receipt.targetId != target ||
            receipt.beforeRole != before ||
            receipt.afterRole != after ||
            receipt.beforeRevision != revision ||
            receipt.afterRevision <= receipt.beforeRevision ||
            receipt.beforeIsDriver != beforeFlag ||
            receipt.afterIsDriver != afterFlag ||
            receipt.committedAt != decided ||
            receipt.committedAt.isAfter(now)) {
          throw const FormatException('Admin role receipt binding mismatch.');
        }
      }
      operations.add(
        AdminRoleOperation(
          operationId: opId,
          ordinal: ordinal,
          entry: entry,
          status: operationState,
          rejectionCode: code,
          decidedAt: decided,
          receipt: receipt,
        ),
      );
    }
    return AdminRoleBatchEnvelope(
      actorId: actorId,
      sessionId: sessionId,
      serverNow: now,
      reservationId: reservation,
      reservationState: state,
      batch: batch,
      operations: operations,
    );
  }
}

class AdminRoleRecipientOutcome {
  const AdminRoleRecipientOutcome({
    required this.entry,
    required this.status,
    this.operationId,
    this.rejectionCode,
    this.decidedAt,
    this.receipt,
  });
  final AdminRoleReviewEntry entry;
  final String? operationId;
  final AdminRoleOutcomeStatus status;
  final String? rejectionCode;
  final DateTime? decidedAt;
  final AdminRoleReceipt? receipt;

  AdminRoleRecipientOutcome withStatus(AdminRoleOutcomeStatus value) =>
      AdminRoleRecipientOutcome(
        entry: entry,
        status: value,
        operationId: operationId,
        rejectionCode: rejectionCode,
        decidedAt: decidedAt,
        receipt: receipt,
      );

  factory AdminRoleRecipientOutcome.fromOperation(
    AdminRoleOperation operation, {
    AdminRoleRecipientOutcome? previous,
  }) {
    if (operation.status == AdminRoleOperationStatus.prepared &&
        previous?.status == AdminRoleOutcomeStatus.knownRejected &&
        previous?.operationId == operation.operationId) {
      return previous!;
    }
    final status = switch (operation.status) {
      AdminRoleOperationStatus.confirmed => AdminRoleOutcomeStatus.confirmed,
      AdminRoleOperationStatus.knownRejected =>
        AdminRoleOutcomeStatus.knownRejected,
      AdminRoleOperationStatus.skipped => AdminRoleOutcomeStatus.skipped,
      AdminRoleOperationStatus.notStarted => AdminRoleOutcomeStatus.notStarted,
      AdminRoleOperationStatus.prepared =>
        previous?.status == AdminRoleOutcomeStatus.unknown ||
                previous?.status == AdminRoleOutcomeStatus.submitting
            ? AdminRoleOutcomeStatus.unknown
            : AdminRoleOutcomeStatus.notStarted,
    };
    return AdminRoleRecipientOutcome(
      entry: operation.entry,
      operationId: operation.operationId,
      status: status,
      rejectionCode: operation.rejectionCode,
      decidedAt: operation.decidedAt,
      receipt: operation.receipt,
    );
  }
}

class AdminRoleOutcomeCounts {
  AdminRoleOutcomeCounts(Iterable<AdminRoleRecipientOutcome> outcomes)
    : confirmed = outcomes
          .where((item) => item.status == AdminRoleOutcomeStatus.confirmed)
          .length,
      knownRejected = outcomes
          .where((item) => item.status == AdminRoleOutcomeStatus.knownRejected)
          .length,
      unknown = outcomes
          .where((item) => item.status == AdminRoleOutcomeStatus.unknown)
          .length,
      notStarted = outcomes
          .where((item) => item.status == AdminRoleOutcomeStatus.notStarted)
          .length,
      skipped = outcomes
          .where((item) => item.status == AdminRoleOutcomeStatus.skipped)
          .length,
      submitting = outcomes
          .where((item) => item.status == AdminRoleOutcomeStatus.submitting)
          .length;
  final int confirmed;
  final int knownRejected;
  final int unknown;
  final int notStarted;
  final int skipped;
  final int submitting;
}
