import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/review_session_context.dart';
import 'package:mobi_app/core/location/location_providers.dart';
import 'package:mobi_app/core/permissions/permission_providers.dart';
import 'package:mobi_app/features/bookings/application/booking_services.dart';
import 'package:mobi_app/features/bookings/application/review_scheduled_post_providers.dart';
import 'package:mobi_app/features/bookings/application/review_scheduled_posts.dart';
import 'package:mobi_app/features/bookings/application/schedule_trip_provider.dart';
import 'package:mobi_app/features/bookings/application/schedule_trip_state.dart';
import 'package:mobi_app/features/bookings/presentation/bookings_screen.dart';
import 'package:mobi_app/features/bookings/presentation/schedule_trip_screen.dart';
import 'package:mobi_app/features/bookings/presentation/trip_details_screen.dart';
import 'package:mobi_app/features/bookings/presentation/widgets/review_place_picker_field.dart';
import 'package:mobi_app/features/bookings/presentation/widgets/trip_route_form.dart';
import 'package:mobi_app/features/bookings/presentation/widgets/trip_timing_picker.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_app/features/store_review/application/review_marketplace_owner.dart';
import 'package:mobi_app/shared/widgets/ai_empty_state.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/place_autocomplete_field.dart';
import 'package:mobi_app/shared/widgets/route_map_card.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
  late _Fixture f;
  late ProviderContainer container;
  var fixtureDisposed = false;
  var ordinaryFactories = 0;
  Never forbidden() {
    ordinaryFactories++;
    throw StateError('Reviewer widget reached an ordinary/native factory');
  }

  setUp(() {
    fixtureDisposed = false;
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
    );
  });
  tearDown(() {
    if (!fixtureDisposed) {
      container.dispose();
      f.dispose();
    }
  });
  void reviewWidgets(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        f.dispose();
        fixtureDisposed = true;
      }
    });
  }

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    ProviderContainer? scope,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope ?? container,
        child: MaterialApp(
          key: UniqueKey(),
          theme: AppTheme.darkTheme,
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  BookingsScreen bookings({VoidCallback? onSchedule}) => BookingsScreen(
    mode: 'passenger',
    onModeChanged: (_) {},
    onSchedule: onSchedule ?? () {},
    onTripDetails: (_) {},
  );
  ScheduleTripScreen schedule({String? id, VoidCallback? onBack}) =>
      ScheduleTripScreen(
        mode: 'passenger',
        editingTripId: id,
        onModeChanged: (_) {},
        onBack: onBack ?? () {},
      );

  reviewWidgets('scheduler selects exactly the three local places without IO', (
    tester,
  ) async {
    await mount(tester, schedule());
    expect(find.byType(ReviewPlacePickerField), findsNWidgets(2));
    expect(find.byType(PlaceAutocompleteField), findsNothing);
    final route = tester.widget<TripRouteForm>(find.byType(TripRouteForm));
    expect(route.favoriteAddresses, hasLength(3));
    expect(route.isReviewSession, true);
    expect(ordinaryFactories, 0);
    await tester.tap(find.byTooltip('Choose to'));
    await tester.pumpAndSettle();
    final dialog = find.byType(BottomSheet);
    for (final label in ['Kigali city centre', 'Nyabugogo', 'Remera']) {
      expect(
        find.descendant(of: dialog, matching: find.text(label)),
        findsOneWidget,
      );
    }
    await tester.tap(
      find.descendant(of: dialog, matching: find.text('Nyabugogo')),
    );
    await tester.pumpAndSettle();
    expect(
      container
          .read(scheduleTripProvider)
          .requireValue
          .destDetails!
          .formattedAddress,
      'Nyabugogo',
    );
    expect(
      tester.widget<RouteMapCard>(find.byType(RouteMapCard)).allowExternalMap,
      false,
    );
    expect(ordinaryFactories, 0);
    expect(tester.takeException(), isNull);
  });

  reviewWidgets('create edit view and cancel use one canonical volatile post', (
    tester,
  ) async {
    var back = 0;
    await mount(tester, schedule(onBack: () => back++));
    final route = tester.widget<TripRouteForm>(find.byType(TripRouteForm));
    route.onDestSelected(
      route.reviewPlaces.singleWhere(
        (place) => place.formattedAddress == 'Remera',
      ),
    );
    await tester.pumpAndSettle();
    final submit = find.widgetWithText(MobiButton, 'Schedule');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Similar scheduled posts'), findsOneWidget);
    expect(back, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    expect(back, 1);
    final post = f.gateway.page('passenger').own.single;
    await mount(tester, bookings());
    expect(find.text('${post.origin} → ${post.destination}'), findsWidgets);
    await mount(tester, schedule(id: post.id, onBack: () => back++));
    final timing = tester.widget<TripTimingPicker>(
      find.byType(TripTimingPicker),
    );
    timing.onTimeChanged(const TimeOfDay(hour: 14, minute: 15));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(MobiButton, 'Save changes');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(back, 2);
    expect(f.gateway.page('passenger').own.single.id, post.id);
    expect(f.gateway.page('passenger').own.single.departureTime, '14:15');
    await mount(
      tester,
      TripDetailsScreen(tripId: post.id!, onBack: () => back++),
    );
    expect(
      tester.widget<RouteMapCard>(find.byType(RouteMapCard)).allowExternalMap,
      false,
    );
    final cancel = find.widgetWithText(TextButton, 'Cancel trip');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Cancel trip'),
      ),
    );
    await tester.pumpAndSettle();
    expect(back, 3);
    expect(f.gateway.page('passenger').own.single.status, 'cancelled');
    await mount(tester, bookings());
    expect(find.text('Cancelled'), findsWidgets);
    expect(ordinaryFactories, 0);
    expect(tester.takeException(), isNull);
  });

  reviewWidgets('a cancel dialog cannot reinterpret a generation replacement', (
    tester,
  ) async {
    final intent = f.gateway.capture();
    final post = f.gateway.submit(intent, f.draft(intent), 'Old post');
    var back = 0;
    await mount(
      tester,
      TripDetailsScreen(tripId: post.id!, onBack: () => back++),
    );
    final cancel = find.widgetWithText(TextButton, 'Cancel trip');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    f.accept(generation: 4);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Cancel trip'),
      ),
    );
    await tester.pumpAndSettle();
    expect(back, 0);
    expect(f.gateway.page('passenger').own, isEmpty);
    expect(ordinaryFactories, 0);
    expect(tester.takeException(), isNull);
  });

  reviewWidgets('a local place sheet cannot commit during pending validation', (
    tester,
  ) async {
    await mount(tester, schedule());
    await tester.tap(find.byTooltip('Choose to'));
    await tester.pumpAndSettle();
    final before = container.read(scheduleTripProvider).requireValue;
    final ticket = f.context.beginValidation();
    await tester.pump();
    final label = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text('Remera'),
    );
    await tester.tap(label);
    await tester.pump();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(before.destDetails, isNull);
    expect(f.owner.store.hasWorld, true);
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pumpAndSettle();
    f.context.acceptStatus(ticket, f.status());
    await tester.pumpAndSettle();
    expect(f.gateway.page('passenger').own, isEmpty);
    expect(ordinaryFactories, 0);
    expect(tester.takeException(), isNull);
  });

  reviewWidgets(
    'unwired review chat and external map remain visibly disabled',
    (tester) async {
      final post = f.gateway.page('passenger').counterpart.single;
      await mount(tester, TripDetailsScreen(tripId: post.id!, onBack: () {}));
      final chat = tester.widget<MobiButton>(
        find.widgetWithText(MobiButton, 'Chat'),
      );
      expect(chat.onPressed, isNull);
      expect(
        tester.widget<RouteMapCard>(find.byType(RouteMapCard)).allowExternalMap,
        false,
      );
      final map = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Open in Google Maps'),
          matching: find.byWidgetPredicate((widget) => widget is FilledButton),
        ),
      );
      expect(map.onPressed, isNull);
      expect(ordinaryFactories, 0);
      expect(tester.takeException(), isNull);
    },
  );

  reviewWidgets(
    'empty-page callback captured before replacement cannot schedule',
    (tester) async {
      var schedules = 0;
      await mount(tester, bookings(onSchedule: () => schedules++));
      final callback = tester
          .widget<AiEmptyState>(find.byType(AiEmptyState))
          .onAction!;
      f.accept(generation: 4);
      callback();
      await tester.pumpAndSettle();
      expect(schedules, 0);
      expect(ordinaryFactories, 0);
      expect(tester.takeException(), isNull);
    },
  );

  reviewWidgets(
    'missing review gateway locks scheduler before ordinary factories',
    (tester) async {
      final missing = ProviderContainer(
        overrides: [
          reviewScheduledPostsSelectedProvider.overrideWithValue(true),
          tripServiceProvider.overrideWith((_) => forbidden()),
          vehicleTypeServiceProvider.overrideWith((_) => forbidden()),
          favoriteAddressServiceProvider.overrideWith((_) => forbidden()),
          appPermissionServiceProvider.overrideWith((_) => forbidden()),
        ],
      );
      addTearDown(missing.dispose);
      await mount(tester, schedule(), scope: missing);
      expect(find.byType(PlaceAutocompleteField), findsNothing);
      expect(find.byType(ReviewPlacePickerField), findsNothing);
      expect(ordinaryFactories, 0);
      expect(tester.takeException(), isNull);
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
