import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/admin/application/admin_users_state.dart';
import 'package:mobi_app/features/admin/domain/admin_user_query.dart';

import '../fixtures/admin_user_protocol_fixture.dart';
import '../fixtures/admin_users_controller_fixture.dart';

void main() {
  test('nullable fields clear without erasing omitted values or outcomes', () {
    const before = AdminUsersState(
      loadError: 'Unavailable',
      updatingUserId: fixtureActor,
      bulkUpdatingRole: 'driver',
    );
    final after = before.copyWith(updatingUserId: null, bulkUpdatingRole: null);
    expect(after.updatingUserId, isNull);
    expect(after.bulkUpdatingRole, isNull);
    expect(after.loadError, 'Unavailable');
    expect(after.copyWith(loadError: null).loadError, isNull);
  });
  test(
    'server sort starts a new snapshot at zero; pagination retains its handle',
    () async {
      final service = AdminUsersFixture();
      final opened = await openAdminUsers(service);
      expect(opened.value.paginationTotal, 3);
      expect(service.queries.first.pageSize, 25);
      await opened.controller.setRowsPerPage(2);
      final handle = opened.value.snapshotId;
      await opened.controller.setPage(1);
      expect(service.queries.last.snapshotId, handle);
      expect(service.queries.last.offset, 2);
      await opened.controller.setSortKey('name_asc');
      expect(service.queries.last.sort, 'name_asc');
      expect(service.queries.last.snapshotId, isNull);
      expect(service.queries.last.offset, 0);
      expect(opened.value.snapshotId, isNot(handle));
    },
  );
  test(
    'authoritative rows retain server order without a local comparator',
    () async {
      final service = AdminUsersFixture()
        ..onPage = (query) async => AdminUserPage.parse(
          fixturePageJson(
            query,
            rows: [
              fixtureUser(1, name: '\uE000'),
              fixtureUser(2, name: '😀'),
            ],
          ),
          actorId: fixtureActor,
          sessionId: fixtureSession,
          request: query,
        );
      final opened = await openAdminUsers(service);
      expect(opened.value.users.map((user) => user.id), [
        fixtureTarget(1),
        fixtureTarget(2),
      ]);
    },
  );
  test('older filter completion cannot replace a later query', () async {
    final service = AdminUsersFixture();
    final opened = await openAdminUsers(service);
    final first = Completer<AdminUserPage>();
    final second = Completer<AdminUserPage>();
    final pending = <AdminUserQuery>[];
    service.onPage = (query) {
      pending.add(query);
      return query.role == 'driver' ? first.future : second.future;
    };
    final old = opened.controller.onRoleFilterChanged('driver');
    await Future<void>.delayed(Duration.zero);
    final newer = opened.controller.onRoleFilterChanged('passenger');
    await Future<void>.delayed(Duration.zero);
    second.complete(
      AdminUserPage.parse(
        fixturePageJson(pending.last),
        actorId: fixtureActor,
        sessionId: fixtureSession,
        request: pending.last,
      ),
    );
    await newer;
    first.complete(
      AdminUserPage.parse(
        fixturePageJson(pending.first),
        actorId: fixtureActor,
        sessionId: fixtureSession,
        request: pending.first,
      ),
    );
    await old;
    expect(opened.value.roleFilter, 'passenger');
    expect(opened.value.isLoading, false);
  });
  test(
    'typing immediately invalidates pending result before debounce dispatch',
    () async {
      final service = AdminUsersFixture();
      final opened = await openAdminUsers(service);
      final response = Completer<AdminUserPage>();
      AdminUserQuery? oldQuery;
      final dispatched = Completer<void>();
      service.onPage = (query) {
        if (query.search == null) {
          oldQuery = query;
          return response.future;
        }
        if (!dispatched.isCompleted) dispatched.complete();
        return Future.value(
          AdminUserPage.parse(
            fixturePageJson(query),
            actorId: fixtureActor,
            sessionId: fixtureSession,
            request: query,
          ),
        );
      };
      final old = opened.controller.refresh();
      await Future<void>.delayed(Duration.zero);
      opened.controller.onSearchChanged('100001');
      response.complete(
        AdminUserPage.parse(
          fixturePageJson(oldQuery!),
          actorId: fixtureActor,
          sessionId: fixtureSession,
          request: oldQuery!,
        ),
      );
      await old;
      expect(opened.value.searchQuery, '100001');
      expect(opened.value.snapshotId, isNull);
      await dispatched.future;
      await Future<void>.delayed(Duration.zero);
      expect(service.queries.last.search, '100001');
    },
  );
  test(
    'more than three query changes release superseded caches and unsent reviews',
    () async {
      final service = AdminUsersFixture();
      final opened = await openAdminUsers(service);
      opened.controller.toggleSelectAll(true);
      final review = opened.controller.prepareRoleReview('driver');
      final first = opened.value.snapshotId;
      await opened.controller.setSortKey('name_asc');
      expect(opened.value.roleReview, isNull);
      await expectLater(
        opened.controller.confirmRoleReview(review.reviewId),
        throwsA(isA<ValidationException>()),
      );
      await opened.controller.onRoleFilterChanged('driver');
      await opened.controller.setRowsPerPage(2);
      await opened.controller.refresh();
      opened.controller.onSearchChanged('100001');
      await Future<void>.delayed(const Duration(milliseconds: 320));
      expect(service.queries.length, 6);
      expect(service.releases.first, first);
      expect(service.releases.length, 5);
      expect(service.snapshots.length, 1);
      expect(opened.value.totalExact, 3);
      expect(opened.value.loadError, isNull);
      expect(service.reserves, isEmpty);
    },
  );
  test(
    'lost release response retains the handle and exact retry accepts authoritative absence',
    () async {
      final service = AdminUsersFixture();
      final opened = await openAdminUsers(service);
      final handle = opened.value.snapshotId!;
      service.onRelease = (id) async {
        service.releaseNow(id);
        throw StateError('Response lost after cache deletion');
      };
      await opened.controller.setSortKey('name_asc');
      expect(service.queries.length, 1);
      expect(opened.value.snapshotId, handle);
      expect(opened.value.totalExact, isNull);
      expect(opened.value.users, isEmpty);
      expect(opened.value.canPrepareReview, false);
      expect(opened.value.loadError, contains('release'));
      service.onRelease = null;
      await opened.controller.refresh();
      expect(service.releases, [handle, handle]);
      expect(service.queries.last.sort, 'name_asc');
      expect(opened.value.snapshotId, isNot(handle));
      expect(opened.value.totalExact, 3);
    },
  );
  test(
    'an expired handle can be released before a new live snapshot',
    () async {
      final service = AdminUsersFixture();
      final opened = await openAdminUsers(service);
      final handle = opened.value.snapshotId;
      service.elapsed = const Duration(minutes: 11);
      await opened.controller.refresh();
      expect(service.releases, [handle]);
      expect(opened.value.snapshotExpired, false);
      expect(opened.value.totalExact, 3);
    },
  );
  test(
    'foreign release rejection retains the handle and does not mint a replacement',
    () async {
      final service = AdminUsersFixture();
      final opened = await openAdminUsers(service);
      final handle = opened.value.snapshotId!;
      service.snapshotOwners[handle] = (
        actor: fixtureTarget(9),
        session: fixtureSession,
      );
      await opened.controller.refresh();
      expect(service.queries.length, 1);
      expect(service.releases, [handle]);
      expect(opened.value.snapshotId, handle);
      expect(opened.value.totalExact, isNull);
      expect(opened.value.loadError, contains('release'));
    },
  );
  test(
    'account replacement during release cannot dispatch or publish a new query',
    () async {
      final service = AdminUsersFixture();
      final opened = await openAdminUsers(service);
      final completed = Completer<AdminUserSnapshotRelease>();
      final started = Completer<void>();
      service.onRelease = (_) {
        started.complete();
        return completed.future;
      };
      final handle = opened.value.snapshotId!;
      final pending = opened.controller.setSortKey('newest');
      await started.future;
      service.replaceSession();
      completed.complete(
        AdminUserSnapshotRelease.parse(
          fixtureReleaseJson(handle),
          actorId: fixtureActor,
          sessionId: fixtureSession,
          snapshotId: handle,
        ),
      );
      await pending;
      expect(service.queries.length, 1);
      expect(opened.value.users, isEmpty);
      expect(opened.value.snapshotId, isNull);
      expect(opened.value.totalExact, isNull);
      expect(opened.value.recoveryPhase, AdminRoleRecoveryPhase.blocked);
    },
  );
  test('selection remains page-scoped and query changes clear it', () async {
    final service = AdminUsersFixture();
    final opened = await openAdminUsers(service);
    await opened.controller.setRowsPerPage(2);
    opened.controller.toggleSelectionFor([
      fixtureTarget(1),
      fixtureTarget(3),
    ], true);
    expect(opened.value.selectedIds, {fixtureTarget(1)});
    await opened.controller.setPage(1);
    expect(opened.value.selectedIds, isEmpty);
    opened.controller.toggleSelectAll(true);
    await opened.controller.onRoleFilterChanged('driver');
    expect(opened.value.selectedIds, isEmpty);
  });
  test(
    'prepare and Cancel perform zero reserve/target writes and preserve selection',
    () async {
      final service = AdminUsersFixture();
      final opened = await openAdminUsers(service);
      opened.controller.toggleSelectAll(true);
      final selected = opened.value.selectedIds;
      final review = opened.controller.prepareRoleReview('driver');
      opened.controller.cancelRoleReview(review.reviewId);
      expect(service.reserves, isEmpty);
      expect(service.executes, isEmpty);
      expect(opened.value.roleReview, isNull);
      expect(opened.value.selectedIds, selected);
    },
  );
  test(
    'single target and selected batch freeze names, role revision and explicit exclusions',
    () async {
      final service = AdminUsersFixture()
        ..rows = [
          fixtureUser(1, id: fixtureActor, role: 'admin'),
          fixtureUser(2, role: 'driver'),
          fixtureUser(3),
        ];
      final opened = await openAdminUsers(service);
      opened.controller.toggleSelectAll(true);
      final review = opened.controller.prepareRoleReview('driver');
      expect(review.entries.map((entry) => entry.skipReason), [
        AdminRoleSkipReason.self,
        AdminRoleSkipReason.sameRole,
        null,
      ]);
      opened.controller.toggleSelectAll(false);
      expect(review.entries.length, 3);
      opened.controller.cancelRoleReview(review.reviewId);
      final single = opened.controller.prepareRoleReview(
        'admin',
        targetIds: {fixtureTarget(3)},
      );
      expect(single.entries.single.expectedRole, 'passenger');
      expect(single.entries.single.expectedRevision, 0);
      expect(single.entries.single.requestedIsDriver, false);
      expect(service.executes, isEmpty);
    },
  );
  test(
    'verified journal completion precedes reservation; failure sends no RPC',
    () async {
      final service = AdminUsersFixture();
      final opened = await openAdminUsers(service);
      opened.controller.toggleSelectAll(true);
      final review = opened.controller.prepareRoleReview('driver');
      final saved = Completer<void>();
      service.journal.onSave = (_) => saved.future;
      final work = opened.controller.confirmRoleReview(review.reviewId);
      await Future<void>.delayed(Duration.zero);
      expect(service.reserves, isEmpty);
      saved.completeError(StateError('Storage unavailable'));
      await work;
      expect(service.reserves, isEmpty);
      expect(service.executes, isEmpty);
      expect(opened.value.recoveryPhase, AdminRoleRecoveryPhase.blocked);
    },
  );
  test(
    'sequential submission waits for each receipt and duplicate Confirm cannot dispatch again',
    () async {
      final service = AdminUsersFixture();
      final opened = await openAdminUsers(service);
      opened.controller.toggleSelectAll(true);
      final review = opened.controller.prepareRoleReview('driver');
      final response = Completer<AdminRoleBatchEnvelope>();
      final started = Completer<void>();
      service.onExecute = (envelope, id) {
        if (service.executes.length == 1) {
          started.complete();
          return response.future;
        }
        return Future.value(service.commit(envelope, id));
      };
      final work = opened.controller.confirmRoleReview(review.reviewId);
      await started.future;
      expect(service.executes.length, 1);
      expect(opened.value.canChangeQuery, false);
      final queriesBefore = service.queries.length;
      await opened.controller.refresh();
      await opened.controller.setSortKey('newest');
      await opened.controller.onRoleFilterChanged('admin');
      opened.controller.onSearchChanged('100001');
      expect(service.queries.length, queriesBefore);
      expect(opened.value.sortKey, 'online');
      expect(opened.value.searchQuery, isEmpty);
      await expectLater(
        opened.controller.confirmRoleReview(review.reviewId),
        throwsA(isA<ValidationException>()),
      );
      response.complete(
        service.commit(
          service.serverBatches[review.reservationId]!,
          service.executes.first,
        ),
      );
      await work;
      expect(service.reserves.length, 1);
      expect(service.executes.length, 3);
      expect(opened.value.roleOutcomeCounts.confirmed, 3);
      expect(opened.value.canPrepareReview, false);
      await opened.controller.closeOutstanding();
      expect(opened.value.roleWorkSealed, true);
      expect(opened.value.canPrepareReview, true);
      expect(opened.value.roleOutcomeCounts.confirmed, 3);
    },
  );
  test(
    'stored target conflict is known and later recipients can continue',
    () async {
      final service = AdminUsersFixture();
      final opened = await openAdminUsers(service);
      service.onExecute = (envelope, id) async =>
          service.commit(envelope, id, reject: service.executes.length == 1);
      opened.controller.toggleSelectAll(true);
      final review = opened.controller.prepareRoleReview('driver');
      await opened.controller.confirmRoleReview(review.reviewId);
      expect(opened.value.roleOutcomeCounts.knownRejected, 1);
      expect(opened.value.roleOutcomeCounts.confirmed, 2);
    },
  );
  for (final error in [
    const MutationOutcomeUnknownException(operation: 'rpc_admin_role_execute'),
    const ValidationException(message: 'Injected failure after commit'),
  ]) {
    test(
      'commit followed by ${error.runtimeType} stops dispatch as unknown; reconciliation never replays',
      () async {
        final service = AdminUsersFixture();
        final opened = await openAdminUsers(service);
        service.onExecute = (envelope, id) async {
          service.commit(envelope, id);
          throw error;
        };
        opened.controller.toggleSelectAll(true);
        final review = opened.controller.prepareRoleReview('driver');
        await opened.controller.confirmRoleReview(review.reviewId);
        expect(service.executes.length, 1);
        expect(opened.value.roleOutcomeCounts.unknown, 1);
        expect(opened.value.roleOutcomeCounts.notStarted, 2);
        await opened.controller.reconcileOutstanding();
        expect(opened.value.roleOutcomeCounts.confirmed, 1);
        expect(service.executes.length, 1);
        await opened.controller.closeOutstanding();
        expect(service.executes.length, 1);
        expect(opened.value.roleOutcomeCounts.notStarted, 2);
        expect(opened.value.roleWorkSealed, true);
      },
    );
  }
  test(
    'snapshot expiry uses monotonic time and blocks Confirm before any reservation',
    () async {
      final service = AdminUsersFixture();
      final opened = await openAdminUsers(service);
      opened.controller.toggleSelectAll(true);
      final review = opened.controller.prepareRoleReview('driver');
      service.elapsed = const Duration(minutes: 11);
      await expectLater(
        opened.controller.confirmRoleReview(review.reviewId),
        throwsA(isA<ValidationException>()),
      );
      expect(service.reserves, isEmpty);
      expect(opened.value.snapshotExpired, true);
    },
  );
  test(
    'query refresh failure never erases confirmed recipient evidence',
    () async {
      final service = AdminUsersFixture();
      final opened = await openAdminUsers(service);
      opened.controller.toggleSelectAll(true);
      final review = opened.controller.prepareRoleReview('driver');
      service.onPage = (_) async => throw StateError('Offline');
      await opened.controller.confirmRoleReview(review.reviewId);
      expect(opened.value.loadError, isNotNull);
      expect(opened.value.roleOutcomeCounts.confirmed, 3);
    },
  );
  test(
    'replacement SID stops remaining dispatch and clears former account rows',
    () async {
      final service = AdminUsersFixture();
      final opened = await openAdminUsers(service);
      final response = Completer<AdminRoleBatchEnvelope>();
      final started = Completer<void>();
      service.onExecute = (_, _) {
        started.complete();
        return response.future;
      };
      opened.controller.toggleSelectAll(true);
      final review = opened.controller.prepareRoleReview('driver');
      final work = opened.controller.confirmRoleReview(review.reviewId);
      await started.future;
      service.replaceSession();
      response.complete(
        service.commit(
          service.serverBatches[review.reservationId]!,
          service.executes.first,
        ),
      );
      await work;
      expect(service.executes.length, 1);
      expect(opened.value.users, isEmpty);
      expect(opened.value.roleOutcomes, isEmpty);
    },
  );
}
