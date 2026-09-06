import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/app/app_providers.dart';
import 'package:mobi_app/app/router/app_router.dart';
import 'package:mobi_app/core/constants/app_enums.dart';
import 'package:mobi_app/features/bookings/presentation/bookings_screen.dart';
import 'package:mobi_app/features/home/presentation/home_screen.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_nav.dart';
import 'package:mobi_app/shared/widgets/mobi_section_header.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
  for (final (mode, size, section) in [
    (AppMode.passenger, const Size(390, 844), 'Scheduled'),
    (AppMode.driver, const Size(900, 1000), 'Passenger requests'),
  ]) {
    testWidgets('${mode.name} Home shortcut selects the Trips tab', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = size;
      addTearDown(tester.view.reset);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(modeProvider.notifier).set(mode);
      final router = createRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.darkTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      int selectedTab() => size.width < 720
          ? tester
                .widget<MobiBottomNav>(find.byType(MobiBottomNav))
                .currentIndex
          : tester
                .widget<NavigationRail>(find.byType(NavigationRail))
                .selectedIndex!;

      expect(selectedTab(), 0);
      final shortcut = find.descendant(
        of: find.widgetWithText(MobiSectionHeader, section),
        matching: find.text('All'),
      );
      await tester.ensureVisible(shortcut);
      await tester.tap(shortcut);
      await tester.pumpAndSettle();
      expect(find.byType(BookingsScreen), findsOneWidget);
      expect(selectedTab(), 1);

      await tester.tap(find.byTooltip('Home'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(BookingsScreen), findsNothing);
      expect(selectedTab(), 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
