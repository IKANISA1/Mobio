import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/admin/data/admin_role_change_journal.dart';
import 'package:mobi_app/features/admin/domain/admin_role_recovery.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/admin_user_protocol_fixture.dart';

void main() {
  const owner = AdminRoleRecoveryOwner(
    actorId: fixtureActor,
    hostIdentity: 'https://project.invalid',
  );
  const pointer = AdminRoleRecoveryPointer(
    owner: owner,
    reservationId: fixtureReservation,
  );
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'verified pointer stores only minimal project/actor/reservation/operation identity',
    () async {
      final journal = AdminRoleChangeJournal();
      await journal.save(pointer, ownerIsCurrent: () => true);
      final persisted = await journal.load(owner);
      expect(persisted!.reservationId, fixtureReservation);
      final prefs = await SharedPreferences.getInstance();
      final raw =
          jsonDecode(prefs.getString(AdminRoleChangeJournal.storageKey(owner))!)
              as Map;
      expect(raw.keys.toSet(), {
        'version',
        'actor_id',
        'host_identity',
        'reservation_id',
        'batch_id',
        'operation_id',
      });
      await journal.save(
        pointer.withOperation(fixtureBatch, fixtureOperation(1)),
        ownerIsCurrent: () => true,
      );
      expect((await journal.load(owner))!.operationId, fixtureOperation(1));
    },
  );
  test(
    'actor and project keys never attribute another scope recovery pointer',
    () async {
      final journal = AdminRoleChangeJournal();
      await journal.save(pointer, ownerIsCurrent: () => true);
      expect(
        await journal.load(
          const AdminRoleRecoveryOwner(
            actorId: fixtureActor,
            hostIdentity: 'https://other-project.invalid',
          ),
        ),
        isNull,
      );
      expect(
        await journal.load(
          AdminRoleRecoveryOwner(
            actorId: fixtureTarget(9),
            hostIdentity: owner.hostIdentity,
          ),
        ),
        isNull,
      );
    },
  );
  test(
    'a newer reservation cannot overwrite or clear an unresolved pointer',
    () async {
      final journal = AdminRoleChangeJournal();
      await journal.save(pointer, ownerIsCurrent: () => true);
      await expectLater(
        journal.save(
          AdminRoleRecoveryPointer(
            owner: owner,
            reservationId: fixtureTarget(9),
          ),
          ownerIsCurrent: () => true,
        ),
        throwsStateError,
      );
      await journal.clear(owner, fixtureTarget(9), ownerIsCurrent: () => true);
      expect((await journal.load(owner))!.reservationId, fixtureReservation);
      await journal.clear(
        owner,
        fixtureReservation,
        ownerIsCurrent: () => true,
      );
      expect(await journal.load(owner), isNull);
    },
  );
  test(
    'owner replacement during platform await fails verified save before dispatch',
    () async {
      var calls = 0;
      final journal = AdminRoleChangeJournal();
      await expectLater(
        journal.save(pointer, ownerIsCurrent: () => ++calls < 3),
        throwsStateError,
      );
      expect((await journal.load(owner))!.reservationId, fixtureReservation);
    },
  );
  test(
    'malformed owner-bound pointer fails closed instead of silently disappearing',
    () async {
      SharedPreferences.setMockInitialValues({
        AdminRoleChangeJournal.storageKey(owner): '{broken',
      });
      await expectLater(
        AdminRoleChangeJournal().load(owner),
        throwsFormatException,
      );
    },
  );
}
