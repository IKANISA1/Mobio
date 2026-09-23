import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_home_screen.dart';
import 'package:mobi_app/features/bookings/presentation/bookings_screen.dart';
import 'package:mobi_app/features/bookings/presentation/trip_details_screen.dart';
import 'package:mobi_app/features/home/presentation/home_screen.dart';
import 'package:mobi_app/features/home/presentation/widgets/home_hero_card.dart';
import 'package:mobi_app/features/home/presentation/widgets/scheduled_trip_card.dart';
import 'package:mobi_app/features/nearby/presentation/nearby_screen.dart';
import 'package:mobi_app/features/profile/presentation/profile_screen.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_nav.dart';

import '../../../tool/revolut_preview_services.dart';
import '../../../tool/revolut_visual_proof_app.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final size in [const Size(390, 844), const Size(1440, 1000)]) {
    testWidgets('proof harness opens Home and returns through all tabs $size', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = size;
      addTearDown(tester.view.reset);

      // Exercise the real proof host and its existing preview services. This
      // intentionally does not initialize Supabase or a release entrypoint.
      await tester.pumpWidget(
        ProviderScope(
          overrides: revolutPreviewOverrides,
          child: const RevolutVisualProofApp(initialScreen: 'home_shell'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      for (final (label, screenType, selectedIndex) in [
        ('Trips', BookingsScreen, 1),
        ('BioPay', BioPayScreen, 2),
        ('Profile', ProfileScreen, 3),
        ('Home', HomeScreen, 0),
      ]) {
        await tester.tap(find.byTooltip(label));
        await tester.pumpAndSettle();
        expect(find.byType(screenType), findsOneWidget);
        expect(
          tester.widget<MobiBottomNav>(find.byType(MobiBottomNav)).currentIndex,
          selectedIndex,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final direct in [false, true]) {
    testWidgets(
      'Nearby preview returns to Home after ${direct ? 'direct entry' : 'discovery'}',
      (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: revolutPreviewOverrides,
            child: RevolutVisualProofApp(
              initialScreen: direct ? 'nearby' : 'home_shell',
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (!direct) {
          await tester.tap(find.byType(HomeHeroCard));
          await tester.pumpAndSettle();
        }
        expect(find.byType(NearbyScreen), findsOneWidget);
        final back = find.bySemanticsLabel('Back');
        expect(tester.getTopLeft(back).dx, lessThan(80));
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('each scheduled Home card opens its matching trip and returns', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: revolutPreviewOverrides,
        child: const RevolutVisualProofApp(initialScreen: 'home_shell'),
      ),
    );
    await tester.pumpAndSettle();
    final trips = tester
        .widgetList<ScheduledTripCard>(find.byType(ScheduledTripCard))
        .map((card) => card.trip)
        .toList();
    expect(trips, hasLength(3));
    for (final trip in trips) {
      final card = find.byWidgetPredicate(
        (widget) => widget is ScheduledTripCard && widget.trip.id == trip.id,
      );
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TripDetailsScreen>(find.byType(TripDetailsScreen)).tripId,
        trip.id,
      );
      expect(find.text('${trip.origin} → ${trip.destination}'), findsOneWidget);
      expect(find.text('Fare'), findsNothing);
      expect(find.text('active'), findsNothing);
      expect(find.text('approved'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'preview workspace modules follow their real route destinations',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1280, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: revolutPreviewOverrides,
          child: const RevolutVisualProofApp(initialScreen: 'admin_dashboard'),
        ),
      );
      await tester.pumpAndSettle();
      for (final (label, tab) in [
        ('Users', AdminWorkspaceTab.users),
        ('Fleet', AdminWorkspaceTab.fleet),
        ('Agencies', AdminWorkspaceTab.agencies),
        ('EV', AdminWorkspaceTab.evChargers),
        ('Plans', AdminWorkspaceTab.subscriptions),
        ('Trips', AdminWorkspaceTab.trips),
        ('Reports', AdminWorkspaceTab.reports),
        ('BioPay', AdminWorkspaceTab.biopayOps),
        ('Health', AdminWorkspaceTab.health),
        ('Audit', AdminWorkspaceTab.audit),
        ('Broadcasts', AdminWorkspaceTab.broadcasts),
        ('Ops', AdminWorkspaceTab.overview),
      ]) {
        final target = find.bySemanticsLabel(RegExp('^$label\$')).first;
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AdminWorkspaceFrame>(find.byType(AdminWorkspaceFrame))
              .currentTab,
          tab,
        );
        expect(tester.takeException(), isNull, reason: label);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
