import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/app/app_providers.dart';
import 'package:mobi_app/app/router/app_router.dart';
import 'package:mobi_app/app/theme_provider.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_face_enroll_screen.dart'
    deferred as enroll_screen;
import 'package:mobi_app/features/biopay/presentation/biopay_face_scan_screen.dart'
    deferred as face_screen;
import 'package:mobi_app/features/biopay/presentation/biopay_nfc_screen.dart'
    deferred as nfc_screen;
import 'package:mobi_app/features/biopay/presentation/biopay_scan_screen.dart'
    deferred as scan_screen;
import 'package:mobi_app/features/biopay/presentation/payment_discovery_routes.dart'
    deferred as payment_screen;
import 'package:mobi_app/features/bookings/presentation/trip_details_screen.dart'
    deferred as trip_screen;
import 'package:mobi_app/features/chat/presentation/chat_screen.dart'
    deferred as chat_screen;
import 'package:mobi_app/features/home/presentation/widgets/scheduled_trip_card.dart';
import 'package:mobi_app/features/profile/presentation/edit_profile_screen.dart'
    deferred as profile_screen;
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

import '../../../tool/revolut_preview_services.dart';
import '../../helpers/mobile_scanner_test_channel.dart';
import '../../helpers/payment_discovery_fixture.dart';

void main() {
  setUpAll(() async {
    installMobileScannerTestChannel();
    // Complete VM library futures outside individual fake-async test zones.
    // Cached completion callbacks otherwise remain tied to a disposed test.
    await Future.wait([
      chat_screen.loadLibrary(),
      profile_screen.loadLibrary(),
      trip_screen.loadLibrary(),
      payment_screen.loadLibrary(),
      scan_screen.loadLibrary(),
      face_screen.loadLibrary(),
      enroll_screen.loadLibrary(),
      nfc_screen.loadLibrary(),
    ]);
  });
  tearDownAll(uninstallMobileScannerTestChannel);

  testWidgets(
    'Home scheduled cards open exact trips with touch, keyboard and semantics',
    (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      try {
        final theme = ThemeProvider();
        addTearDown(theme.dispose);
        final router = createRouter();
        addTearDown(router.dispose);
        router.go('/home');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...revolutPreviewOverrides,
              themeProviderProvider.overrideWithValue(theme),
            ],
            child: MaterialApp.router(
              theme: AppTheme.darkTheme,
              routerConfig: router,
            ),
          ),
        );
        await settleRoute(tester);
        final trips = tester
            .widgetList<ScheduledTripCard>(find.byType(ScheduledTripCard))
            .map((card) => card.trip)
            .toList();
        expect(trips, hasLength(3));
        for (final (index, trip) in trips.indexed) {
          final card = find.byWidgetPredicate(
            (widget) =>
                widget is ScheduledTripCard && widget.trip.id == trip.id,
          );
          await tester.ensureVisible(card);
          await tester.pumpAndSettle();
          final target = find.descendant(
            of: card,
            matching: find.byType(InkWell),
          );
          if (index == 0) {
            await tester.tap(card);
          } else if (index == 1) {
            final content = find
                .descendant(of: card, matching: find.byType(Text))
                .first;
            Focus.of(tester.element(content)).requestFocus();
            await tester.pump();
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          } else {
            final node = tester.getSemantics(target);
            expect(node.label, contains(trip.origin));
            expect(node.flagsCollection.isButton, isTrue);
            tester.binding.renderViews.first.owner!.semanticsOwner!
                .performAction(node.id, SemanticsAction.tap);
          }
          await settleRoute(tester);
          expect(router.state.uri.path, '/trip/${trip.id}');
          expect(
            find.text('${trip.origin} → ${trip.destination}'),
            findsOneWidget,
          );
          await tester.tap(find.bySemanticsLabel('Back'));
          await settleRoute(tester);
          expect(router.routeInformationProvider.value.uri.path, '/home');
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        semantics.dispose();
      }
    },
  );

  const routes = {
    '/nearby': '/home',
    '/ledger': '/home',
    '/admin-auth': '/home',
    '/ev-chargers': '/home',
    '/notifications': '/home',
    '/schedule': '/home',
    '/trip/t1': '/home',
    '/trip/t1/edit': '/home',
    '/chat': '/home',
    '/edit-profile': '/profile',
    '/profile/setup': '/home',
    '/wallet': '/profile',
    '/mobio-plus': '/profile',
    '/biopay/send': '/biopay',
    '/profile/payment-methods': '/profile',
    '/biopay/requests': '/biopay',
    '/biopay/activity': '/biopay',
    '/biopay/recents': '/biopay',
    '/biopay/templates': '/biopay',
    '/biopay/request-payment': '/biopay',
    '/biopay/qr': '/biopay',
    '/biopay/pay/0123456789abcdef0123456789abcdef0123456789abcdef': '/biopay',
    '/biopay/scan': '/biopay',
    '/biopay/face-scan': '/biopay',
    '/biopay/enroll': '/biopay',
    '/biopay/nfc': '/biopay',
    '/biopay/nfc/write-card': '/profile',
  };

  for (final entry in routes.entries) {
    for (final direct in [false, true]) {
      testWidgets(
        '${entry.key} returns after ${direct ? 'direct entry' : 'push'}',
        (tester) async {
          tester.view
            ..physicalSize = const Size(390, 844)
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final theme = ThemeProvider();
          addTearDown(theme.dispose);
          final router = createRouter();
          addTearDown(router.dispose);
          router.go(direct ? entry.key : '/bookings');
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                ...revolutPreviewOverrides,
                themeProviderProvider.overrideWithValue(theme),
                paymentDiscoveryServiceProvider.overrideWithValue(
                  PaymentDiscoveryFixture(),
                ),
              ],
              child: MaterialApp.router(
                theme: AppTheme.darkTheme,
                routerConfig: router,
              ),
            ),
          );
          await settleRoute(tester);
          if (!direct) {
            router.push<void>(entry.key);
            await settleRoute(tester);
          }
          final screenType = loadedScreenType(entry.key);
          if (screenType != null) {
            expect(find.byType(screenType), findsOneWidget);
          }
          final tooltipBack = find.byTooltip('Back');
          final back = tooltipBack.evaluate().isNotEmpty
              ? tooltipBack
              : find.bySemanticsLabel('Back');
          expect(back, findsOneWidget);
          expect(
            tester.getTopLeft(back).dx,
            lessThan(80),
            reason: 'Return must be at the leading edge.',
          );
          await tester.tap(back);
          await settleRoute(tester);
          expect(
            router.routeInformationProvider.value.uri.path,
            direct ? entry.value : '/bookings',
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}

Future<void> settleRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  // Deferred Dart libraries complete on the real event loop, outside fake time.
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(LoadingSkeleton).evaluate().isEmpty) break;
  }
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

Type? loadedScreenType(String location) => switch (location) {
  '/chat' => chat_screen.TripChatScreen,
  '/edit-profile' || '/profile/setup' => profile_screen.EditProfileScreen,
  '/trip/t1' => trip_screen.TripDetailsScreen,
  '/biopay/send' => payment_screen.PaymentComposerScreen,
  '/profile/payment-methods' => payment_screen.PaymentMethodsScreen,
  '/biopay/requests' ||
  '/biopay/activity' ||
  '/biopay/recents' ||
  '/biopay/templates' => payment_screen.PaymentLibraryScreen,
  '/biopay/request-payment' ||
  '/biopay/qr' => payment_screen.PaymentRequestEditor,
  '/biopay/nfc/write-card' => payment_screen.PaymentNfcLinkScreen,
  '/biopay/scan' => scan_screen.BioPayScanScreen,
  '/biopay/face-scan' => face_screen.BioPayFaceScanScreen,
  '/biopay/enroll' => enroll_screen.BioPayFaceEnrollScreen,
  '/biopay/nfc' => nfc_screen.BioPayNfcScreen,
  _ => null,
};
