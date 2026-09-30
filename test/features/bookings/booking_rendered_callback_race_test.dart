import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/constants/app_constants.dart';
import 'package:mobi_app/core/permissions/app_permission_service.dart';
import 'package:mobi_app/core/permissions/permission_providers.dart';
import 'package:mobi_app/features/bookings/application/booking_services.dart';
import 'package:mobi_app/features/bookings/application/schedule_trip_provider.dart';
import 'package:mobi_app/features/bookings/application/schedule_trip_state.dart';
import 'package:mobi_app/features/bookings/data/trip_service.dart';
import 'package:mobi_app/features/bookings/presentation/bookings_screen.dart';
import 'package:mobi_app/features/bookings/presentation/schedule_trip_screen.dart';
import 'package:mobi_app/features/bookings/presentation/trip_details_screen.dart';
import 'package:mobi_app/features/bookings/presentation/widgets/trip_route_form.dart';
import 'package:mobi_app/shared/widgets/ai_empty_state.dart';
import 'package:mobi_design_system/theme/app_theme.dart';
import 'package:mobi_shared_types/models/place.dart';
import 'package:mobi_shared_types/models/trip.dart';

class _Permissions extends Fake implements AppPermissionService {
  final pending = Completer<bool>();
  int reads = 0, prompts = 0;
  @override
  Future<bool> hasLocationAccess() {
    reads++;
    return pending.future;
  }

  @override
  Future<bool> ensureLocationAccess() async {
    prompts++;
    return true;
  }
}

class _Schedule extends ScheduleTripController {
  int locations = 0, origins = 0;
  @override
  Future<ScheduleTripState> build() async =>
      ScheduleTripState(selectedRole: 'passenger');
  @override
  Future<void> handleCurrentLocation() async {
    locations++;
  }

  @override
  void setOrigin(PlaceDetails? place) {
    origins++;
  }
}

class _Trips extends Fake implements TripService {
  int cancels = 0;
  @override
  Future<void> cancelTrip(String id) async {
    cancels++;
  }
}

const _ownTrip = Trip(
  id: 'rendered-trip',
  authorId: 'preview-user',
  authorName: 'Synthetic owner',
  origin: 'Synthetic pickup',
  destination: 'Synthetic destination',
  date: '2026-09-30',
  time: '12:00',
  departureDate: '2026-09-30',
  departureTime: '12:00',
  role: 'passenger',
  whatsapp: '',
  seats: 1,
  price: '',
  isActive: true,
  status: 'active',
);

void main() {
  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    _Schedule? schedule,
    _Permissions? permissions,
    _Trips? trips,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (schedule != null)
            scheduleTripProvider.overrideWith(() => schedule),
          if (permissions != null)
            appPermissionServiceProvider.overrideWithValue(permissions),
          if (trips != null) tripServiceProvider.overrideWithValue(trips),
        ],
        child: MaterialApp(theme: AppTheme.darkTheme, home: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  void replaceSession() {
    AccountContext.changes.value++;
  }

  for (final stale in [false, true]) {
    testWidgets(
      '${stale ? 'retained' : 'current'} empty bookings schedule ${stale ? 'cannot enter a replacement account' : 'remains usable'}',
      (tester) async {
        final storedTrips = List<Trip>.of(AppConstants.mockTrips);
        AppConstants.mockTrips.clear();
        addTearDown(() => AppConstants.mockTrips.addAll(storedTrips));
        var schedules = 0;
        await mount(
          tester,
          BookingsScreen(
            mode: 'driver',
            onModeChanged: (_) {},
            onSchedule: () => schedules++,
            onTripDetails: (_) {},
          ),
        );
        final schedule = tester
            .widget<AiEmptyState>(find.byType(AiEmptyState))
            .onAction!;
        if (stale) replaceSession();
        schedule();
        await tester.pumpAndSettle();
        expect(schedules, stale ? 0 : 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'initial scheduler permission reply cannot prompt after replacement',
    (tester) async {
      final permissions = _Permissions();
      final controller = _Schedule();
      await mount(
        tester,
        ScheduleTripScreen(
          mode: 'passenger',
          onModeChanged: (_) {},
          onBack: () {},
        ),
        schedule: controller,
        permissions: permissions,
      );
      expect(permissions.reads, 1);
      final routeForm = tester.widget<TripRouteForm>(
        find.byType(TripRouteForm),
      );
      replaceSession();
      permissions.pending.complete(false);
      routeForm.onHandleCurrentLocation();
      routeForm.onOriginSelected(
        const PlaceDetails(
          placeId: 'old',
          formattedAddress: 'Old private pickup',
          latitude: -1,
          longitude: 30,
        ),
      );
      await tester.pumpAndSettle();
      expect(permissions.reads, 1);
      expect(permissions.prompts, 0);
      expect(controller.locations, 0);
      expect(controller.origins, 0);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Account changed. Close this view.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'retained bookings cancel callback cannot mutate another generation',
    (tester) async {
      await mount(
        tester,
        BookingsScreen(
          mode: 'driver',
          onModeChanged: (_) {},
          onSchedule: () {},
          onTripDetails: (_) {},
        ),
      );
      final cancel = find.text('Cancel').first;
      final callback = tester
          .widget<InkWell>(
            find.ancestor(of: cancel, matching: find.byType(InkWell)).first,
          )
          .onTap!;
      final count = find.text('Cancel').evaluate().length;
      replaceSession();
      callback();
      await tester.pumpAndSettle();
      expect(find.text('Cancel').evaluate().length, count);
      expect(tester.takeException(), isNull);
    },
  );

  for (final lateDialog in [false, true]) {
    testWidgets(
      'trip cancellation rejects ${lateDialog ? 'confirmed old dialog' : 'retained old callback'}',
      (tester) async {
        AppConstants.mockTrips.add(_ownTrip);
        addTearDown(() => AppConstants.mockTrips.remove(_ownTrip));
        final trips = _Trips();
        await mount(
          tester,
          TripDetailsScreen(tripId: _ownTrip.id!, onBack: () {}),
          trips: trips,
        );
        final callback = tester
            .widget<TextButton>(
              find
                  .ancestor(
                    of: find.text('Cancel trip'),
                    matching: find.byType(TextButton),
                  )
                  .first,
            )
            .onPressed!;
        if (lateDialog) {
          callback();
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsOneWidget);
          final confirm = tester
              .widget<InkWell>(
                find
                    .ancestor(
                      of: find.text('Cancel trip').last,
                      matching: find.byType(InkWell),
                    )
                    .first,
              )
              .onTap!;
          replaceSession();
          confirm();
        } else {
          replaceSession();
          callback();
        }
        await tester.pumpAndSettle();
        expect(trips.cancels, 0);
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('current trip confirmation cancels the rendered trip once', (
    tester,
  ) async {
    AppConstants.mockTrips.add(_ownTrip);
    addTearDown(() => AppConstants.mockTrips.remove(_ownTrip));
    final trips = _Trips();
    var backs = 0;
    await mount(
      tester,
      TripDetailsScreen(tripId: _ownTrip.id!, onBack: () => backs++),
      trips: trips,
    );
    tester
        .widget<TextButton>(
          find
              .ancestor(
                of: find.text('Cancel trip'),
                matching: find.byType(TextButton),
              )
              .first,
        )
        .onPressed!();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel trip').last);
    await tester.pumpAndSettle();
    expect(trips.cancels, 1);
    expect(backs, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('current scheduler callback can use a granted location', (
    tester,
  ) async {
    final permissions = _Permissions()..pending.complete(true);
    final controller = _Schedule();
    await mount(
      tester,
      ScheduleTripScreen(
        mode: 'passenger',
        onModeChanged: (_) {},
        onBack: () {},
      ),
      schedule: controller,
      permissions: permissions,
    );
    tester
        .widget<TripRouteForm>(find.byType(TripRouteForm))
        .onHandleCurrentLocation();
    await tester.pumpAndSettle();
    expect(controller.locations, 1);
    expect(permissions.prompts, 0);
    expect(tester.takeException(), isNull);
  });
}
