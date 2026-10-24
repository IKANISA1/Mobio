import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:mobi_app/features/admin/data/admin_service.dart';
import 'package:mobi_app/features/admin/domain/admin_user_protocol.dart';

/// Bounded synthetic Admin member contracts shared by local visual fixtures.
/// This helper grants no authenticated authority and never calls a backend.
class PreviewAdminUserContract {
  PreviewAdminUserContract({this.elapsed}) : _clock = Stopwatch()..start();
  static const actorId = '11111111-1111-4111-8111-111111111111';
  static const sessionId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  static const hostIdentity = 'https://admin-visual-preview.invalid';
  final Stopwatch _clock;
  final Duration Function()? elapsed;
  DateTime get _now =>
      DateTime.utc(2026, 6, 18, 8).add(elapsed?.call() ?? _clock.elapsed);
  int _serial = 0;
  final _snapshots = <String, AdminUserPage>{};
  final _batches = <String, AdminRoleBatchEnvelope>{};
  final _fences = <String>{};
  final _users = <String, AdminUserSnapshotRow>{
    '22222222-2222-4222-8222-222222222222': const AdminUserSnapshotRow(
      user: AdminUserListItem(
        id: '22222222-2222-4222-8222-222222222222',
        name: 'Chantal Rider',
        phone: '+250788111222',
        role: 'passenger',
        isDriver: false,
        hasFaceId: true,
        isOnline: true,
        memberId: '482013',
        createdAt: '2026-06-10T08:00:00Z',
        vehicleType: 'cab',
      ),
      roleRevision: 0,
    ),
  };
  AdminRoleRecoveryOwner get owner => const AdminRoleRecoveryOwner(
    actorId: actorId,
    hostIdentity: hostIdentity,
  );
  String _id() =>
      '33333333-3333-4333-8333-${(++_serial).toString().padLeft(12, '0')}';
  Never _fail(String code) => throw StateError(code);

  Future<AdminUserPage> page(AdminUserQuery query) async {
    _snapshots.removeWhere((id, page) => !page.expiresAt.isAfter(_now));
    AdminUserPage frozen;
    if (query.snapshotId case final String id) {
      frozen = _snapshots[id] ?? _fail('ADMIN_USERS_SNAPSHOT_NOT_FOUND');
      if (frozen.query.role != query.role ||
          frozen.query.search != query.search ||
          frozen.query.sort != query.sort ||
          frozen.query.pageSize != query.pageSize) {
        _fail('ADMIN_USERS_SNAPSHOT_BINDING_MISMATCH');
      }
    } else {
      if (_snapshots.length >= 3) _fail('ADMIN_USERS_SNAPSHOT_LIMIT');
      final rows = _users.values
          .where(
            (row) =>
                (query.role == null || row.user.role == query.role) &&
                (query.search == null ||
                    [
                      row.user.name,
                      row.user.phone,
                      row.user.memberId ?? '',
                    ].any(
                      (value) => value.toLowerCase().contains(
                        query.search!.toLowerCase(),
                      ),
                    )),
          )
          .toList();
      int label(AdminUserSnapshotRow a, AdminUserSnapshotRow b) {
        final value = a.user.name.toLowerCase().compareTo(
          b.user.name.toLowerCase(),
        );
        return value == 0 ? a.user.id.compareTo(b.user.id) : value;
      }

      rows.sort(
        (a, b) => switch (query.sort) {
          'name_desc' => -label(a, b),
          'role' =>
            a.user.role.compareTo(b.user.role) == 0
                ? label(a, b)
                : a.user.role.compareTo(b.user.role),
          'newest' =>
            a.user.createdAt == b.user.createdAt
                ? a.user.id.compareTo(b.user.id)
                : b.user.createdAt!.compareTo(a.user.createdAt!),
          'online' =>
            a.user.isOnline == b.user.isOnline
                ? label(a, b)
                : a.user.isOnline
                ? -1
                : 1,
          _ => label(a, b),
        },
      );
      final now = _now;
      final id = _id();
      frozen = AdminUserPage(
        actorId: actorId,
        sessionId: sessionId,
        serverNow: now,
        snapshotId: id,
        asOf: now,
        expiresAt: now.add(const Duration(minutes: 10)),
        query: AdminUserQuery(
          role: query.role,
          search: query.search,
          sort: query.sort,
          pageSize: query.pageSize,
          snapshotId: id,
        ),
        totalExact: rows.length,
        hasNextPage: false,
        rows: rows,
      );
      _snapshots[id] = frozen;
    }
    if (query.offset > frozen.totalExact) _fail('ADMIN_USERS_QUERY_INVALID');
    final rows = frozen.rows.skip(query.offset).take(query.pageSize).toList();
    return AdminUserPage(
      actorId: actorId,
      sessionId: sessionId,
      serverNow: _now,
      snapshotId: frozen.snapshotId,
      asOf: frozen.asOf,
      expiresAt: frozen.expiresAt,
      query: AdminUserQuery(
        role: query.role,
        search: query.search,
        sort: query.sort,
        pageSize: query.pageSize,
        snapshotId: frozen.snapshotId,
        offset: query.offset,
      ),
      totalExact: frozen.totalExact,
      hasNextPage: query.offset + rows.length < frozen.totalExact,
      rows: rows,
    );
  }

  Future<AdminUserSnapshotRelease> release(String id) async {
    final removed = _snapshots.remove(id) != null;
    return AdminUserSnapshotRelease(
      actorId: actorId,
      sessionId: sessionId,
      serverNow: _now,
      snapshotId: id,
      released: removed,
      alreadyAbsent: !removed,
    );
  }

  Future<AdminRoleBatchEnvelope> reserve(AdminRoleReview review) async {
    if (review.actorId != actorId || review.sessionId != sessionId) {
      _fail('ADMIN_ROLE_SESSION_CHANGED');
    }
    if (_fences.contains(review.reservationId)) {
      _fail('ADMIN_ROLE_RESERVATION_SEALED');
    }
    final hash = sha256
        .convert(
          utf8.encode(
            jsonEncode(
              review.entries.map((entry) => entry.toReserveTarget()).toList(),
            ),
          ),
        )
        .toString();
    final existing = _batches[review.reservationId];
    if (existing != null) {
      if (existing.batch!.inputSha256 != hash ||
          existing.batch!.snapshotId != review.snapshotId) {
        _fail('ADMIN_ROLE_RESERVATION_CONFLICT');
      }
      return _echo(existing);
    }
    if (_batches.values.any((batch) => !batch.isSealed)) {
      _fail('ADMIN_ROLE_BATCH_OPEN');
    }
    final snapshot =
        _snapshots[review.snapshotId] ??
        _fail('ADMIN_USERS_SNAPSHOT_NOT_FOUND');
    if (!snapshot.expiresAt.isAfter(_now)) {
      _fail('ADMIN_USERS_SNAPSHOT_EXPIRED');
    }
    if (review.entries.isEmpty ||
        review.entries.length > 100 ||
        review.entries.map((entry) => entry.targetId).toSet().length !=
            review.entries.length) {
      _fail('ADMIN_ROLE_ARGUMENT_INVALID');
    }
    for (final entry in review.entries) {
      final row = snapshot.rows
          .where((row) => row.user.id == entry.targetId)
          .firstOrNull;
      final expectedSkip = entry.targetId == actorId
          ? AdminRoleSkipReason.self
          : entry.expectedRole == entry.requestedRole
          ? AdminRoleSkipReason.sameRole
          : null;
      if (row == null ||
          row.user.role != entry.expectedRole ||
          row.roleRevision != entry.expectedRevision ||
          row.user.isDriver != entry.expectedIsDriver ||
          row.user.name != entry.displayLabel ||
          row.user.memberId != entry.memberId ||
          !AdminUserProtocol.roles.contains(entry.requestedRole) ||
          entry.requestedRole != review.requestedRole ||
          entry.requestedIsDriver != (entry.requestedRole == 'driver') ||
          entry.skipReason != expectedSkip) {
        _fail('ADMIN_ROLE_ARGUMENT_INVALID');
      }
    }
    final now = _now;
    final batch = AdminRoleBatch(
      batchId: _id(),
      reservationId: review.reservationId,
      snapshotId: review.snapshotId,
      originSessionId: sessionId,
      reservedAt: now,
      executeExpiresAt: now.add(const Duration(minutes: 10)),
      inputSha256: hash,
      state: AdminRoleBatchState.open,
      sealedAt: null,
    );
    final result = AdminRoleBatchEnvelope(
      actorId: actorId,
      sessionId: sessionId,
      serverNow: now,
      reservationId: review.reservationId,
      reservationState: AdminRoleReservationState.reserved,
      batch: batch,
      operations: [
        for (var i = 0; i < review.entries.length; i++)
          AdminRoleOperation(
            operationId: _id(),
            ordinal: i + 1,
            entry: review.entries[i],
            status: review.entries[i].skipReason == null
                ? AdminRoleOperationStatus.prepared
                : AdminRoleOperationStatus.skipped,
            rejectionCode: null,
            decidedAt: review.entries[i].skipReason == null ? null : now,
            receipt: null,
          ),
      ],
    );
    _batches[review.reservationId] = result;
    return result;
  }

  AdminRoleBatchEnvelope _echo(
    AdminRoleBatchEnvelope source, {
    AdminRoleBatch? batch,
    List<AdminRoleOperation>? operations,
  }) => AdminRoleBatchEnvelope(
    actorId: actorId,
    sessionId: sessionId,
    serverNow: _now,
    reservationId: source.reservationId,
    reservationState:
        (batch ?? source.batch)!.state == AdminRoleBatchState.sealed
        ? AdminRoleReservationState.sealed
        : AdminRoleReservationState.reserved,
    batch: batch ?? source.batch,
    operations: operations ?? source.operations,
  );
  Future<AdminRoleBatchEnvelope> execute(
    AdminRoleBatchEnvelope envelope,
    String operationId,
  ) async {
    final source =
        _batches[envelope.reservationId] ?? _fail('ADMIN_ROLE_BATCH_NOT_FOUND');
    if (!source.continues(envelope)) _fail('ADMIN_ROLE_ARGUMENT_INVALID');
    final batch = source.batch!;
    if (batch.state == AdminRoleBatchState.sealed) {
      _fail('ADMIN_ROLE_BATCH_SEALED');
    }
    if (!batch.executeExpiresAt.isAfter(_now)) {
      _fail('ADMIN_ROLE_BATCH_EXPIRED');
    }
    final operation =
        source.operations
            .where((op) => op.operationId == operationId)
            .firstOrNull ??
        _fail('ADMIN_ROLE_OPERATION_NOT_FOUND');
    if (operation.status != AdminRoleOperationStatus.prepared) {
      return _echo(source);
    }
    final entry = operation.entry, row = _users[operation.entry.targetId];
    final code = row == null
        ? 'target_not_found'
        : row.user.role != entry.expectedRole ||
              row.roleRevision != entry.expectedRevision ||
              row.user.isDriver != entry.expectedIsDriver
        ? 'target_changed'
        : null;
    final now = _now;
    AdminRoleReceipt? receipt;
    if (code == null) {
      final previous = row!.user;
      _users[entry.targetId] = AdminUserSnapshotRow(
        roleRevision: entry.expectedRevision + 1,
        user: AdminUserListItem(
          id: previous.id,
          name: previous.name,
          phone: previous.phone,
          role: entry.requestedRole,
          isDriver: entry.requestedIsDriver,
          vehicleType: previous.vehicleType,
          memberId: previous.memberId,
          hasFaceId: previous.hasFaceId,
          isOnline: previous.isOnline,
          createdAt: previous.createdAt,
        ),
      );
      receipt = AdminRoleReceipt(
        actorId: actorId,
        sessionId: batch.originSessionId,
        batchId: batch.batchId,
        operationId: operationId,
        targetId: entry.targetId,
        beforeRole: entry.expectedRole,
        afterRole: entry.requestedRole,
        beforeRevision: entry.expectedRevision,
        afterRevision: entry.expectedRevision + 1,
        beforeIsDriver: entry.expectedIsDriver,
        afterIsDriver: entry.requestedIsDriver,
        auditId: _id(),
        committedAt: now,
      );
    }
    final result = _echo(
      source,
      operations: [
        for (final op in source.operations)
          if (op.operationId != operationId)
            op
          else
            AdminRoleOperation(
              operationId: op.operationId,
              ordinal: op.ordinal,
              entry: op.entry,
              status: code == null
                  ? AdminRoleOperationStatus.confirmed
                  : AdminRoleOperationStatus.knownRejected,
              rejectionCode: code,
              decidedAt: now,
              receipt: receipt,
            ),
      ],
    );
    _batches[source.reservationId!] = result;
    return result;
  }

  AdminRoleBatchEnvelope _empty(String? reservation, {bool sealed = false}) =>
      AdminRoleBatchEnvelope(
        actorId: actorId,
        sessionId: sessionId,
        serverNow: _now,
        reservationId: reservation,
        reservationState: sealed
            ? AdminRoleReservationState.sealedBeforeReserve
            : AdminRoleReservationState.absent,
        batch: null,
        operations: const [],
      );
  AdminRoleBatchEnvelope? _find(String? batchId, String? reservationId) {
    if (batchId != null && reservationId != null) {
      _fail('ADMIN_ROLE_ARGUMENT_INVALID');
    }
    if (reservationId != null) return _batches[reservationId];
    return _batches.values
        .where(
          (batch) => batchId == null
              ? !batch.isSealed
              : batch.batch!.batchId == batchId,
        )
        .firstOrNull;
  }

  Future<AdminRoleBatchEnvelope> status({
    String? batchId,
    String? reservationId,
  }) async {
    final found = _find(batchId, reservationId);
    if (found != null) return _echo(found);
    return _empty(
      reservationId,
      sealed: reservationId != null && _fences.contains(reservationId),
    );
  }

  Future<AdminRoleBatchEnvelope> seal({
    String? batchId,
    String? reservationId,
  }) async {
    if ((batchId == null) == (reservationId == null)) {
      _fail('ADMIN_ROLE_ARGUMENT_INVALID');
    }
    final source = _find(batchId, reservationId);
    if (source == null) {
      if (reservationId == null) _fail('ADMIN_ROLE_BATCH_NOT_FOUND');
      _fences.add(reservationId);
      return _empty(reservationId, sealed: true);
    }
    if (source.isSealed) return _echo(source);
    final old = source.batch!, now = _now;
    final batch = AdminRoleBatch(
      batchId: old.batchId,
      reservationId: old.reservationId,
      snapshotId: old.snapshotId,
      originSessionId: old.originSessionId,
      reservedAt: old.reservedAt,
      executeExpiresAt: old.executeExpiresAt,
      inputSha256: old.inputSha256,
      state: AdminRoleBatchState.sealed,
      sealedAt: now,
    );
    final result = _echo(
      source,
      batch: batch,
      operations: [
        for (final op in source.operations)
          if (op.status != AdminRoleOperationStatus.prepared)
            op
          else
            AdminRoleOperation(
              operationId: op.operationId,
              ordinal: op.ordinal,
              entry: op.entry,
              status: AdminRoleOperationStatus.notStarted,
              rejectionCode: null,
              decidedAt: now,
              receipt: null,
            ),
      ],
    );
    _fences.add(source.reservationId!);
    _batches[source.reservationId!] = result;
    return result;
  }
}
