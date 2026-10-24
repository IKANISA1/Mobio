import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/admin/data/admin_service.dart';

import '../../../tool/preview_admin_user_contract.dart';

// Synthetic adapter behavior only: no hosted authority, SDK request or accepted
// production receipt is exercised or asserted by these fixtures.
void main() {
  late Duration elapsed;
  late PreviewAdminUserContract contract;
  setUp(() {
    elapsed = Duration.zero;
    contract = PreviewAdminUserContract(elapsed: () => elapsed);
  });
  Matcher failure(String code) =>
      throwsA(isA<StateError>().having((error) => error.message, 'code', code));

  test(
    'directory snapshots retain rows after role mutation and explicit release',
    () async {
      final page = await contract.page(AdminUserQuery());
      final review = _review(page);
      final reserved = await contract.reserve(review);
      final confirmed = await contract.execute(
        reserved,
        reserved.operations.single.operationId,
      );
      expect(
        confirmed.operations.single.status,
        AdminRoleOperationStatus.confirmed,
      );
      final repeated = await contract.page(page.query);
      expect(repeated.rows.single.user.role, 'passenger');
      expect(repeated.rows.single.roleRevision, 0);
      expect(repeated.rows.clear, throwsUnsupportedError);
      final release = await contract.release(page.snapshotId);
      expect(release.released, isTrue);
      expect((await contract.release(page.snapshotId)).alreadyAbsent, isTrue);
      // Cache release preserves durable synthetic operation evidence.
      final status = await contract.status(batchId: reserved.batch!.batchId);
      expect(
        status.operations.single.receipt!.sameEvidence(
          confirmed.operations.single.receipt!,
        ),
        isTrue,
      );
      final fresh = await contract.page(AdminUserQuery());
      expect(fresh.rows.single.user.role, 'driver');
      expect(fresh.rows.single.roleRevision, 1);
    },
  );

  test(
    'more than three superseded queries work only after their captured release',
    () async {
      for (final sort in [
        'online',
        'name_asc',
        'name_desc',
        'role',
        'newest',
      ]) {
        final page = await contract.page(AdminUserQuery(sort: sort));
        expect(page.query.sort, sort);
        expect(page.totalExact, 1);
        await contract.release(page.snapshotId);
      }
      final page = await contract.page(AdminUserQuery());
      await expectLater(
        contract.page(
          AdminUserQuery(snapshotId: page.snapshotId, sort: 'name_asc'),
        ),
        failure('ADMIN_USERS_SNAPSHOT_BINDING_MISMATCH'),
      );
      await expectLater(
        contract.page(
          AdminUserQuery(snapshotId: page.snapshotId, search: 'other'),
        ),
        failure('ADMIN_USERS_SNAPSHOT_BINDING_MISMATCH'),
      );
      await expectLater(
        contract.page(
          AdminUserQuery(snapshotId: page.snapshotId, pageSize: 50),
        ),
        failure('ADMIN_USERS_SNAPSHOT_BINDING_MISMATCH'),
      );
      expect(
        (await contract.page(page.query)).rows.single.user.name,
        'Chantal Rider',
      );
    },
  );

  test(
    'query cache bound and exact expiry free a slot without extending an old handle',
    () async {
      final page = await contract.page(AdminUserQuery());
      await contract.page(AdminUserQuery(sort: 'name_asc'));
      await contract.page(AdminUserQuery(sort: 'name_desc'));
      await expectLater(
        contract.page(AdminUserQuery(sort: 'role')),
        failure('ADMIN_USERS_SNAPSHOT_LIMIT'),
      );
      elapsed = const Duration(minutes: 10);
      await expectLater(
        contract.page(page.query),
        failure('ADMIN_USERS_SNAPSHOT_NOT_FOUND'),
      );
      expect(
        (await contract.page(AdminUserQuery(sort: 'role'))).asOf,
        page.asOf.add(const Duration(minutes: 10)),
      );
    },
  );

  test(
    'review tuples must match the frozen row and exact synthetic owner',
    () async {
      final page = await contract.page(AdminUserQuery());
      final review = _review(page, revision: 8);
      await expectLater(
        contract.reserve(review),
        failure('ADMIN_ROLE_ARGUMENT_INVALID'),
      );
      await expectLater(
        contract.reserve(
          _review(page, actor: '99999999-9999-4999-8999-999999999999'),
        ),
        failure('ADMIN_ROLE_SESSION_CHANGED'),
      );
      await expectLater(
        contract.reserve(
          _review(page, session: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
        ),
        failure('ADMIN_ROLE_SESSION_CHANGED'),
      );
      expect((await contract.status()).batch, isNull);
      expect(
        (await contract.page(page.query)).rows.single.user.role,
        'passenger',
      );
    },
  );

  test(
    'reserve exact replay preserves operation IDs and rejects conflicting input',
    () async {
      final page = await contract.page(AdminUserQuery());
      final review = _review(page);
      final reserved = await contract.reserve(review);
      final replay = await contract.reserve(review);
      expect(replay.batch!.sameImmutableTuple(reserved.batch!), isTrue);
      expect(
        replay.operations.single.operationId,
        reserved.operations.single.operationId,
      );
      expect(replay.operations.clear, throwsUnsupportedError);
      await expectLater(
        contract.reserve(_review(page, requested: 'admin')),
        failure('ADMIN_ROLE_RESERVATION_CONFLICT'),
      );
    },
  );

  test(
    'confirmed receipts survive duplicate execute and explicit close',
    () async {
      final page = await contract.page(AdminUserQuery());
      final reserved = await contract.reserve(_review(page));
      final operation = reserved.operations.single.operationId;
      final confirmed = await contract.execute(reserved, operation);
      final duplicate = await contract.execute(reserved, operation);
      expect(
        duplicate.operations.single.receipt!.sameEvidence(
          confirmed.operations.single.receipt!,
        ),
        isTrue,
      );
      final sealed = await contract.seal(batchId: reserved.batch!.batchId);
      expect(sealed.isSealed, isTrue);
      expect(
        sealed.operations.single.status,
        AdminRoleOperationStatus.confirmed,
      );
      expect(
        sealed.operations.single.receipt!.sameEvidence(
          confirmed.operations.single.receipt!,
        ),
        isTrue,
      );
      expect((await contract.status()).batch, isNull);
      await expectLater(
        contract.execute(sealed, operation),
        failure('ADMIN_ROLE_BATCH_SEALED'),
      );
    },
  );

  test(
    'seal cancels unexecuted work and old reply cannot submit after the fence',
    () async {
      final reserved = await contract.reserve(
        _review(await contract.page(AdminUserQuery())),
      );
      final sealed = await contract.seal(reservationId: reserved.reservationId);
      expect(
        sealed.operations.single.status,
        AdminRoleOperationStatus.notStarted,
      );
      expect(sealed.operations.single.decidedAt, sealed.batch!.sealedAt);
      await expectLater(
        contract.execute(reserved, reserved.operations.single.operationId),
        failure('ADMIN_ROLE_BATCH_SEALED'),
      );
      expect(
        (await contract.page(AdminUserQuery())).rows.single.user.role,
        'passenger',
      );
    },
  );

  test(
    'missing reserve stays absent until an explicit reservation fence',
    () async {
      final review = _review(await contract.page(AdminUserQuery()));
      final absent = await contract.status(reservationId: review.reservationId);
      expect(absent.reservationState, AdminRoleReservationState.absent);
      expect(absent.reservationId, review.reservationId);
      expect(absent.isSealed, isFalse);
      final closed = await contract.seal(reservationId: review.reservationId);
      expect(
        closed.reservationState,
        AdminRoleReservationState.sealedBeforeReserve,
      );
      expect(closed.batch, isNull);
      expect(closed.operations, isEmpty);
      await expectLater(
        contract.reserve(review),
        failure('ADMIN_ROLE_RESERVATION_SEALED'),
      );
    },
  );

  test(
    'a fresh synthetic instance cannot inherit another instance operation',
    () async {
      final reserved = await contract.reserve(
        _review(await contract.page(AdminUserQuery())),
      );
      final replacement = PreviewAdminUserContract(elapsed: () => elapsed);
      expect((await replacement.status()).batch, isNull);
      await expectLater(
        replacement.execute(reserved, reserved.operations.single.operationId),
        failure('ADMIN_ROLE_BATCH_NOT_FOUND'),
      );
    },
  );

  test(
    'operation expiry rejects execute while recovery can seal without role mutation',
    () async {
      final reserved = await contract.reserve(
        _review(await contract.page(AdminUserQuery())),
      );
      elapsed = const Duration(minutes: 10);
      await expectLater(
        contract.execute(reserved, reserved.operations.single.operationId),
        failure('ADMIN_ROLE_BATCH_EXPIRED'),
      );
      expect((await contract.status()).batch!.batchId, reserved.batch!.batchId);
      final closed = await contract.seal(batchId: reserved.batch!.batchId);
      expect(
        closed.operations.single.status,
        AdminRoleOperationStatus.notStarted,
      );
    },
  );
}

AdminRoleReview _review(
  AdminUserPage page, {
  int? revision,
  String requested = 'driver',
  String actor = PreviewAdminUserContract.actorId,
  String session = PreviewAdminUserContract.sessionId,
}) {
  final row = page.rows.single;
  return AdminRoleReview(
    reviewId: '44444444-4444-4444-8444-444444444444',
    reservationId: '55555555-5555-4555-8555-555555555555',
    actorId: actor,
    sessionId: session,
    snapshotId: page.snapshotId,
    requestedRole: requested,
    entries: [
      AdminRoleReviewEntry(
        targetId: row.user.id,
        displayLabel: row.user.name,
        memberId: row.user.memberId,
        expectedRole: row.user.role,
        expectedRevision: revision ?? row.roleRevision,
        expectedIsDriver: row.user.isDriver,
        requestedRole: requested,
        requestedIsDriver: requested == 'driver',
        skipReason: row.user.role == requested
            ? AdminRoleSkipReason.sameRole
            : null,
      ),
    ],
  );
}
