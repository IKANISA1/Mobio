import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/admin/domain/admin_role_change.dart';

import '../fixtures/admin_user_protocol_fixture.dart';

void main() {
  test(
    'confirmed receipt proves exact immutable reviewed tuple and origin session',
    () {
      final review = fixtureReview();
      final envelope = fixtureEnvelope(
        review,
        statuses: ['confirmed', 'known_rejected', 'prepared'],
      );
      expect(envelope.operations.first.receipt!.afterRole, 'driver');
      expect(envelope.operations[1].rejectionCode, 'target_changed');
      expect(envelope.operations.last.receipt, isNull);
    },
  );
  for (final mutation in [
    'target',
    'revision',
    'session',
    'driver',
    'missing',
    'ordinal',
    'skip',
  ]) {
    test('rejects malformed recipient receipt: $mutation', () {
      final review = fixtureReview();
      final raw = fixtureRoleJson(
        review,
        statuses: ['confirmed', 'prepared', 'prepared'],
      );
      final operation = (raw['operations'] as List).first as Map;
      final receipt = operation['receipt'] as Map;
      switch (mutation) {
        case 'target':
          receipt['target_id'] = fixtureTarget(9);
        case 'revision':
          receipt['before_revision'] = 9;
        case 'session':
          receipt['session_id'] = fixtureNextSession;
        case 'driver':
          receipt['after_is_driver'] = false;
        case 'missing':
          operation['receipt'] = null;
        case 'ordinal':
          operation['ordinal'] = 2;
        case 'skip':
          operation['skip_reason'] = 'same_role';
      }
      expect(
        () => AdminRoleBatchEnvelope.parse(
          raw,
          actorId: fixtureActor,
          sessionId: fixtureSession,
          expectedReservationId: review.reservationId,
          review: review,
        ),
        throwsFormatException,
      );
    });
  }
  test(
    'complete receipt and immutable batch comparison catches valid-looking tampering',
    () {
      final review = fixtureReview();
      final previous = fixtureEnvelope(
        review,
        statuses: ['confirmed', 'prepared', 'prepared'],
      );
      final raw = fixtureRoleJson(
        review,
        statuses: ['confirmed', 'confirmed', 'prepared'],
      );
      final operation = (raw['operations'] as List).first as Map;
      final revised = fixtureNow
          .add(const Duration(seconds: 2))
          .toIso8601String();
      operation['decided_at'] = revised;
      (operation['receipt'] as Map)['committed_at'] = revised;
      final next = AdminRoleBatchEnvelope.parse(
        raw,
        actorId: fixtureActor,
        sessionId: fixtureSession,
        review: review,
      );
      expect(
        next.operations.first.receipt!.auditId,
        previous.operations.first.receipt!.auditId,
      );
      expect(next.continues(previous), false);
      final shifted = fixtureRoleJson(
        review,
        statuses: ['confirmed', 'prepared', 'prepared'],
      );
      (shifted['batch'] as Map)['execute_expires_at'] = fixtureNow
          .add(const Duration(minutes: 9))
          .toIso8601String();
      expect(
        AdminRoleBatchEnvelope.parse(
          shifted,
          actorId: fixtureActor,
          sessionId: fixtureSession,
          review: review,
        ).continues(previous),
        false,
      );
    },
  );
  test(
    'prepared after a lost execute stays unknown until authoritative seal',
    () {
      final review = fixtureReview();
      final prepared = fixtureEnvelope(review).operations.first;
      final uncertain = AdminRoleRecipientOutcome(
        entry: prepared.entry,
        operationId: prepared.operationId,
        status: AdminRoleOutcomeStatus.unknown,
      );
      expect(
        AdminRoleRecipientOutcome.fromOperation(
          prepared,
          previous: uncertain,
        ).status,
        AdminRoleOutcomeStatus.unknown,
      );
      final sealed = fixtureEnvelope(review, sealed: true).operations.first;
      expect(
        AdminRoleRecipientOutcome.fromOperation(
          sealed,
          previous: uncertain,
        ).status,
        AdminRoleOutcomeStatus.notStarted,
      );
    },
  );
  test(
    'absent is not cancellation; sealed-before-reserve binds exact actor/token',
    () {
      final absent = AdminRoleBatchEnvelope.parse(
        fixtureEmptyRoleJson(reservation: fixtureReservation),
        actorId: fixtureActor,
        sessionId: fixtureSession,
        expectedReservationId: fixtureReservation,
      );
      expect(absent.isSealed, false);
      final sealed = AdminRoleBatchEnvelope.parse(
        fixtureEmptyRoleJson(reservation: fixtureReservation, sealed: true),
        actorId: fixtureActor,
        sessionId: fixtureSession,
        expectedReservationId: fixtureReservation,
      );
      expect(sealed.isSealed, true);
      expect(sealed.operations, isEmpty);
      expect(
        () => AdminRoleBatchEnvelope.parse(
          fixtureEmptyRoleJson(reservation: fixtureReservation, sealed: true),
          actorId: fixtureActor,
          sessionId: fixtureSession,
          expectedReservationId: fixtureSnapshot,
        ),
        throwsFormatException,
      );
    },
  );
}
