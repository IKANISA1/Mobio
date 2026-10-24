import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/review_session_context.dart';
import 'package:mobi_app/features/bookings/application/review_scheduled_posts.dart';
import 'package:mobi_app/features/bookings/application/schedule_trip_state.dart';
import 'package:mobi_app/features/store_review/application/review_marketplace_owner.dart';
import 'package:mobi_app/features/store_review/domain/review_world_authority.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/location/location_providers.dart';
import 'package:mobi_app/core/permissions/permission_providers.dart';
import 'package:mobi_app/features/bookings/application/booking_services.dart';
import 'package:mobi_app/features/bookings/application/review_scheduled_post_providers.dart';
import 'package:mobi_app/features/bookings/application/schedule_trip_provider.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_shared_types/models/place.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Fixture f;
  late ProviderContainer container;
  var ordinaryFactories = 0;
  Never forbidden() {
    ordinaryFactories++;
    throw StateError('Ordinary SDK/native factory must not run for reviewer');
  }

  setUp(() {
    ordinaryFactories = 0;
    f = _Fixture();
    container = ProviderContainer(
      overrides: [
        reviewScheduledPostGatewayProvider.overrideWithValue(f.gateway),
        tripServiceProvider.overrideWith((_) => forbidden()),
        publicTransportServiceProvider.overrideWith((_) => forbidden()),
        vehicleTypeServiceProvider.overrideWith((_) => forbidden()),
        favoriteAddressServiceProvider.overrideWith((_) => forbidden()),
        locationServiceProvider.overrideWith((_) => forbidden()),
        placesServiceProvider.overrideWith((_) => forbidden()),
        appPermissionServiceProvider.overrideWith((_) => forbidden()),
      ],
    )..listen(scheduleTripProvider, (_, _) {});
  });
  tearDown(() {
    container.dispose();
    f.dispose();
  });
  Future<ScheduleTripController> ready() async {
    container
        .read(scheduleTripArgsProvider.notifier)
        .setCreateMode('passenger');
    await container.read(scheduleTripProvider.future);
    return container.read(scheduleTripProvider.notifier);
  }

  test(
    'review branches before any account/native/catalog/service factory',
    () async {
      final c = await ready();
      final state = container.read(scheduleTripProvider).requireValue;
      expect(c.isReviewSession, true);
      expect(state.isReviewSession, true);
      expect(state.reviewPlaces, hasLength(3));
      expect(state.favoriteAddresses, hasLength(3));
      expect(state.transportAgencyNames, isEmpty);
      expect(state.userLat, isNull);
      expect(state.clientRequestId, isEmpty);
      await c.handleCurrentLocation();
      c.useFavoriteAsDestination(state.favoriteAddresses[1]);
      expect(
        container.read(scheduleTripProvider).requireValue.destDetails!.placeId,
        state.reviewPlaces[1].placeId,
      );
      expect(ordinaryFactories, 0);
    },
  );

  test(
    'one controller submits one canonical post with no automatic replay',
    () async {
      final c = await ready();
      final initial = container.read(scheduleTripProvider).requireValue;
      c.setDestination(initial.reviewPlaces[1]);
      final post = await c.submitTrip(note: 'One local post');
      expect(post, isNotNull);
      expect(
        container.read(scheduleTripProvider).requireValue.createdTrip!.id,
        post!.id,
      );
      expect(f.gateway.page('passenger').own.single.note, 'One local post');
      await expectLater(
        c.submitTrip(note: 'Duplicate'),
        throwsA(isA<ReviewWorldUnavailable>()),
      );
      expect(f.gateway.page('passenger').own, hasLength(1));
      expect(ordinaryFactories, 0);
    },
  );

  test(
    'edit uses exact captured owner tuple and retains canonical ID',
    () async {
      final intent = f.gateway.capture();
      final post = f.gateway.submit(intent, f.draft(intent), 'Before');
      container
          .read(scheduleTripArgsProvider.notifier)
          .setEditTrip(tripId: post.id!, mode: 'passenger');
      final initial = await container.read(scheduleTripProvider.future);
      expect(initial.editingTrip!.id, post.id);
      final c = container.read(scheduleTripProvider.notifier);
      c.setTime(const TimeOfDay(hour: 14, minute: 15));
      final updated = await c.submitTrip(note: 'After');
      expect(updated!.id, post.id);
      expect(updated.departureTime, '14:15');
      expect(f.gateway.page('passenger').own.single.note, 'After');
      // Successful edit must not invalidate the controller's display-time read.
      expect(c.comparisonNow, _anchor.add(const Duration(hours: 2)));
      expect(ordinaryFactories, 0);
    },
  );

  test(
    'external row revision invalidates submission rather than overwriting it',
    () async {
      final create = f.gateway.capture();
      final post = f.gateway.submit(create, f.draft(create), 'Before');
      container
          .read(scheduleTripArgsProvider.notifier)
          .setEditTrip(tripId: post.id!);
      await container.read(scheduleTripProvider.future);
      final c = container.read(scheduleTripProvider.notifier);
      final other = f.gateway.capture(targetId: post.id);
      f.gateway.submit(other, f.gateway.initialState(other), 'Other edit');
      await expectLater(
        c.submitTrip(note: 'Stale overwrite'),
        throwsA(isA<ReviewWorldUnavailable>()),
      );
      expect(f.gateway.page('passenger').own.single.note, 'Other edit');
      expect(ordinaryFactories, 0);
    },
  );

  test(
    'pending validation immediately blocks retained controller callbacks',
    () async {
      final c = await ready();
      final state = container.read(scheduleTripProvider).requireValue;
      final ticket = f.context.beginValidation();
      expect(
        () => c.setDestination(state.reviewPlaces[1]),
        throwsA(isA<ReviewWorldUnavailable>()),
      );
      await expectLater(
        c.submitTrip(note: 'Pending'),
        throwsA(isA<ReviewWorldUnavailable>()),
      );
      f.context.rejectStatus(ticket);
      await expectLater(
        container.read(scheduleTripProvider.future),
        throwsA(isA<ReviewWorldUnavailable>()),
      );
      expect(f.owner.store.hasWorld, false);
      expect(ordinaryFactories, 0);
    },
  );

  test(
    'foreign place or favorite edits fail locally without constructing SDK',
    () async {
      final c = await ready();
      expect(
        () => c.setDestination(
          const PlaceDetails(
            placeId: 'foreign',
            formattedAddress: 'Foreign',
            latitude: -1,
            longitude: 30,
          ),
        ),
        throwsA(isA<ReviewWorldUnavailable>()),
      );
      expect(
        await c.saveFavoriteAddress(
          fromOrigin: true,
          label: 'Unavailable',
          addressType: 'other',
        ),
        false,
      );
      expect(ordinaryFactories, 0);
    },
  );

  test(
    'selected reviewer with missing composition never falls through to ordinary',
    () async {
      final missing = ProviderContainer(
        overrides: [
          reviewScheduledPostsSelectedProvider.overrideWithValue(true),
          tripServiceProvider.overrideWith((_) => forbidden()),
          publicTransportServiceProvider.overrideWith((_) => forbidden()),
          vehicleTypeServiceProvider.overrideWith((_) => forbidden()),
          favoriteAddressServiceProvider.overrideWith((_) => forbidden()),
          appPermissionServiceProvider.overrideWith((_) => forbidden()),
        ],
      )..listen(scheduleTripProvider, (_, _) {});
      addTearDown(missing.dispose);
      await expectLater(
        missing.read(scheduleTripProvider.future),
        throwsA(isA<ReviewWorldUnavailable>()),
      );
      expect(ordinaryFactories, 0);
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
