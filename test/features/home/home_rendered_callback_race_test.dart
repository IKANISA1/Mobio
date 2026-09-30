import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/home/presentation/home_screen.dart';
import 'package:mobi_app/features/home/presentation/widgets/home_header.dart';
import 'package:mobi_app/features/home/presentation/widgets/scheduled_trip_card.dart';
import 'package:mobi_app/shared/widgets/mobi_action_row.dart';
import 'package:mobi_app/shared/widgets/mobi_section_header.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  late Map<String, int> calls;
  void record(String action) =>
      calls.update(action, (value) => value + 1, ifAbsent: () => 1);
  Future<void> mount(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: HomeScreen(
              mode: 'driver',
              onModeChanged: (_) => record('mode'),
              onChat: (_) => record('chat'),
              onChatPerson: (_) => record('person'),
              onTripDetails: (_) => record('details'),
              onViewNearby: () => record('nearby'),
              onViewBookings: () => record('bookings'),
              onSchedule: () => record('schedule'),
              onEvChargers: () => record('ev'),
              onNotifications: () => record('notifications'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => calls = {});

  testWidgets(
    'retained Home mode, navigation, filters and online callbacks stop after replacement',
    (tester) async {
      await mount(tester);
      final header = tester.widget<HomeHeader>(find.byType(HomeHeader));
      final actions = tester
          .widget<MobiActionRow>(find.byType(MobiActionRow))
          .items;
      final scheduled = tester
          .widget<MobiSectionHeader>(
            find.widgetWithText(MobiSectionHeader, 'Scheduled'),
          )
          .onAction!;
      final details = tester
          .widgetList<ScheduledTripCard>(find.byType(ScheduledTripCard))
          .where((card) => card.onTap != null)
          .map((card) => card.onTap!)
          .toList();
      AccountContext.changes.value++;
      header.onModeChanged('passenger');
      header.onNotifications!();
      header.onDriverOnlineToggle!(true);
      for (final action in actions) {
        action.onTap!();
      }
      scheduled();
      for (final detail in details) {
        detail();
      }
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(
        tester.widget<HomeHeader>(find.byType(HomeHeader)).isDriverOnline,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('current Home callbacks retain navigation and online behavior', (
    tester,
  ) async {
    await mount(tester);
    final header = tester.widget<HomeHeader>(find.byType(HomeHeader));
    header.onModeChanged('passenger');
    header.onNotifications!();
    header.onDriverOnlineToggle!(true);
    for (final action
        in tester.widget<MobiActionRow>(find.byType(MobiActionRow)).items) {
      action.onTap!();
    }
    await tester.pumpAndSettle();
    expect(calls, {
      'mode': 1,
      'notifications': 1,
      'bookings': 1,
      'schedule': 1,
      'ev': 1,
    });
    expect(
      tester.widget<HomeHeader>(find.byType(HomeHeader)).isDriverOnline,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
