import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/review_session_context.dart';
import 'package:mobi_app/features/bookings/application/review_scheduled_posts.dart';
import 'package:mobi_app/features/bookings/application/schedule_trip_state.dart';
import 'package:mobi_app/features/store_review/application/review_marketplace_owner.dart';
import 'package:mobi_app/features/store_review/domain/review_world_authority.dart';
import 'package:mobi_shared_types/models/favorite_address.dart';
import 'package:mobi_shared_types/models/place.dart';

void main() {
  _Fixture fixture({String role = 'driver'}) {
    final f = _Fixture(role: role);
    addTearDown(f.dispose);
    return f;
  }

  Matcher unavailable() => throwsA(isA<ReviewWorldUnavailable>());

  test('places and local shortcuts are bounded immutable world copies', () {
    final f = fixture();
    final intent = f.gateway.capture();
    final places = f.gateway.places(intent);
    final shortcuts = f.gateway.favorites(intent);
    expect(places.map((p) => p.formattedAddress), [
      'Kigali city centre',
      'Nyabugogo',
      'Remera',
    ]);
    expect(shortcuts, hasLength(3));
    expect(shortcuts.map((s) => s.placeId), places.map((p) => p.placeId));
    expect(shortcuts.every((s) => s.profileId == intent.actorId), true);
    expect(shortcuts.every((s) => s.id.startsWith('review-favorite:')), true);
    expect(() => places.clear(), throwsUnsupportedError);
    expect(() => shortcuts.clear(), throwsUnsupportedError);
    expect(
      f.gateway.favoritePlace(intent, shortcuts[1]).placeId,
      places[1].placeId,
    );
    expect(f.gateway.initialState(intent).transportAgencyNames, isEmpty);
    expect(f.gateway.initialState(intent).clientRequestId, isEmpty);
  });

  test('matching local ID never validates changed label or coordinates', () {
    final f = fixture();
    final intent = f.gateway.capture();
    final known = f.gateway.places(intent).first;
    for (final changed in [
      PlaceDetails(
        placeId: known.placeId,
        formattedAddress: 'Altered',
        latitude: known.latitude,
        longitude: known.longitude,
      ),
      PlaceDetails(
        placeId: known.placeId,
        formattedAddress: known.formattedAddress,
        latitude: known.latitude + 1,
        longitude: known.longitude,
      ),
      const PlaceDetails(
        placeId: '00000000-0000-4000-8000-000000000000',
        formattedAddress: 'Hosted-looking ID',
        latitude: -1,
        longitude: 30,
      ),
    ]) {
      expect(() => f.gateway.requirePlace(intent, changed), unavailable());
    }
    final saved = f.gateway.favorites(intent).first;
    final forged = FavoriteAddress(
      id: saved.id,
      profileId: 'other-actor',
      label: saved.label,
      addressType: saved.addressType,
      formattedAddress: saved.formattedAddress,
      placeId: saved.placeId,
      latitude: saved.latitude,
      longitude: saved.longitude,
    );
    expect(() => f.gateway.favoritePlace(intent, forged), unavailable());
    expect(f.owner.store.snapshot(f.owner.captureAction()).revision, 0);
  });

  test('Rwanda calendar literals round trip through UTC across midnight', () {
    final f = fixture();
    final intent = f.gateway.capture();
    final input = f
        .draft(intent)
        .copyWith(
          date: DateTime.utc(2026, 10, 3),
          time: const TimeOfDay(hour: 0, minute: 30),
        );
    final post = f.gateway.submit(intent, input, ' Across midnight ');
    expect(post.startsAt, '2026-10-02T22:30:00.000Z');
    expect(post.departureDate, '2026-10-03');
    expect(post.departureTime, '00:30');
    expect(post.note, 'Across midnight');
    final raw = f.owner.store.snapshot(f.owner.captureAction()).trips[post.id]!;
    expect(raw.departureDate, '2026-10-02');
    expect(raw.departureTime, '22:30');
    final edit = f.gateway.initialState(f.gateway.capture(targetId: post.id));
    expect(edit.date, DateTime.utc(2026, 10, 3));
    expect(edit.time, const TimeOfDay(hour: 0, minute: 30));
  });

  test('equal conservative current time is rejected before any mutation', () {
    final f = fixture();
    f.elapsed = const Duration(minutes: 1);
    final intent = f.gateway.capture();
    final calendar = f.gateway.calendarNow(intent);
    final input = f
        .draft(intent)
        .copyWith(
          date: calendar,
          time: TimeOfDay(hour: calendar.hour, minute: calendar.minute),
        );
    expect(input.canSubmit(calendar), false);
    expect(() => f.gateway.submit(intent, input, ''), unavailable());
    expect(f.gateway.page('passenger').own, isEmpty);
  });

  test(
    'create edit cancel share canonical state and freeze older row evidence',
    () {
      final f = fixture();
      final create = f.gateway.capture();
      final post = f.gateway.submit(create, f.draft(create), 'First');
      final before = f.gateway.page('passenger');
      final edit = before.rows[post.id]!;
      final updated = f.gateway.submit(
        edit,
        f.gateway
            .initialState(edit)
            .copyWith(isRecurring: true, recurringDays: const [1, 3]),
        'Updated',
      );
      expect(updated.id, post.id);
      expect(before.own.single.note, 'First');
      expect(before.own.single.recurringDays, isEmpty);
      expect(f.gateway.isCurrent(edit), false);
      expect(f.gateway.hasCurrentAuthority(edit), true);
      // Time remains readable after our own known commit; mutation tuple does not.
      expect(
        f.gateway.calendarNow(edit),
        _anchor.add(const Duration(hours: 2)),
      );
      expect(() => f.gateway.cancel(edit), unavailable());
      final current = f.gateway.capture(targetId: post.id);
      final cancelled = f.gateway.cancel(current);
      expect(cancelled.status, 'cancelled');
      expect(f.gateway.page('passenger').own.single.isActive, false);
      expect(
        () => f.gateway.initialState(f.gateway.capture(targetId: post.id)),
        unavailable(),
      );
      expect(() => updated.recurringDays.add(6), throwsUnsupportedError);
      expect(() => before.rows.clear(), throwsUnsupportedError);
    },
  );

  test('counterpart rows are browsable but not editable or cancellable', () {
    final f = fixture();
    final page = f.gateway.page('passenger');
    expect(page.counterpart, hasLength(1));
    final intent = page.rows[page.counterpart.single.id]!;
    expect(f.gateway.get(intent).role, 'driver');
    expect(() => f.gateway.initialState(intent), unavailable());
    expect(() => f.gateway.cancel(intent), unavailable());
    expect(f.owner.store.snapshot(f.owner.captureAction()).revision, 0);
  });

  test('passenger proof cannot use UI mode to create a driver post', () {
    final f = fixture(role: 'passenger');
    final intent = f.gateway.capture();
    expect(f.gateway.canUseRole(intent, 'driver'), false);
    expect(() => f.gateway.initialState(intent, mode: 'driver'), unavailable());
    expect(
      () => f.gateway.submit(
        intent,
        f.draft(intent).copyWith(selectedRole: 'driver'),
        '',
      ),
      unavailable(),
    );
    expect(f.gateway.page('passenger').own, isEmpty);
  });

  test(
    'same-binding renewal retains posts but never renews an old callback',
    () {
      final f = fixture();
      final intent = f.gateway.capture();
      final post = f.gateway.submit(intent, f.draft(intent), 'Retain');
      final row = f.gateway.capture(targetId: post.id);
      final action = ScheduledPostUiAction.review(f.gateway, row);
      final ticket = f.context.beginValidation();
      expect(action.isCurrent, false);
      expect(f.owner.store.hasWorld, true);
      f.elapsed = const Duration(seconds: 3);
      f.context.acceptStatus(ticket, f.status());
      expect(action.isCurrent, false);
      expect(() => f.gateway.cancel(row), unavailable());
      expect(f.gateway.page('passenger').own.single.note, 'Retain');
      expect(
        f.gateway.get(f.gateway.capture(targetId: post.id)).note,
        'Retain',
      );
    },
  );

  for (final replacement in ['generation', 'role', 'session']) {
    test(
      '$replacement replacement drops old world and cannot rebind callbacks',
      () {
        final f = fixture();
        final intent = f.gateway.capture();
        f.gateway.submit(intent, f.draft(intent), 'Clear');
        final action = ScheduledPostUiAction.review(f.gateway, intent);
        if (replacement == 'session') {
          f.transport = ReviewTransportIdentity(
            _identity.userId,
            '33333333-3333-4333-8333-333333333333',
          );
        }
        f.accept(
          role: replacement == 'role' ? 'passenger' : 'driver',
          generation: replacement == 'generation' ? 4 : 3,
        );
        expect(action.isCurrent, false);
        expect(action.hasAuthority, false);
        expect(
          () => f.gateway.submit(intent, f.draft(intent), ''),
          unavailable(),
        );
        expect(f.gateway.page('passenger').own, isEmpty);
      },
    );
  }

  test('foreign gateway cannot consume even an identically bound intent', () {
    final f = fixture();
    final other = fixture();
    final intent = f.gateway.capture();
    expect(other.gateway.isCurrent(intent), false);
    expect(() => other.gateway.get(intent), unavailable());
    expect(
      () => other.gateway.submit(intent, f.draft(intent), ''),
      unavailable(),
    );
    expect(other.gateway.page('passenger').own, isEmpty);
  });

  test('reads publish nothing and each known local command publishes once', () {
    final f = fixture();
    var notifications = 0;
    f.gateway.addListener(() => notifications++);
    final intent = f.gateway.capture();
    f.gateway.page('passenger');
    f.gateway.places(intent);
    f.gateway.favorites(intent);
    f.gateway.calendarNow(intent);
    expect(notifications, 0);
    final post = f.gateway.submit(intent, f.draft(intent), 'Published');
    expect(notifications, 1);
    f.gateway.cancel(f.gateway.capture(targetId: post.id));
    expect(notifications, 2);
  });

  test('precise expiry clears data and denies all old continuations', () {
    final f = fixture();
    final intent = f.gateway.capture();
    f.gateway.submit(intent, f.draft(intent), 'Expires');
    f.elapsed = const Duration(minutes: 10, microseconds: -1);
    expect(f.gateway.hasCurrentAuthority(intent), true);
    f.elapsed = const Duration(minutes: 10);
    expect(f.gateway.hasCurrentAuthority(intent), false);
    expect(f.owner.store.hasWorld, false);
    expect(() => f.gateway.page('passenger'), unavailable());
  });

  test(
    'gateway disposal detaches publication without disposing root owner',
    () {
      final f = fixture();
      final intent = f.gateway.capture();
      var notifications = 0;
      f.gateway.addListener(() => notifications++);
      f.gateway.dispose();
      expect(
        () => f.gateway.submit(intent, f.draft(intent), ''),
        unavailable(),
      );
      final action = f.owner.captureAction();
      f.owner.perform(
        action,
        (store) => store.editProfile(action, displayName: 'Root still owns'),
      );
      expect(notifications, 0);
      expect(
        f.owner.store.getProfile(f.owner.captureAction()).displayName,
        'Root still owns',
      );
    },
  );
}

const _identity = ReviewTransportIdentity(
  '11111111-1111-4111-8111-111111111111',
  '22222222-2222-4222-8222-222222222222',
);
final _anchor = DateTime.utc(2026, 10, 2, 10);

class _Fixture {
  _Fixture({String role = 'driver'}) {
    context = ReviewSessionContext(
      readTransport: () => transport,
      elapsedTime: () => elapsed,
    );
    owner = ReviewMarketplaceOwner(
      context: context,
      issuer: 'https://review.supabase.co',
      elapsed: () => elapsed,
    );
    gateway = ReviewScheduledPostGateway(owner);
    accept(role: role);
  }
  ReviewTransportIdentity? transport = _identity;
  Duration elapsed = Duration.zero;
  late final ReviewSessionContext context;
  late final ReviewMarketplaceOwner owner;
  late final ReviewScheduledPostGateway gateway;

  Map<String, Object> status({String role = 'driver', int generation = 3}) => {
    'active': true,
    'mode': 'synthetic_review',
    'user_id': transport!.userId,
    'session_id': transport!.sessionId,
    'role': role,
    'generation': generation,
    'fixture_version': ReviewSessionLease.supportedFixtureVersion,
    'authenticated_at': _anchor
        .subtract(const Duration(minutes: 1))
        .toIso8601String(),
    'server_now': _anchor.add(elapsed).toIso8601String(),
    'expires_at': _anchor.add(const Duration(minutes: 10)).toIso8601String(),
  };
  void accept({String role = 'driver', int generation = 3}) =>
      context.acceptStatus(
        context.beginValidation(),
        status(role: role, generation: generation),
      );
  ScheduleTripState draft(ReviewScheduledPostIntent intent) {
    final initial = gateway.initialState(intent, mode: 'passenger');
    return initial.copyWith(destDetails: initial.reviewPlaces[1]);
  }

  void dispose() {
    gateway.dispose();
    owner.dispose();
    context.dispose();
  }
}
