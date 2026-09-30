import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_nfc_write_card_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_scan_screen.dart';
import 'package:mobi_app/features/bookings/presentation/bookings_screen.dart';
import 'package:mobi_app/features/bookings/presentation/schedule_trip_screen.dart';
import 'package:mobi_app/features/chat/presentation/widgets/chat_composer.dart';
import 'package:mobi_app/features/home/presentation/home_screen.dart';
import 'package:mobi_app/features/profile/presentation/edit_profile_screen.dart';
import 'package:mobi_app/shared/widgets/mobi_page_header.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

import '../../helpers/biopay_nfc_test_channels.dart';
import '../../helpers/mobile_scanner_test_channel.dart';

void main() {
  setUpAll(installMobileScannerTestChannel);
  tearDownAll(uninstallMobileScannerTestChannel);
  setUp(installBioPayNfcTestChannels);
  tearDown(uninstallBioPayNfcTestChannels);

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

  testWidgets('desktop Admin wordmark stays inside its sidebar at 2x text', (
    tester,
  ) async {
    await pumpAccessibilitySubject(
      tester,
      const AdminWorkspaceFrame(
        title: 'Reports',
        subtitle: 'Chat safety and user blocks.',
        currentTab: AdminWorkspaceTab.reports,
        child: SizedBox.expand(),
      ),
      size: const Size(1280, 720),
    );
    final wordmark = tester.getRect(find.text('Mobio'));
    expect(wordmark.left, greaterThanOrEqualTo(24));
    expect(wordmark.right, lessThanOrEqualTo(216 - 24));
    expect(find.text('Mobio'), findsOneWidget);
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
          onChatPerson: (_) {},
          onTripDetails: (_) {},
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
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
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
