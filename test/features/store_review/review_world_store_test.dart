import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/chat/domain/chat_message.dart';
import 'package:mobi_app/features/store_review/domain/review_marketplace_store.dart';
import 'package:mobi_app/features/store_review/domain/review_world_authority.dart';
import 'package:mobi_app/features/store_review/domain/review_world_models.dart';
import 'package:mobi_shared_types/models/trip.dart';

// Pure domain fixtures use the existing test harness only. They issue no SDK,
// backend, native/plugin or provider requests and assert no hosted authority.
void main() {
  Matcher unavailable([String? code]) => throwsA(
    isA<ReviewWorldUnavailable>().having(
      (error) => code == null ? null : error.code,
      'code',
      code,
    ),
  );

  test('binding accepts only HTTPS origin and supported fixture identity', () {
    final canonical = _binding();
    expect(
      _binding(issuer: 'https://review.supabase.co/').sameWorld(canonical),
      isTrue,
    );
    expect(
      _binding(issuer: 'https://other.supabase.co').sameWorld(canonical),
      isFalse,
    );
    expect(
      _binding(issuer: 'https://review.supabase.co:444').sameWorld(canonical),
      isFalse,
    );
    for (final issuer in [
      'http://review.supabase.co',
      ' https://review.supabase.co',
      'https://review.supabase.co/auth/v1',
      'https://review.supabase.co/../',
      'https://review.supabase.co/%2E%2E/',
      'https://review.supabase.co?project=other',
      'https://review.supabase.co#other',
      'https://actor@review.supabase.co',
      'https://review.supabase.co:0',
      'https://review.supabase.co:65536',
    ]) {
      expect(
        () => _binding(issuer: issuer),
        unavailable('invalid_binding'),
        reason: issuer,
      );
    }
    expect(() => _binding(userId: '900001'), unavailable('invalid_binding'));
    expect(() => _binding(generation: 0), unavailable('invalid_binding'));
    expect(
      () => _binding(fixtureVersion: 'other-fixture'),
      unavailable('invalid_binding'),
    );
  });

  test(
    'manifest contains limited marketplace data and no contact/payment/Admin authority',
    () {
      final fixture = _Fixture();
      final action = fixture.store.captureAction();
      final world = fixture.store.snapshot(action);
      expect(world.profile.memberId, matches(RegExp(r'^\d{6}$')));
      expect(world.profile.countryCode, 'RW');
      expect(world.profile.isAdmin, isFalse);
      for (final profile in [
        world.profile,
        ...world.peers.values.map((peer) => peer.profile),
      ]) {
        expect(profile.phone, isNull);
        expect(profile.whatsapp, isNull);
        expect(profile.momoNumber, isNull);
        expect(profile.momoPayCode, isNull);
        expect(profile.avatarUrl, isNull);
      }
      expect(world.trips.length, 2);
      for (final post in world.trips.values) {
        expect(post.price, isNull);
        expect(post.whatsapp, isEmpty);
        expect(post.clientRequestId, isNull);
        expect(post.status, 'active');
      }
      expect(world.unreadMessages, 1);
      expect(world.unreadInbox, 2);
    },
  );

  test('a forged interface cannot authorize a read or local mutation', () {
    final fixture = _Fixture();
    final action = fixture.store.captureAction();
    final before = fixture.store.snapshot(action);
    final forged = _ForgedAction(action.actorId);
    expect(
      () => fixture.store.getProfile(forged),
      unavailable('stale_or_foreign_action'),
    );
    expect(
      () => fixture.store.editProfile(forged, displayName: 'Forged'),
      unavailable('stale_or_foreign_action'),
    );
    expect(identical(fixture.store.snapshot(action), before), isTrue);
    expect(forged.callbackCalls, 0);
  });

  test(
    'opaque actions are exact store owners even for identical stable binding',
    () {
      final first = _Fixture(), second = _Fixture();
      final action = first.store.captureAction();
      expect(
        () => second.store.snapshot(action),
        unavailable('stale_or_foreign_action'),
      );
      expect(
        () => second.store.sendMessage(
          action,
          first.store.listConversations(action).single.id,
          'Foreign',
        ),
        unavailable('stale_or_foreign_action'),
      );
      expect(second.store.snapshot(second.store.captureAction()).revision, 0);
    },
  );

  test(
    'pending validation quarantines memory and same binding resumes with fresh action',
    () {
      final fixture = _Fixture();
      final action = fixture.store.captureAction();
      final post = fixture.store.createTrip(
        action,
        fixture.trip(note: 'Keep this post'),
      );
      final conversation = fixture.store.listConversations(action).single;
      final message = fixture.store.sendMessage(
        action,
        conversation.id,
        'Keep this message',
      );
      fixture.store.markConversationRead(action, conversation.id);
      final before = fixture.store.snapshot(action);
      fixture.store.quarantine();
      fixture.valid = false;
      expect(fixture.store.phase, ReviewWorldPhase.quarantined);
      expect(fixture.store.hasWorld, isTrue);
      expect(() => fixture.store.snapshot(action), unavailable());
      expect(fixture.store.captureAction, unavailable('world_locked'));
      fixture
        ..valid = true
        ..elapsed = const Duration(seconds: 5)
        ..accept(epoch: 99);
      final renewed = fixture.store.captureAction();
      final after = fixture.store.snapshot(renewed);
      expect(after.worldInstance, before.worldInstance);
      expect(after.revision, before.revision);
      expect(after.trips[post.id]!.note, 'Keep this post');
      expect(after.messages[conversation.id]!.last.id, message.id);
      expect(after.unreadMessages, 0);
      expect(
        () => fixture.store.snapshot(action),
        unavailable('stale_or_foreign_action'),
      );
    },
  );

  test(
    'renewed validation invalidates old action independently of stable generation',
    () {
      final fixture = _Fixture();
      final old = fixture.store.captureAction();
      final world = fixture.store.snapshot(old);
      fixture.accept(epoch: 2);
      final next = fixture.store.captureAction();
      expect(fixture.store.snapshot(next).worldInstance, world.worldInstance);
      expect(
        () => fixture.store.getProfile(old),
        unavailable('stale_or_foreign_action'),
      );
      next.requireCurrent();
    },
  );

  for (final reason in [
    ReviewWorldClearReason.statusFailure,
    ReviewWorldClearReason.logout,
    ReviewWorldClearReason.background,
    ReviewWorldClearReason.replacement,
  ]) {
    test(
      'terminal $reason clears volatile edits before a fresh accepted world',
      () {
        final fixture = _Fixture();
        final action = fixture.store.captureAction();
        fixture.store.editProfile(action, displayName: 'Temporary name');
        final old = fixture.store.snapshot(action);
        fixture.store.clear(reason);
        expect(fixture.store.phase, ReviewWorldPhase.locked);
        expect(fixture.store.hasWorld, isFalse);
        expect(fixture.store.binding, isNull);
        expect(fixture.store.lastClearReason, reason);
        fixture.accept(epoch: 2);
        final next = fixture.store.snapshot(fixture.store.captureAction());
        expect(next.profile.displayName, 'Review member');
        expect(next.worldInstance, greaterThan(old.worldInstance));
        expect(() => fixture.store.snapshot(action), unavailable());
      },
    );
  }

  for (final replacement in [
    _binding(issuer: 'https://another.supabase.co'),
    _binding(userId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
    _binding(sessionId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'),
    _binding(generation: 2),
  ]) {
    test(
      'replacement ${replacement.key} does not inherit prior actor-local state',
      () {
        final fixture = _Fixture();
        final action = fixture.store.captureAction();
        fixture.store.editProfile(action, displayName: 'Earlier world');
        final before = fixture.store.snapshot(action);
        fixture.accept(binding: replacement, epoch: 2);
        final next = fixture.store.snapshot(fixture.store.captureAction());
        expect(next.binding.sameWorld(replacement), isTrue);
        expect(next.profile.displayName, 'Review member');
        expect(next.worldInstance, greaterThan(before.worldInstance));
        expect(() => fixture.store.snapshot(action), unavailable());
      },
    );
  }

  test(
    'server role replacement clears state rather than granting local elevated mode',
    () {
      final fixture = _Fixture(role: MarketplaceRole.driver);
      final action = fixture.store.captureAction();
      fixture.store.editProfile(action, displayName: 'Driver edit');
      fixture.store.setMode(action, MarketplaceRole.driver);
      fixture.store.setDriverOnline(action, true);
      final before = fixture.store.snapshot(action);
      fixture.accept(role: MarketplaceRole.passenger, epoch: 2);
      final next = fixture.store.captureAction();
      final world = fixture.store.snapshot(next);
      expect(world.worldInstance, greaterThan(before.worldInstance));
      expect(world.profile.role, 'passenger');
      expect(world.profile.isAdmin, isFalse);
      expect(world.mode, MarketplaceRole.passenger);
      expect(world.driverOnline, isFalse);
      expect(
        () => fixture.store.setMode(next, MarketplaceRole.driver),
        unavailable('driver_role_required'),
      );
      expect(
        () => fixture.store.setDriverOnline(next, true),
        unavailable('driver_role_required'),
      );
      expect(
        () => fixture.store.createTrip(
          next,
          fixture.trip(role: MarketplaceRole.driver),
        ),
        unavailable('invalid_post'),
      );
    },
  );

  test(
    'lease is usable before and cleared exactly at its monotonic expiry boundary',
    () {
      final fixture = _Fixture();
      final action = fixture.store.captureAction();
      fixture.elapsed =
          const Duration(minutes: 10) - const Duration(microseconds: 1);
      expect(fixture.store.getProfile(action).id, action.actorId);
      expect(fixture.store.remaining, const Duration(microseconds: 1));
      fixture.elapsed = const Duration(minutes: 10);
      expect(() => fixture.store.snapshot(action), unavailable());
      expect(fixture.store.phase, ReviewWorldPhase.locked);
      expect(fixture.store.lastClearReason, ReviewWorldClearReason.expiry);
      fixture.accept(epoch: 2);
      expect(fixture.store.snapshot(fixture.store.captureAction()).revision, 0);
    },
  );

  test(
    'quarantined memory expires and backwards clock cannot extend authority',
    () {
      final fixture = _Fixture();
      fixture.store.quarantine();
      fixture.elapsed = const Duration(minutes: 10);
      expect(fixture.store.hasWorld, isFalse);
      expect(fixture.store.lastClearReason, ReviewWorldClearReason.expiry);
      fixture.accept(epoch: 2);
      final action = fixture.store.captureAction();
      fixture.elapsed += const Duration(seconds: 1);
      action.requireCurrent();
      fixture.elapsed -= const Duration(seconds: 2);
      expect(() => fixture.store.snapshot(action), unavailable());
      expect(fixture.store.lastClearReason, ReviewWorldClearReason.clockReset);
    },
  );

  test(
    'revoked callback and disposed store clear state and cannot issue actions',
    () {
      final fixture = _Fixture();
      final action = fixture.store.captureAction();
      fixture.valid = false;
      expect(() => fixture.store.snapshot(action), unavailable());
      expect(
        fixture.store.lastClearReason,
        ReviewWorldClearReason.authorityLost,
      );
      fixture
        ..valid = true
        ..accept(epoch: 2);
      fixture.store.dispose();
      expect(fixture.store.captureAction, unavailable('world_locked'));
      expect(() => fixture.accept(epoch: 3), unavailable('invalid_grant'));
    },
  );

  test(
    'callback revocation during a mutation prevents commit and clears the old world',
    () {
      final fixture = _Fixture();
      var checks = 0;
      fixture.store.acceptValidatedLease(
        ReviewLeaseGrant(
          binding: _binding(),
          serverRole: MarketplaceRole.passenger,
          serverNow: _anchor,
          remaining: const Duration(minutes: 10),
          authorityEpoch: 2,
          isCurrent: () => ++checks <= 5,
        ),
      );
      // Two grant checks, one capture check, two pre-mutation checks; the next
      // authority check during commit fails. No edited snapshot is exposed.
      final action = fixture.store.captureAction();
      expect(
        () => fixture.store.editProfile(action, displayName: 'Must not commit'),
        unavailable(),
      );
      expect(fixture.store.hasWorld, isFalse);
      fixture.accept(epoch: 3);
      expect(
        fixture.store.getProfile(fixture.store.captureAction()).displayName,
        'Review member',
      );
    },
  );

  test(
    'scheduled posts enforce actor ownership, revision and cancelled-state guards',
    () {
      final fixture = _Fixture();
      final action = fixture.store.captureAction();
      final peerPost = fixture.store.listTrips(action).first;
      expect(
        () => fixture.store.editTrip(
          action,
          peerPost.id!,
          fixture.trip(),
          expectedRevision: 0,
        ),
        unavailable('post_ownership_or_revision'),
      );
      final created = fixture.store.createTrip(
        action,
        fixture.trip(note: 'First'),
      );
      final edited = fixture.store.editTrip(
        action,
        created.id!,
        fixture.trip(note: 'Changed'),
        expectedRevision: 0,
      );
      expect(edited.id, created.id);
      expect(edited.createdAt, created.createdAt);
      expect(
        () =>
            fixture.store.cancelTrip(action, created.id!, expectedRevision: 0),
        unavailable('post_ownership_or_revision'),
      );
      final cancelled = fixture.store.cancelTrip(
        action,
        created.id!,
        expectedRevision: 1,
      );
      expect(cancelled.isActive, isFalse);
      expect(cancelled.status, 'cancelled');
      expect(fixture.store.listTrips(action, ownOnly: true), isEmpty);
      expect(
        fixture.store
            .listTrips(action, ownOnly: true, includeCancelled: true)
            .single
            .id,
        created.id,
      );
      expect(
        () => fixture.store.editTrip(
          action,
          created.id!,
          fixture.trip(),
          expectedRevision: 2,
        ),
        unavailable('post_ownership_or_revision'),
      );
      expect(
        () => fixture.store.getTrip(action, 'missing'),
        unavailable('unknown_post'),
      );
    },
  );

  test(
    'post validation uses current server time and bounded fixture places',
    () {
      final fixture = _Fixture();
      final action = fixture.store.captureAction();
      fixture.elapsed = const Duration(minutes: 2);
      final before = fixture.store.snapshot(action);
      expect(
        () => fixture.store.createTrip(
          action,
          fixture.trip(at: _anchor.add(const Duration(minutes: 1))),
        ),
        unavailable('invalid_post'),
      );
      final places = before.places.keys.toList();
      expect(
        () => fixture.store.createTrip(
          action,
          ReviewTripDraft(
            originPlaceId: 'external',
            destinationPlaceId: places.last,
            departureAt: _anchor.add(const Duration(days: 1)),
            role: MarketplaceRole.passenger,
          ),
        ),
        unavailable('invalid_post'),
      );
      expect(
        () => fixture.store.createTrip(
          action,
          fixture.trip(recurringDays: [1, 1]),
        ),
        unavailable('invalid_post'),
      );
      expect(
        () => fixture.store.createTrip(action, fixture.trip(seats: 9)),
        unavailable('invalid_post'),
      );
      expect(identical(fixture.store.snapshot(action), before), isTrue);
    },
  );

  test(
    'profile edits are actor-local and coherent with existing authored posts',
    () {
      final fixture = _Fixture();
      final action = fixture.store.captureAction();
      final post = fixture.store.createTrip(action, fixture.trip());
      final old = fixture.store.snapshot(action);
      final profile = fixture.store.editProfile(
        action,
        displayName: '  Local member  ',
        vehicleType: 'bus',
      );
      expect(profile.displayName, 'Local member');
      expect(profile.vehicleType, 'bus');
      expect(
        fixture.store.getTrip(action, post.id!).authorName,
        'Local member',
      );
      expect(old.profile.displayName, 'Review member');
      expect(old.trips[post.id]!.authorName, 'Review member');
      expect(
        fixture.store
            .snapshot(action)
            .peers
            .values
            .map((peer) => peer.profile.displayName),
        old.peers.values.map((peer) => peer.profile.displayName),
      );
      expect(
        () => fixture.store.editProfile(
          action,
          displayName: 'x',
          vehicleType: 'route-dispatch',
        ),
        unavailable('invalid_vehicle'),
      );
    },
  );

  test(
    'chat membership, post context and exact actor token constrain local messages',
    () {
      final fixture = _Fixture();
      final action = fixture.store.captureAction();
      final world = fixture.store.snapshot(action);
      final peers = world.peers.keys.toList();
      final first = fixture.store.openConversation(action, peers.first);
      expect(fixture.store.openConversation(action, peers.first).id, first.id);
      final otherPeerPost = world.trips.values.firstWhere(
        (trip) => trip.authorId == peers.last,
      );
      expect(
        () => fixture.store.openConversation(
          action,
          peers.first,
          tripId: otherPeerPost.id,
        ),
        unavailable('invalid_conversation_post'),
      );
      expect(
        () => fixture.store.openConversation(action, 'unknown'),
        unavailable('unknown_peer'),
      );
      expect(
        () => fixture.store.messagesFor(action, 'foreign-conversation'),
        unavailable('conversation_ownership'),
      );
      final message = fixture.store.sendMessage(
        action,
        first.id,
        'An actor-local message',
      );
      expect(message.senderId, action.actorId);
      expect(fixture.store.messagesFor(action, first.id).last.id, message.id);
      expect(
        fixture.store
            .listConversations(action)
            .firstWhere((chat) => chat.id == first.id)
            .lastMessagePreview,
        message.body,
      );
    },
  );

  test(
    'chat read and inbox read remain coherent but independently explicit',
    () {
      final fixture = _Fixture();
      final action = fixture.store.captureAction();
      final conversation = fixture.store.listConversations(action).single;
      fixture.store.markConversationRead(action, conversation.id);
      final world = fixture.store.snapshot(action);
      expect(world.unreadMessages, 0);
      expect(world.unreadInbox, 1);
      fixture.store.markInboxRead(action);
      expect(fixture.store.snapshot(action).unreadInbox, 0);
      expect(
        () => fixture.store.markInboxRead(action, id: 'other'),
        unavailable('unknown_notification'),
      );
    },
  );

  test(
    'blocking and reports stay inside fixture peers and the actor world',
    () {
      final fixture = _Fixture();
      final action = fixture.store.captureAction();
      final peer = fixture.store.nearby(action).first;
      final conversation = fixture.store.openConversation(
        action,
        peer.profile.id,
      );
      fixture.store.blockPeer(action, peer.profile.id, true);
      expect(
        fixture.store
            .nearby(action)
            .any((item) => item.profile.id == peer.profile.id),
        isFalse,
      );
      expect(
        () => fixture.store.sendMessage(action, conversation.id, 'Blocked'),
        unavailable('peer_blocked'),
      );
      expect(
        () => fixture.store.openConversation(action, peer.profile.id),
        unavailable('peer_blocked'),
      );
      final report = fixture.store.reportPeer(
        action,
        peer.profile.id,
        'Synthetic report',
      );
      expect(fixture.store.snapshot(action).reports.single.id, report.id);
      expect(fixture.store.snapshot(action).profile.isAdmin, isFalse);
      fixture.store.blockPeer(action, peer.profile.id, false);
      expect(
        fixture.store
            .nearby(action)
            .any((item) => item.profile.id == peer.profile.id),
        isTrue,
      );
      expect(
        () => fixture.store.reportPeer(action, 'external', 'No'),
        unavailable('unknown_peer'),
      );
    },
  );

  test(
    'collection limits reject a whole command without advancing state or IDs',
    () {
      final fixture = _Fixture();
      final action = fixture.store.captureAction();
      for (var index = 2; index < ReviewMarketplaceStore.maxPosts; index++) {
        fixture.store.createTrip(action, fixture.trip(note: '$index'));
      }
      final before = fixture.store.snapshot(action);
      expect(
        () => fixture.store.createTrip(action, fixture.trip()),
        unavailable('post_limit'),
      );
      expect(identical(fixture.store.snapshot(action), before), isTrue);
      final conversation = fixture.store.listConversations(action).single;
      for (
        var index = 1;
        index < ReviewMarketplaceStore.maxMessagesPerConversation;
        index++
      ) {
        fixture.store.sendMessage(action, conversation.id, '$index');
      }
      final full = fixture.store.snapshot(action);
      expect(
        () => fixture.store.sendMessage(action, conversation.id, 'overflow'),
        unavailable('message_limit'),
      );
      expect(identical(fixture.store.snapshot(action), full), isTrue);
    },
  );

  test(
    'snapshot maps, lists and old nested models remain immutable after mutations',
    () {
      final fixture = _Fixture();
      final action = fixture.store.captureAction();
      final days = [1, 3];
      final input = fixture.trip(recurringDays: days);
      days.add(5);
      final post = fixture.store.createTrip(action, input);
      final old = fixture.store.snapshot(action);
      expect(post.recurringDays, [1, 3]);
      expect(() => post.recurringDays.add(6), throwsUnsupportedError);
      expect(old.trips.clear, throwsUnsupportedError);
      expect(old.places.clear, throwsUnsupportedError);
      expect(old.messages.clear, throwsUnsupportedError);
      expect(old.blockedPeers.clear, throwsUnsupportedError);
      expect(old.reports.clear, throwsUnsupportedError);
      final conversation = old.conversations.values.single;
      expect(old.messages[conversation.id]!.clear, throwsUnsupportedError);
      fixture.store.sendMessage(action, conversation.id, 'New message');
      fixture.store.cancelTrip(action, post.id!, expectedRevision: 0);
      expect(old.messages[conversation.id]!.length, 1);
      expect(old.trips[post.id]!.isActive, isTrue);
      expect(fixture.store.getTrip(action, post.id!).isActive, isFalse);
    },
  );

  test(
    'copied shared trip/message models do not retain nested caller aliases',
    () {
      final days = [1], skipDates = ['2026-10-04'];
      final trip = Trip(
        authorId: _actor,
        origin: 'A',
        destination: 'B',
        recurringDays: days,
        recurrenceSkipDates: skipDates,
      );
      final copiedTrip = ReviewWorldSnapshot.copyTrip(trip);
      days.add(2);
      skipDates.add('2026-10-05');
      expect(copiedTrip.recurringDays, [1]);
      expect(copiedTrip.recurrenceSkipDates, ['2026-10-04']);
      final nested = <String, dynamic>{
        'array': <Object?>[
          <String, Object?>{'label': 'initial'},
        ],
      };
      final message = ChatMessageModel(
        id: 'm',
        conversationId: 'c',
        senderId: _actor,
        messageType: 'text',
        body: 'Body',
        createdAt: _anchor,
        metadata: nested,
      );
      final copy = ReviewWorldSnapshot.copyMessage(message);
      ((nested['array'] as List).single as Map)['label'] = 'changed';
      expect(
        ((copy.metadata['array'] as List).single as Map)['label'],
        'initial',
      );
      expect(
        () => ((copy.metadata['array'] as List).single as Map)['label'] =
            'forged',
        throwsUnsupportedError,
      );
      expect(
        () => (copy.metadata['array'] as List).add('forged'),
        throwsUnsupportedError,
      );
      expect(() => copy.metadata['other'] = 1, throwsUnsupportedError);
    },
  );

  test('invalid or expired grants cannot unlock a store', () {
    final store = ReviewMarketplaceStore(elapsed: () => Duration.zero);
    for (final remaining in [
      Duration.zero,
      const Duration(seconds: -1),
      const Duration(hours: 2),
    ]) {
      expect(
        () => store.acceptValidatedLease(
          ReviewLeaseGrant(
            binding: _binding(),
            serverRole: MarketplaceRole.passenger,
            serverNow: _anchor,
            remaining: remaining,
            authorityEpoch: 1,
            isCurrent: () => true,
          ),
        ),
        unavailable('invalid_grant'),
      );
      expect(store.hasWorld, isFalse);
    }
    expect(
      () => store.acceptValidatedLease(
        ReviewLeaseGrant(
          binding: _binding(),
          serverRole: MarketplaceRole.passenger,
          serverNow: _anchor,
          remaining: const Duration(minutes: 10),
          authorityEpoch: 1,
          isCurrent: () => throw StateError('unavailable proof'),
        ),
      ),
      unavailable('invalid_grant'),
    );
    expect(store.hasWorld, isFalse);
  });

  test(
    'grant callback that fails after acquisition clears the active world',
    () {
      final fixture = _Fixture();
      var throwProof = false;
      fixture.store.acceptValidatedLease(
        ReviewLeaseGrant(
          binding: _binding(),
          serverRole: MarketplaceRole.passenger,
          serverNow: _anchor,
          remaining: const Duration(minutes: 10),
          authorityEpoch: 2,
          isCurrent: () {
            if (throwProof) throw StateError('proof unavailable');
            return true;
          },
        ),
      );
      final action = fixture.store.captureAction();
      throwProof = true;
      expect(() => fixture.store.snapshot(action), unavailable());
      expect(fixture.store.hasWorld, isFalse);
      expect(
        fixture.store.lastClearReason,
        ReviewWorldClearReason.authorityLost,
      );
    },
  );

  test('bounded nested metadata rejects cycles and non JSON objects', () {
    final cycle = <Object?>[];
    cycle.add(cycle);
    ChatMessageModel message(Object? value) => ChatMessageModel(
      id: 'm',
      conversationId: 'c',
      messageType: 'text',
      body: 'body',
      createdAt: _anchor,
      metadata: {'nested': value},
    );
    expect(
      () => ReviewWorldSnapshot.copyMessage(message(cycle)),
      unavailable('invalid_metadata'),
    );
    expect(
      () => ReviewWorldSnapshot.copyMessage(message(Object())),
      unavailable('invalid_metadata'),
    );
    expect(
      () => ReviewWorldSnapshot.copyMessage(message(double.nan)),
      unavailable('invalid_metadata'),
    );
  });

  test(
    'conversation and report bounds preserve committed local state on overflow',
    () {
      final fixture = _Fixture();
      final action = fixture.store.captureAction();
      final peer = fixture.store.nearby(action).first.profile.id;
      for (
        var index = 1;
        index < ReviewMarketplaceStore.maxConversations;
        index++
      ) {
        final post = fixture.store.createTrip(
          action,
          fixture.trip(note: '$index'),
        );
        fixture.store.openConversation(action, peer, tripId: post.id);
      }
      final next = fixture.store.createTrip(action, fixture.trip(note: 'last'));
      final full = fixture.store.snapshot(action);
      expect(
        () => fixture.store.openConversation(action, peer, tripId: next.id),
        unavailable('conversation_limit'),
      );
      expect(identical(fixture.store.snapshot(action), full), isTrue);
      for (var index = 0; index < ReviewMarketplaceStore.maxReports; index++) {
        fixture.store.reportPeer(action, peer, 'Synthetic report $index');
      }
      final reported = fixture.store.snapshot(action);
      expect(
        () => fixture.store.reportPeer(action, peer, 'overflow'),
        unavailable('report_limit'),
      );
      expect(identical(fixture.store.snapshot(action), reported), isTrue);
    },
  );

  test(
    'bounded IDs, order and logical times are deterministic for identical actor commands',
    () {
      final first = _Fixture(), second = _Fixture();
      List<String> sequence(_Fixture fixture) {
        final action = fixture.store.captureAction();
        fixture.store.editProfile(action, displayName: 'Deterministic actor');
        final post = fixture.store.createTrip(
          action,
          fixture.trip(note: 'same'),
        );
        final conversation = fixture.store.openConversation(
          action,
          fixture.store.nearby(action).first.profile.id,
          tripId: post.id,
        );
        final message = fixture.store.sendMessage(
          action,
          conversation.id,
          'same',
        );
        return [
          jsonEncode(post.toJson()),
          message.id,
          message.createdAt.toIso8601String(),
          ...fixture.store.listTrips(action).map((trip) => trip.id!),
          ...fixture.store
              .listInbox(action)
              .map((item) => '${item.id}|${item.createdAt.toIso8601String()}'),
        ];
      }

      expect(sequence(first), sequence(second));
    },
  );
}

const _actor = '11111111-1111-4111-8111-111111111111';
final _anchor = DateTime.utc(2026, 10, 2, 8);
ReviewWorldBinding _binding({
  String issuer = 'https://review.supabase.co',
  String userId = _actor,
  String sessionId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  int generation = 1,
  String fixtureVersion = ReviewWorldBinding.supportedFixtureVersion,
}) => ReviewWorldBinding(
  issuer: issuer,
  userId: userId,
  sessionId: sessionId,
  generation: generation,
  fixtureVersion: fixtureVersion,
);

class _Fixture {
  _Fixture({MarketplaceRole role = MarketplaceRole.passenger}) {
    store = ReviewMarketplaceStore(elapsed: () => elapsed);
    accept(role: role);
  }
  Duration elapsed = Duration.zero;
  bool valid = true;
  late final ReviewMarketplaceStore store;
  void accept({
    ReviewWorldBinding? binding,
    MarketplaceRole role = MarketplaceRole.passenger,
    int epoch = 1,
  }) => store.acceptValidatedLease(
    ReviewLeaseGrant(
      binding: binding ?? _binding(),
      serverRole: role,
      serverNow: _anchor.add(elapsed),
      remaining: const Duration(minutes: 10),
      authorityEpoch: epoch,
      isCurrent: () => valid,
    ),
  );
  ReviewTripDraft trip({
    String? note,
    MarketplaceRole role = MarketplaceRole.passenger,
    DateTime? at,
    int seats = 1,
    List<int> recurringDays = const [],
  }) {
    final places = store.snapshot(store.captureAction()).places.keys.toList();
    return ReviewTripDraft(
      originPlaceId: places.first,
      destinationPlaceId: places.last,
      departureAt: at ?? _anchor.add(const Duration(days: 1)),
      role: role,
      seats: seats,
      note: note,
      recurringDays: recurringDays,
    );
  }
}

class _ForgedAction implements MarketplaceAction {
  _ForgedAction(this.actorId);
  @override
  final String actorId;
  int callbackCalls = 0;
  @override
  void requireCurrent() {
    callbackCalls++;
  }
}
