import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/admin/application/admin_services.dart';
import 'package:mobi_app/features/admin/application/admin_users_provider.dart';
import 'package:mobi_app/features/admin/application/admin_users_state.dart';
import 'package:mobi_app/features/admin/data/admin_role_change_journal.dart';
import 'package:mobi_app/features/admin/data/admin_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'admin_user_protocol_fixture.dart';

class MemoryRoleJournal implements AdminRoleJournal {
  AdminRoleRecoveryPointer? pointer;
  final saves = <AdminRoleRecoveryPointer>[];
  final clears = <String>[];
  Future<void> Function(AdminRoleRecoveryPointer)? onSave;
  @override
  Future<AdminRoleRecoveryPointer?> load(AdminRoleRecoveryOwner owner) async =>
      pointer;
  @override
  Future<void> save(
    AdminRoleRecoveryPointer value, {
    required bool Function() ownerIsCurrent,
  }) async {
    saves.add(value);
    await onSave?.call(value);
    if (!ownerIsCurrent()) throw StateError('OWNER_CHANGED');
    pointer = value;
  }

  @override
  Future<void> clear(
    AdminRoleRecoveryOwner owner,
    String reservationId, {
    required bool Function() ownerIsCurrent,
  }) async {
    if (!ownerIsCurrent()) throw StateError('OWNER_CHANGED');
    clears.add(reservationId);
    if (pointer?.reservationId == reservationId) pointer = null;
  }
}

class AdminUsersFixture implements AdminService {
  AccountSnapshot account = const AccountSnapshot(
    fixtureActor,
    fixtureSession,
    1,
  );
  int revision = 0;
  Duration elapsed = Duration.zero;
  final journal = MemoryRoleJournal();
  List<Map<String, dynamic>> rows = [
    fixtureUser(1),
    fixtureUser(2),
    fixtureUser(3),
  ];
  final queries = <AdminUserQuery>[];
  final releases = <String>[];
  final reserves = <AdminRoleReview>[];
  final executes = <String>[];
  final statusCalls = <({String? batchId, String? reservationId})>[];
  final seals = <String>[];
  final serverBatches = <String, AdminRoleBatchEnvelope>{};
  final serverPlans = <String, AdminRoleReview>{};
  final fenced = <String>{};
  final snapshots = <String, List<Map<String, dynamic>>>{};
  final snapshotOwners = <String, ({String actor, String session})>{};
  int snapshotCounter = 0;
  Future<AdminUserPage> Function(AdminUserQuery)? onPage;
  Future<AdminUserSnapshotRelease> Function(String)? onRelease;
  Future<AdminRoleBatchEnvelope> Function(AdminRoleReview)? onReserve;
  Future<AdminRoleBatchEnvelope> Function(AdminRoleBatchEnvelope, String)?
  onExecute;
  Future<AdminRoleBatchEnvelope> Function(String?, String?)? onStatus;

  @override
  String? get currentUserId => account.userId;
  @override
  String? get currentSessionId => account.sessionId;
  @override
  AdminRoleRecoveryOwner get roleRecoveryOwner => AdminRoleRecoveryOwner(
    actorId: account.userId,
    hostIdentity: 'https://admin-contract.invalid',
  );

  @override
  Future<AdminUserPage> listUsersPage(AdminUserQuery query) async {
    queries.add(query);
    if (onPage != null) return onPage!(query);
    if (query.snapshotId == null && snapshots.length >= 3) {
      throw const PostgrestException(
        message: 'ADMIN_USERS_SNAPSHOT_LIMIT',
        code: 'P0001',
      );
    }
    final snapshot =
        query.snapshotId ??
        '33333333-3333-4333-8333-${(++snapshotCounter).toString().padLeft(12, '0')}';
    snapshots.putIfAbsent(snapshot, () => rows.map(copyJson).toList());
    snapshotOwners.putIfAbsent(
      snapshot,
      () => (actor: account.userId, session: account.sessionId),
    );
    final frozen = snapshots[snapshot]!;
    final page = frozen.skip(query.offset).take(query.pageSize).toList();
    final raw =
        fixturePageJson(
            query,
            rows: page,
            total: frozen.length,
            snapshot: snapshot,
          )
          ..['actor_id'] = account.userId
          ..['session_id'] = account.sessionId;
    return AdminUserPage.parse(
      raw,
      actorId: account.userId,
      sessionId: account.sessionId,
      request: query,
    );
  }

  AdminUserSnapshotRelease releaseNow(String snapshotId) {
    final owner = snapshotOwners[snapshotId];
    if (owner != null &&
        (owner.actor != account.userId || owner.session != account.sessionId)) {
      throw const PostgrestException(
        message: 'ADMIN_USERS_SNAPSHOT_BINDING_MISMATCH',
        code: '42501',
      );
    }
    final absent = snapshots.remove(snapshotId) == null;
    snapshotOwners.remove(snapshotId);
    return AdminUserSnapshotRelease.parse(
      fixtureReleaseJson(
        snapshotId,
        absent: absent,
        session: account.sessionId,
      ),
      actorId: account.userId,
      sessionId: account.sessionId,
      snapshotId: snapshotId,
    );
  }

  @override
  Future<AdminUserSnapshotRelease> releaseUsersSnapshot(
    String snapshotId,
  ) async {
    releases.add(snapshotId);
    if (onRelease != null) return onRelease!(snapshotId);
    return releaseNow(snapshotId);
  }

  AdminRoleBatchEnvelope echo(AdminRoleBatchEnvelope envelope) {
    final plan = serverPlans[envelope.reservationId]!;
    return fixtureEnvelope(
      plan,
      session: account.sessionId,
      statuses: envelope.operations
          .map(
            (operation) => switch (operation.status) {
              AdminRoleOperationStatus.prepared => 'prepared',
              AdminRoleOperationStatus.confirmed => 'confirmed',
              AdminRoleOperationStatus.knownRejected => 'known_rejected',
              AdminRoleOperationStatus.skipped => 'skipped',
              AdminRoleOperationStatus.notStarted => 'not_started',
            },
          )
          .toList(),
      sealed: envelope.isSealed,
      batch: envelope.batch!.batchId,
    );
  }

  @override
  Future<AdminRoleBatchEnvelope> reserveRoleChange(
    AdminRoleReview review,
  ) async {
    reserves.add(review);
    if (onReserve != null) return onReserve!(review);
    if (fenced.contains(review.reservationId)) {
      throw const PostgrestException(
        message: 'ADMIN_ROLE_RESERVATION_SEALED',
        code: 'P0001',
      );
    }
    if (serverBatches.values.any((batch) => !batch.isSealed)) {
      throw const PostgrestException(
        message: 'ADMIN_ROLE_BATCH_OPEN',
        code: 'P0001',
      );
    }
    final result = fixtureEnvelope(review);
    serverPlans[review.reservationId] = review;
    serverBatches[review.reservationId] = result;
    return result;
  }

  AdminRoleBatchEnvelope commit(
    AdminRoleBatchEnvelope envelope,
    String operationId, {
    bool reject = false,
  }) {
    final plan = serverPlans[envelope.reservationId]!;
    final previous = serverBatches[plan.reservationId]!;
    final statuses = previous.operations
        .map(
          (operation) => operation.operationId == operationId
              ? reject
                    ? 'known_rejected'
                    : 'confirmed'
              : switch (operation.status) {
                  AdminRoleOperationStatus.confirmed => 'confirmed',
                  AdminRoleOperationStatus.knownRejected => 'known_rejected',
                  AdminRoleOperationStatus.skipped => 'skipped',
                  _ => 'prepared',
                },
        )
        .toList();
    final result = fixtureEnvelope(plan, statuses: statuses);
    serverBatches[plan.reservationId] = result;
    return result;
  }

  @override
  Future<AdminRoleBatchEnvelope> executeRoleChange({
    required AdminRoleBatchEnvelope envelope,
    required String operationId,
  }) async {
    executes.add(operationId);
    if (onExecute != null) return onExecute!(envelope, operationId);
    return commit(envelope, operationId);
  }

  @override
  Future<AdminRoleBatchEnvelope> roleChangeStatus({
    String? batchId,
    String? reservationId,
  }) async {
    statusCalls.add((batchId: batchId, reservationId: reservationId));
    if (onStatus != null) return onStatus!(batchId, reservationId);
    final matching = reservationId != null
        ? serverBatches[reservationId]
        : serverBatches.values
              .where(
                (value) => batchId != null
                    ? value.batch!.batchId == batchId
                    : !value.isSealed,
              )
              .firstOrNull;
    if (matching != null) return echo(matching);
    return AdminRoleBatchEnvelope.parse(
      fixtureEmptyRoleJson(
        reservation: reservationId,
        sealed: reservationId != null && fenced.contains(reservationId),
        session: account.sessionId,
      ),
      actorId: fixtureActor,
      sessionId: account.sessionId,
      expectedReservationId: reservationId,
    );
  }

  @override
  Future<AdminRoleBatchEnvelope> sealRoleChange({
    String? batchId,
    String? reservationId,
  }) async {
    final token = reservationId!;
    seals.add(token);
    fenced.add(token);
    final previous = serverBatches[token];
    if (previous == null) {
      return AdminRoleBatchEnvelope.parse(
        fixtureEmptyRoleJson(
          reservation: token,
          sealed: true,
          session: account.sessionId,
        ),
        actorId: fixtureActor,
        sessionId: account.sessionId,
        expectedReservationId: token,
      );
    }
    final statuses = previous.operations
        .map(
          (operation) => switch (operation.status) {
            AdminRoleOperationStatus.confirmed => 'confirmed',
            AdminRoleOperationStatus.knownRejected => 'known_rejected',
            AdminRoleOperationStatus.skipped => 'skipped',
            _ => 'not_started',
          },
        )
        .toList();
    final result = fixtureEnvelope(
      serverPlans[token]!,
      statuses: statuses,
      sealed: true,
      session: account.sessionId,
      batch: previous.batch!.batchId,
    );
    serverBatches[token] = result;
    return result;
  }

  void replaceSession() {
    account = AccountSnapshot(
      account.userId,
      fixtureNextSession,
      account.generation + 1,
    );
    revision++;
    AccountContext.changes.value++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'Unexpected fixture call: ${invocation.memberName}',
  );
}

class OpenAdminUsers {
  OpenAdminUsers(this.container, this.controller, this._cleanup);
  final void Function() _cleanup;
  bool _closed = false;
  void close() {
    if (!_closed) {
      _closed = true;
      _cleanup();
    }
  }

  final ProviderContainer container;
  final AdminUsersController controller;
  AdminUsersState get value => container.read(adminUsersProvider).requireValue;
}

Future<OpenAdminUsers> openAdminUsers(AdminUsersFixture fixture) async {
  final container = ProviderContainer(
    overrides: [
      adminServiceProvider.overrideWithValue(fixture),
      adminRoleJournalProvider.overrideWithValue(fixture.journal),
      adminUsersAccountProvider.overrideWithValue(() => fixture.account),
      adminUsersAccountRevisionProvider.overrideWithValue(
        () => fixture.revision,
      ),
      adminUsersElapsedProvider.overrideWithValue(() => fixture.elapsed),
    ],
  );
  final subscription = container.listen(adminUsersProvider, (_, _) {});
  await container.read(adminUsersProvider.future);
  final opened = OpenAdminUsers(
    container,
    container.read(adminUsersProvider.notifier),
    () {
      subscription.close();
      container.dispose();
    },
  );
  addTearDown(opened.close);
  return opened;
}
