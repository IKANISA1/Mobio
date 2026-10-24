import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/admin/application/admin_users_state.dart';

import '../fixtures/admin_user_protocol_fixture.dart';
import '../fixtures/admin_users_controller_fixture.dart';

void main() {
  test(
    'lost reserve response survives restart; absent stays unknown and seal denies delayed reserve',
    () async {
      final service = AdminUsersFixture();
      final first = await openAdminUsers(service);
      first.controller.toggleSelectAll(true);
      final plan = first.controller.prepareRoleReview('driver');
      service.onReserve = (_) async =>
          throw const MutationOutcomeUnknownException(
            operation: 'rpc_admin_role_reserve',
          );
      await first.controller.confirmRoleReview(plan.reviewId);
      expect(service.journal.pointer!.reservationId, plan.reservationId);
      first.close();
      service.onReserve = null;
      final restarted = await openAdminUsers(service);
      expect(restarted.value.recoveryPhase, AdminRoleRecoveryPhase.unresolved);
      expect(restarted.value.roleWorkSealed, false);
      expect(restarted.value.canCloseOutstanding, true);
      expect(service.reserves.length, 1);
      expect(service.executes, isEmpty);
      await restarted.controller.closeOutstanding();
      expect(restarted.value.roleWorkSealed, true);
      expect(restarted.value.canPrepareReview, true);
      expect(service.journal.pointer, isNull);
      await expectLater(service.reserveRoleChange(plan), throwsA(anything));
      expect(service.executes, isEmpty);
      expect(service.fenced, contains(plan.reservationId));
    },
  );
  test(
    'pointer loss discovers server-owned batch without replaying any prepared operation',
    () async {
      final service = AdminUsersFixture();
      final plan = fixtureReview();
      service.serverPlans[plan.reservationId] = plan;
      service.serverBatches[plan.reservationId] = fixtureEnvelope(plan);
      service.journal.pointer = null;
      final opened = await openAdminUsers(service);
      expect(opened.value.canPrepareReview, false);
      expect(opened.value.roleOutcomeCounts.unknown, 3);
      expect(service.journal.pointer!.batchId, fixtureBatch);
      expect(service.executes, isEmpty);
      await opened.controller.closeOutstanding();
      expect(opened.value.roleOutcomeCounts.notStarted, 3);
      expect(opened.value.roleWorkSealed, true);
    },
  );
  for (final oldSealed in [false, true]) {
    test(
      'retained ${oldSealed ? 'sealed' : 'absent'} token cannot hide another tab open actor batch',
      () async {
        final service = AdminUsersFixture();
        service.journal.pointer = AdminRoleRecoveryPointer(
          owner: service.roleRecoveryOwner,
          reservationId: fixtureReservation,
        );
        if (oldSealed) service.fenced.add(fixtureReservation);
        final other = fixtureReview(reservation: fixtureTarget(9));
        service.serverPlans[other.reservationId] = other;
        service.serverBatches[other.reservationId] = fixtureEnvelope(
          other,
          batch: fixtureTarget(10),
        );
        final opened = await openAdminUsers(service);
        expect(
          service.statusCalls.any(
            (call) => call.reservationId == null && call.batchId == null,
          ),
          true,
        );
        expect(opened.value.canPrepareReview, false);
        expect(opened.value.recoveryPhase, AdminRoleRecoveryPhase.unresolved);
        expect(opened.value.roleEnvelope!.batch!.batchId, fixtureTarget(10));
        if (!oldSealed) {
          expect(opened.value.outstandingReservationId, fixtureReservation);
          await opened.controller.closeOutstanding();
          expect(service.fenced, contains(fixtureReservation));
          expect(service.serverBatches[other.reservationId]!.isSealed, false);
          expect(opened.value.canPrepareReview, false);
          expect(opened.value.roleWorkSealed, false);
          expect(opened.value.roleOutcomeCounts.unknown, 3);
        }
        expect(opened.value.outstandingReservationId, other.reservationId);
        expect(service.journal.pointer!.reservationId, other.reservationId);
        expect(service.executes, isEmpty);
      },
    );
  }
  test(
    'unknown execute discovered after cold restore becomes confirmed only by receipt',
    () async {
      final service = AdminUsersFixture();
      final first = await openAdminUsers(service);
      service.onExecute = (envelope, id) async {
        service.commit(envelope, id);
        throw const MutationOutcomeUnknownException(
          operation: 'rpc_admin_role_execute',
        );
      };
      first.controller.toggleSelectAll(true);
      final review = first.controller.prepareRoleReview('driver');
      await first.controller.confirmRoleReview(review.reviewId);
      first.close();
      final restored = await openAdminUsers(service);
      expect(restored.value.roleOutcomeCounts.confirmed, 1);
      expect(service.executes.length, 1);
      expect(restored.value.canPrepareReview, false);
      await restored.controller.closeOutstanding();
      expect(restored.value.roleOutcomeCounts.confirmed, 1);
      expect(restored.value.roleOutcomeCounts.notStarted, 2);
      expect(service.executes.length, 1);
    },
  );
  test(
    'tampered prior confirmed receipt with same audit ID blocks recovery and retains evidence',
    () async {
      final service = AdminUsersFixture();
      final opened = await openAdminUsers(service);
      opened.controller.toggleSelectAll(true);
      final review = opened.controller.prepareRoleReview('driver');
      await opened.controller.confirmRoleReview(review.reviewId);
      final before = opened.value.roleOutcomes.first.receipt!;
      final raw = fixtureRoleJson(
        review,
        statuses: ['confirmed', 'confirmed', 'confirmed'],
      );
      final first = (raw['operations'] as List).first as Map;
      final changed = fixtureNow
          .add(const Duration(seconds: 2))
          .toIso8601String();
      first['decided_at'] = changed;
      (first['receipt'] as Map)['committed_at'] = changed;
      final tampered = AdminRoleBatchEnvelope.parse(
        raw,
        actorId: fixtureActor,
        sessionId: fixtureSession,
        expectedReservationId: review.reservationId,
        review: review,
      );
      service.onStatus = (_, _) async => tampered;
      await opened.controller.reconcileOutstanding();
      expect(opened.value.recoveryPhase, AdminRoleRecoveryPhase.blocked);
      expect(
        opened.value.roleOutcomes.first.receipt!.sameEvidence(before),
        true,
      );
      expect(opened.value.roleOutcomeCounts.confirmed, 3);
      expect(service.executes.length, 3);
    },
  );
  test(
    'query change during reconciliation retains its new filter and snapshot',
    () async {
      final service = AdminUsersFixture();
      final plan = fixtureReview();
      service.serverPlans[plan.reservationId] = plan;
      service.serverBatches[plan.reservationId] = fixtureEnvelope(plan);
      final opened = await openAdminUsers(service);
      final response = Completer<AdminRoleBatchEnvelope>();
      final called = Completer<void>();
      service.onStatus = (_, token) {
        if (token != null) {
          called.complete();
          return response.future;
        }
        return Future.value(fixtureEnvelope(plan));
      };
      final work = opened.controller.reconcileOutstanding();
      await called.future;
      await opened.controller.onRoleFilterChanged('driver');
      final snapshot = opened.value.snapshotId;
      response.complete(fixtureEnvelope(plan));
      await work;
      expect(opened.value.roleFilter, 'driver');
      expect(opened.value.snapshotId, snapshot);
      expect(opened.value.recoveryPhase, AdminRoleRecoveryPhase.unresolved);
      expect(service.executes, isEmpty);
    },
  );
}
