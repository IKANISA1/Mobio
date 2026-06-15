import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_theme.dart';
import 'package:mobi_app/features/biopay/biopay_screen.dart';
import 'package:mobi_app/features/bookings/bookings_screen.dart';
import 'package:mobi_app/features/bookings/schedule_trip_screen.dart';
import 'package:mobi_app/features/chat/widgets/chat_composer.dart';
import 'package:mobi_app/features/home/home_screen.dart';
import 'package:mobi_app/features/profile/edit_profile_screen.dart';
import 'package:mobi_app/shared/widgets/mobi_page_header.dart';

import '../../helpers/mobile_scanner_test_channel.dart';

void main() {
  setUpAll(installMobileScannerTestChannel);
  tearDownAll(uninstallMobileScannerTestChannel);

  Future<void> pumpAccessibilitySubject(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 844),
    double textScale = 2,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
            ),
            child: Scaffold(body: child),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pushed page header keeps large-text back control tappable', (
    tester,
  ) async {
    var backCount = 0;

    await pumpAccessibilitySubject(
      tester,
      MobiPageHeader(
        title: 'Very long pushed page title for accessibility proof',
        onBack: () => backCount += 1,
      ),
      size: const Size(320, 240),
    );

    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    final backSize = tester.getSize(find.bySemanticsLabel('Back'));
    expect(backSize.width, greaterThanOrEqualTo(48));
    expect(backSize.height, greaterThanOrEqualTo(48));

    await tester.tap(find.bySemanticsLabel('Back'));
    expect(backCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text does not break core mobile preview surfaces', (
    tester,
  ) async {
    final surfaces = <({String name, Widget child})>[
      (
        name: 'home',
        child: HomeScreen(
          mode: 'passenger',
          onModeChanged: (_) {},
          onChat: (_) {},
          onViewNearby: () {},
          onViewBookings: () {},
          onSchedule: () {},
        ),
      ),
      (
        name: 'bookings',
        child: BookingsScreen(
          mode: 'passenger',
          onModeChanged: (_) {},
          onSchedule: () {},
          onTripDetails: (_) {},
        ),
      ),
      (
        name: 'schedule',
        child: ScheduleTripScreen(
          mode: 'passenger',
          onModeChanged: (_) {},
          onBack: () {},
        ),
      ),
      (
        name: 'profile setup',
        child: EditProfileScreen(isFirstRun: true, onBack: () {}),
      ),
      (name: 'biopay scan', child: BioPayScanScreen(onBack: () {})),
      (
        name: 'biopay nfc write',
        child: BioPayNfcWriteCardScreen(onBack: () {}),
      ),
    ];

    for (final surface in surfaces) {
      await pumpAccessibilitySubject(tester, surface.child);
      expect(tester.takeException(), isNull, reason: surface.name);
    }
  });

  testWidgets('chat composer supports focus and icon send at large text', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    var sendCount = 0;

    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await pumpAccessibilitySubject(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: ChatComposer(
          controller: controller,
          focusNode: focusNode,
          isSending: false,
          onSendMessage: () => sendCount += 1,
        ),
      ),
      size: const Size(390, 320),
    );

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Pickup at 8');
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isTrue);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(sendCount, 1);

    await tester.tap(find.byIcon(LucideIcons.send));
    await tester.pump();
    expect(sendCount, 2);
    expect(tester.takeException(), isNull);
  });
}
