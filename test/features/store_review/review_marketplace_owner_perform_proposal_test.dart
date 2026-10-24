import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/review_session_context.dart';
import 'package:mobi_app/features/store_review/application/review_marketplace_owner.dart';
import 'package:mobi_app/features/store_review/domain/review_world_authority.dart';

// PRIVATE PROPOSAL: these tests bind the separately staged owner contract.
// No callback sandbox/void-async safety or hosted authorization is asserted.
void main() {
  _OwnerFixture fixture() {
    final result = _OwnerFixture();
    addTearDown(result.dispose);
    return result;
  }

  final unavailable = throwsA(isA<ReviewWorldUnavailable>());

  test('read command publishes no data-change notification', () {
    final f = fixture();
    final action = f.owner.captureAction();
    var notifications = 0;
    f.owner.addListener(() => notifications++);
    final profile = f.owner.perform(
      action,
      (store) => store.getProfile(action),
    );
    expect(profile.displayName, 'Review member');
    expect(notifications, 0);
  });

  test('one local change publishes the committed immutable revision', () {
    final f = fixture();
    final action = f.owner.captureAction();
    final before = f.owner.store.snapshot(action);
    final revisions = <int>[];
    f.owner.addListener(
      () => revisions.add(f.owner.store.snapshot(action).revision),
    );
    f.owner.perform(
      action,
      (store) => store.editProfile(action, displayName: 'Updated'),
    );
    expect(revisions, [before.revision + 1]);
    expect(before.profile.displayName, 'Review member');
    expect(f.owner.store.getProfile(action).displayName, 'Updated');
  });

  test(
    'void local read-state command publishes only actual revision changes',
    () {
      final f = fixture();
      final action = f.owner.captureAction();
      final before = f.owner.store.snapshot(action);
      var notifications = 0;
      f.owner.addListener(() => notifications++);
      f.owner.perform<void>(action, (store) => store.markInboxRead(action));
      expect(f.owner.store.snapshot(action).unreadInbox, 0);
      expect(f.owner.store.snapshot(action).revision, before.revision + 1);
      expect(notifications, 1);
    },
  );

  test('foreign owner action fails before a callback can run', () {
    final first = fixture(), second = fixture();
    final action = first.owner.captureAction();
    var called = false;
    expect(
      () => second.owner.perform(action, (_) => called = true),
      unavailable,
    );
    expect(called, false);
    expect(
      second.owner.store.snapshot(second.owner.captureAction()).revision,
      0,
    );
  });

  test('pending and renewed stale actions cannot publish a local command', () {
    final f = fixture();
    final action = f.owner.captureAction();
    final ticket = f.context.beginValidation();
    var called = false;
    expect(() => f.owner.perform(action, (_) => called = true), unavailable);
    f.context.acceptStatus(ticket, f.status());
    expect(() => f.owner.perform(action, (_) => called = true), unavailable);
    expect(called, false);
    f.owner.perform(f.owner.captureAction(), (_) => 1);
  });

  test('throw without local change publishes nothing', () {
    final f = fixture();
    final action = f.owner.captureAction();
    var notifications = 0;
    f.owner.addListener(() => notifications++);
    expect(
      () => f.owner.perform<int>(action, (_) => throw StateError('fixture')),
      throwsStateError,
    );
    expect(f.owner.store.snapshot(action).revision, 0);
    expect(notifications, 0);
  });

  test(
    'throw after completed local mutation publishes rather than implying rollback',
    () {
      final f = fixture();
      final action = f.owner.captureAction();
      var notifications = 0;
      f.owner.addListener(() => notifications++);
      expect(
        () => f.owner.perform<int>(action, (store) {
          store.editProfile(action, displayName: 'Already committed locally');
          throw StateError('fixture');
        }),
        throwsStateError,
      );
      expect(
        f.owner.store.getProfile(action).displayName,
        'Already committed locally',
      );
      expect(notifications, 1);
    },
  );

  test('revocation during callback fails the final exact-action check', () {
    final f = fixture();
    final action = f.owner.captureAction();
    expect(
      () => f.owner.perform<int>(action, (_) {
        f.context.invalidate();
        return 7;
      }),
      unavailable,
    );
    expect(f.owner.store.hasWorld, false);
    expect(f.owner.captureAction, unavailable);
  });

  test(
    'visible Future and Stream results diagnose misuse without claiming cancellation',
    () {
      final f = fixture();
      final action = f.owner.captureAction();
      expect(
        () => f.owner.perform<Object>(action, (_) => Future.value(1)),
        unavailable,
      );
      expect(
        () => f.owner.perform<Object>(action, (_) => const Stream<int>.empty()),
        unavailable,
      );
      expect(f.owner.store.snapshot(action).revision, 0);
    },
  );

  test(
    'visible async misuse cannot retract already committed local changes',
    () {
      final f = fixture();
      final action = f.owner.captureAction();
      var notifications = 0;
      f.owner.addListener(() => notifications++);
      expect(
        () => f.owner.perform<Object>(action, (store) {
          store.editProfile(
            action,
            displayName: 'Local effect survives diagnosis',
          );
          return Future.value(1);
        }),
        unavailable,
      );
      expect(
        f.owner.store.getProfile(action).displayName,
        'Local effect survives diagnosis',
      );
      expect(notifications, 1);
    },
  );

  test(
    'current conservative server bound advances without device wall time',
    () {
      final f = fixture();
      final ticket = f.context.beginValidation();
      f.elapsed = const Duration(seconds: 10);
      f.context.acceptStatus(ticket, f.status());
      expect(
        f.owner.serverTimeUpperBound,
        DateTime.utc(2026, 10, 2, 10, 0, 10),
      );
      f.elapsed = const Duration(seconds: 17);
      expect(
        f.owner.serverTimeUpperBound,
        DateTime.utc(2026, 10, 2, 10, 0, 17),
      );
      f.context.invalidate();
      expect(f.owner.serverTimeUpperBound, isNull);
    },
  );
}

class _OwnerFixture {
  _OwnerFixture() {
    context = ReviewSessionContext(
      readTransport: () => _identity,
      elapsedTime: () => elapsed,
    );
    context.acceptStatus(context.beginValidation(), status());
    owner = ReviewMarketplaceOwner(
      context: context,
      issuer: 'https://review.supabase.co',
      elapsed: () => elapsed,
    );
  }
  static const _identity = ReviewTransportIdentity(
    '11111111-1111-4111-8111-111111111111',
    '22222222-2222-4222-8222-222222222222',
  );
  Duration elapsed = Duration.zero;
  late final ReviewSessionContext context;
  late final ReviewMarketplaceOwner owner;
  Map<String, Object> status() => {
    'active': true,
    'mode': 'synthetic_review',
    'user_id': _identity.userId,
    'session_id': _identity.sessionId,
    'role': 'driver',
    'generation': 3,
    'fixture_version': ReviewSessionLease.supportedFixtureVersion,
    'authenticated_at': '2026-10-02T09:59:00Z',
    'server_now': '2026-10-02T10:00:00Z',
    'expires_at': '2026-10-02T10:10:00Z',
  };
  void dispose() {
    owner.dispose();
    context.dispose();
  }
}
