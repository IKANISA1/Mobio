import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/review_session_context.dart';
import 'package:mobi_app/features/store_review/application/review_marketplace_owner.dart';
import 'package:mobi_app/features/store_review/domain/review_world_authority.dart';
import 'package:mobi_app/features/store_review/domain/review_world_models.dart';

const _identity = ReviewTransportIdentity(
  '11111111-1111-4111-8111-111111111111',
  '22222222-2222-4222-8222-222222222222',
);
const _other = ReviewTransportIdentity(
  '33333333-3333-4333-8333-333333333333',
  '44444444-4444-4444-8444-444444444444',
);
final _anchor = DateTime.utc(2026, 10, 1, 10, 1);

void main() {
  _Fixture fixture({
    bool acceptedBeforeOwner = false,
    Duration ownerDelay = Duration.zero,
    String issuer = 'https://review.supabase.co',
    void Function(_Fixture)? beforeOwner,
  }) {
    final result = _Fixture(
      acceptedBeforeOwner: acceptedBeforeOwner,
      ownerDelay: ownerDelay,
      issuer: issuer,
      beforeOwner: beforeOwner,
    );
    addTearDown(result.dispose);
    return result;
  }

  Matcher unavailable() => throwsA(isA<ReviewWorldUnavailable>());

  test('transport and ordinary status cannot grant an owner action', () {
    final f = fixture();
    expect(f.owner.hasTransport, true);
    expect(f.owner.phase, ReviewWorldPhase.locked);
    expect(f.owner.captureAction, unavailable());
    final ticket = f.context.beginValidation();
    expect(f.owner.captureAction, unavailable());
    expect(
      () => f.context.acceptStatus(ticket, f.status()..['mode'] = 'ordinary'),
      throwsA(isA<ReviewAccessUnavailable>()),
    );
    f.context.rejectStatus(ticket);
    expect(f.owner.store.hasWorld, false);
    expect(f.owner.captureAction, unavailable());
  });

  test(
    'Admin and unsupported server role cannot grant a world or local mode',
    () {
      final f = fixture();
      for (final role in ['admin', 'moderator', 'Driver']) {
        final ticket = f.context.beginValidation();
        expect(
          () => f.context.acceptStatus(ticket, f.status()..['role'] = role),
          throwsA(isA<ReviewAccessUnavailable>()),
        );
        f.context.rejectStatus(ticket);
        expect(f.owner.store.hasWorld, false);
        expect(f.owner.captureAction, unavailable());
      }
      f.activate();
      final action = f.owner.captureAction();
      expect(
        () => f.owner.store.setMode(action, MarketplaceRole.driver),
        unavailable(),
      );
      expect(f.snapshot().mode, MarketplaceRole.passenger);
      expect(f.snapshot().profile.isAdmin, false);
    },
  );

  test(
    'construction synchronizes an accepted lease and delayed server time',
    () {
      final f = fixture(
        acceptedBeforeOwner: true,
        ownerDelay: const Duration(seconds: 7),
        issuer: 'https://REVIEW.supabase.co/',
      );
      final world = f.snapshot();
      expect(f.owner.issuer, 'https://review.supabase.co');
      expect(world.binding.userId, _identity.userId);
      expect(world.binding.sessionId, _identity.sessionId);
      expect(world.binding.generation, 3);
      expect(world.binding.fixtureVersion, 'mobio-marketplace-v1');
      expect(world.anchor, _anchor.add(const Duration(seconds: 7)));
      expect(f.owner.remaining, const Duration(seconds: 53));
      expect(world.profile.isDriver, false);
      expect(world.profile.isAdmin, false);
    },
  );

  test('issuer validation rejects altered origins before status exists', () {
    final f = fixture();
    for (final issuer in [
      'http://review.supabase.co',
      ' https://review.supabase.co',
      'https://review.supabase.co/auth/v1',
      'https://review.supabase.co/../',
      'https://review.supabase.co/%2E%2E/',
      'https://actor@review.supabase.co',
      'https://review.supabase.co?project=other',
      'https://review.supabase.co#other',
      'https://review.supabase.co:0',
    ]) {
      expect(
        () => ReviewMarketplaceOwner(context: f.context, issuer: issuer),
        unavailable(),
        reason: issuer,
      );
    }
    f.activate();
    expect(f.owner.phase, ReviewWorldPhase.active);
  });

  test('priority owner quarantine precedes older general UI listeners', () {
    // Register UI first to prove order does not depend on registration order.
    final observations = <String>[];
    final f = fixture(
      beforeOwner: (current) => current.context.addListener(() {
        observations.add('ui:${current.owner.phase.name}');
        if (current.context.pending) {
          expect(current.owner.captureAction, unavailable());
        }
      }),
    );
    f.owner.addListener(() => observations.add('owner:${f.owner.phase.name}'));
    f.activate();
    final oldAction = f.owner.captureAction();
    observations.clear();
    final ticket = f.context.beginValidation();
    expect(observations, ['owner:quarantined', 'ui:quarantined']);
    expect(oldAction.requireCurrent, unavailable());
    f.context.acceptStatus(ticket, f.status());
    expect(observations, [
      'owner:quarantined',
      'ui:quarantined',
      'owner:active',
      'ui:active',
    ]);
    expect(oldAction.requireCurrent, unavailable());
  });

  test('same binding renewal retains posts chat and unread state', () {
    final f = fixture()..activate();
    final action = f.owner.captureAction();
    final store = f.owner.store
      ..editProfile(action, displayName: 'Local reviewer');
    final post = store.createTrip(action, f.trip('Retain this post'));
    final conversation = store.listConversations(action).single;
    final message = store.sendMessage(action, conversation.id, 'Retain chat');
    store
      ..markConversationRead(action, conversation.id)
      ..markInboxRead(action);
    final before = store.snapshot(action);
    final ticket = f.context.beginValidation();
    expect(store.hasWorld, true);
    expect(f.owner.phase, ReviewWorldPhase.quarantined);
    expect(() => store.snapshot(action), unavailable());
    f.elapsed = const Duration(seconds: 5);
    f.context.acceptStatus(ticket, f.status());
    final after = f.snapshot();
    expect(after.worldInstance, before.worldInstance);
    expect(after.revision, before.revision);
    expect(after.profile.displayName, 'Local reviewer');
    expect(after.trips[post.id]!.note, 'Retain this post');
    expect(after.messages[conversation.id]!.last.id, message.id);
    expect(after.unreadMessages, 0);
    expect(after.unreadInbox, 0);
    expect(action.requireCurrent, unavailable());
  });

  for (final identity in [
    _other,
    ReviewTransportIdentity(_identity.userId, _other.sessionId),
  ]) {
    test(
      'pending ${identity.key} replacement clears before UI observes it',
      () {
        final f = fixture()..activate();
        final oldAction = f.owner.captureAction();
        f.owner.store.editProfile(oldAction, displayName: 'Must clear');
        final before = f.snapshot();
        var observed = false;
        f.context.addListener(() {
          if (f.context.pending) {
            observed = true;
            expect(f.owner.store.hasWorld, false);
            expect(f.owner.phase, ReviewWorldPhase.locked);
          }
        });
        f.transport = identity;
        final ticket = f.context.beginValidation();
        expect(observed, true);
        expect(
          f.owner.store.lastClearReason,
          ReviewWorldClearReason.replacement,
        );
        f.context.acceptStatus(ticket, f.status());
        final after = f.snapshot();
        expect(after.binding.userId, identity.userId);
        expect(after.binding.sessionId, identity.sessionId);
        expect(after.worldInstance, greaterThan(before.worldInstance));
        expect(after.profile.displayName, 'Review member');
        expect(after.revision, 0);
        expect(oldAction.requireCurrent, unavailable());
      },
    );
  }

  for (final replacement in ['generation', 'role']) {
    test('$replacement replacement starts a new immutable world', () {
      final f = fixture()..activate();
      final action = f.owner.captureAction();
      f.owner.store.editProfile(action, displayName: 'Old world');
      final before = f.snapshot();
      final ticket = f.context.beginValidation();
      final status = f.status();
      status[replacement] = replacement == 'generation' ? 4 : 'driver';
      f.context.acceptStatus(ticket, status);
      final after = f.snapshot();
      expect(after.worldInstance, greaterThan(before.worldInstance));
      expect(after.profile.displayName, 'Review member');
      expect(after.profile.isDriver, replacement == 'role');
      expect(after.profile.isAdmin, false);
      expect(after.revision, 0);
      expect(action.requireCurrent, unavailable());
    });
  }

  test('different project owners never accept each other\'s opaque action', () {
    final first = fixture()..activate();
    final second = fixture(issuer: 'https://other.supabase.co')..activate();
    final action = first.owner.captureAction();
    expect(
      first.snapshot().binding.sameWorld(second.snapshot().binding),
      false,
    );
    expect(() => second.owner.store.snapshot(action), unavailable());
    expect(
      () => second.owner.store.editProfile(action, displayName: 'Foreign'),
      unavailable(),
    );
    expect(second.snapshot().revision, 0);
    expect(first.snapshot().revision, 0);
  });

  test(
    'status failure clears quarantine before UI and fresh status cannot retain it',
    () {
      final f = fixture()..activate();
      f.owner.store.editProfile(
        f.owner.captureAction(),
        displayName: 'Discard',
      );
      final before = f.snapshot();
      final ticket = f.context.beginValidation();
      var terminalObserved = false;
      f.context.addListener(() {
        if (!f.context.pending && !f.context.hasAccess) {
          terminalObserved = true;
          expect(f.owner.store.hasWorld, false);
        }
      });
      f.context.rejectStatus(ticket);
      expect(terminalObserved, true);
      expect(
        f.owner.store.lastClearReason,
        ReviewWorldClearReason.statusFailure,
      );
      f.activate();
      expect(f.snapshot().worldInstance, greaterThan(before.worldInstance));
      expect(f.snapshot().profile.displayName, 'Review member');
    },
  );

  for (final transition in ['logout', 'background']) {
    test('$transition invalidation drops retained memory and old callbacks', () {
      final f = fixture()..activate();
      final action = f.owner.captureAction();
      f.owner.store.editProfile(action, displayName: 'Transient');
      final before = f.snapshot();
      if (transition == 'logout') f.transport = null;
      // App lifecycle/auth composition calls the same fail-closed invalidation.
      f.context.invalidate();
      expect(f.owner.store.hasWorld, false);
      expect(f.owner.captureAction, unavailable());
      expect(action.requireCurrent, unavailable());
      f
        ..transport = _identity
        ..activate();
      expect(f.snapshot().worldInstance, greaterThan(before.worldInstance));
      expect(f.snapshot().profile.displayName, 'Review member');
    });
  }

  test(
    'request elapsed and delayed reads preserve conservative time and expiry',
    () {
      final f = fixture();
      final ticket = f.context.beginValidation();
      f.elapsed = const Duration(seconds: 10);
      f.context.acceptStatus(ticket, f.status(serverNow: _anchor));
      expect(f.owner.remaining, const Duration(seconds: 50));
      expect(f.snapshot().anchor, _anchor.add(const Duration(seconds: 10)));
      f.elapsed = const Duration(seconds: 17);
      expect(f.owner.remaining, const Duration(seconds: 43));
      final currentServerUpper = _anchor.add(const Duration(seconds: 17));
      expect(
        () => f.owner.store.createTrip(
          f.owner.captureAction(),
          f.trip('Past upper bound', departureAt: currentServerUpper),
        ),
        unavailable(),
      );
      f.owner.store.createTrip(
        f.owner.captureAction(),
        f.trip(
          'Beyond upper bound',
          departureAt: currentServerUpper.add(const Duration(seconds: 1)),
        ),
      );
      f.elapsed = const Duration(seconds: 59, microseconds: 999999);
      f.owner.captureAction().requireCurrent();
      expect(f.owner.remaining, const Duration(microseconds: 1));
      final oldAction = f.owner.captureAction();
      f.elapsed = const Duration(minutes: 1);
      expect(f.owner.remaining, Duration.zero);
      expect(f.owner.store.hasWorld, false);
      expect(f.owner.store.lastClearReason, ReviewWorldClearReason.expiry);
      expect(oldAction.requireCurrent, unavailable());
    },
  );

  test(
    'pending validation cannot retain data past the old expiry boundary',
    () {
      final f = fixture()..activate();
      final before = f.snapshot();
      final ticket = f.context.beginValidation();
      f.elapsed = const Duration(minutes: 1);
      expect(f.owner.phase, ReviewWorldPhase.locked);
      expect(f.owner.store.lastClearReason, ReviewWorldClearReason.expiry);
      final fresh = f.status(
        serverNow: _anchor.add(const Duration(minutes: 1)),
        expiresAt: _anchor.add(const Duration(minutes: 4)),
      );
      f.context.acceptStatus(ticket, fresh);
      expect(f.snapshot().worldInstance, greaterThan(before.worldInstance));
      expect(f.snapshot().revision, 0);
    },
  );

  test(
    'backwards monotonic clock clears before UI and cannot resume old data',
    () {
      final f = fixture()
        ..elapsed = const Duration(seconds: 20)
        ..activate();
      final oldAction = f.owner.captureAction();
      final before = f.snapshot();
      f.elapsed = const Duration(seconds: 21);
      expect(f.owner.remaining, const Duration(seconds: 39));
      f.elapsed = const Duration(seconds: 20);
      expect(f.context.hasAccess, false);
      expect(f.owner.store.hasWorld, false);
      expect(f.owner.store.lastClearReason, ReviewWorldClearReason.clockReset);
      expect(oldAction.requireCurrent, unavailable());
      expect(
        f.context.beginValidation,
        throwsA(isA<ReviewAccessUnavailable>()),
      );
      f
        ..elapsed = const Duration(seconds: 22)
        ..activate();
      expect(f.snapshot().worldInstance, greaterThan(before.worldInstance));
    },
  );

  test(
    'transport loss detected through the core proof clears synchronously',
    () {
      final f = fixture()..activate();
      final action = f.owner.captureAction();
      f.transport = _other;
      expect(action.requireCurrent, unavailable());
      expect(f.owner.store.hasWorld, false);
      expect(f.owner.captureAction, unavailable());
    },
  );

  test('late failure from a replaced ticket cannot erase the newer world', () {
    final f = fixture()..activate();
    final old = f.context.beginValidation();
    f
      ..transport = _other
      ..activate();
    final nextAction = f.owner.captureAction();
    f.owner.store.editProfile(nextAction, displayName: 'New actor');
    f.context.rejectStatus(old);
    expect(f.owner.store.getProfile(nextAction).displayName, 'New actor');
    expect(f.snapshot().binding.userId, _other.userId);
  });

  test('context disposal clears before a general owner notification', () {
    final f = fixture()..activate();
    final action = f.owner.captureAction();
    var observed = false;
    f.owner.addListener(() {
      observed = true;
      expect(f.owner.store.hasWorld, false);
    });
    f.disposeContext();
    expect(observed, true);
    expect(action.requireCurrent, unavailable());
    expect(f.owner.hasTransport, false);
  });

  test('owner disposal detaches and permanently disposes only its store', () {
    final f = fixture()..activate();
    final action = f.owner.captureAction();
    var notifications = 0;
    f.owner.addListener(() => notifications++);
    f.owner.dispose();
    expect(f.owner.store.lastClearReason, ReviewWorldClearReason.disposed);
    expect(action.requireCurrent, unavailable());
    f.context.invalidate();
    f.activate();
    expect(f.context.hasAccess, true);
    expect(notifications, 0);
    expect(f.owner.captureAction, unavailable());
    expect(f.owner.store.lastClearReason, ReviewWorldClearReason.disposed);
  });
}

class _Fixture {
  _Fixture({
    required bool acceptedBeforeOwner,
    required Duration ownerDelay,
    required String issuer,
    void Function(_Fixture)? beforeOwner,
  }) {
    context = ReviewSessionContext(
      readTransport: () => transport,
      elapsedTime: () => elapsed,
    );
    if (acceptedBeforeOwner) activate();
    elapsed += ownerDelay;
    beforeOwner?.call(this);
    owner = ReviewMarketplaceOwner(
      context: context,
      issuer: issuer,
      elapsed: () => elapsed,
    );
  }
  ReviewTransportIdentity? transport = _identity;
  Duration elapsed = Duration.zero;
  late final ReviewSessionContext context;
  late final ReviewMarketplaceOwner owner;
  bool _contextDisposed = false;

  Map<String, Object> status({DateTime? serverNow, DateTime? expiresAt}) => {
    'active': true,
    'mode': 'synthetic_review',
    'user_id': transport!.userId,
    'session_id': transport!.sessionId,
    'role': 'passenger',
    'generation': 3,
    'fixture_version': ReviewSessionLease.supportedFixtureVersion,
    'authenticated_at': _anchor
        .subtract(const Duration(minutes: 1))
        .toIso8601String(),
    'server_now': (serverNow ?? _anchor.add(elapsed)).toIso8601String(),
    'expires_at': (expiresAt ?? _anchor.add(const Duration(minutes: 1)))
        .toIso8601String(),
  };

  void activate() => context.acceptStatus(context.beginValidation(), status());
  ReviewWorldSnapshot snapshot() => owner.store.snapshot(owner.captureAction());
  ReviewTripDraft trip(String note, {DateTime? departureAt}) {
    final places = snapshot().places.keys.toList();
    return ReviewTripDraft(
      originPlaceId: places[0],
      destinationPlaceId: places[1],
      departureAt: departureAt ?? _anchor.add(const Duration(minutes: 2)),
      role: MarketplaceRole.passenger,
      note: note,
    );
  }

  void disposeContext() {
    if (_contextDisposed) return;
    _contextDisposed = true;
    context.dispose();
  }

  void dispose() {
    owner.dispose();
    disposeContext();
  }
}
