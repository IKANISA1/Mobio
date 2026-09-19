import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/home/presentation/widgets/home_header.dart';
import 'package:mobi_app/shared/widgets/mobi_toggle.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
  testWidgets('Home modes expose single names and full-height touch targets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    try {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        String? chosen;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: HomeHeader(
                isDriver: false,
                unreadCount: 0,
                onModeChanged: (value) => chosen = value,
                onNotifications: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final label in ['Passenger', 'Driver']) {
          final target = find.bySemanticsLabel(RegExp('^$label\$'));
          expect(target, findsOneWidget);
          final rect = tester.getRect(target);
          expect(rect.height, greaterThanOrEqualTo(48));
          // The former five-point visual padding must also receive pointer taps.
          await tester.tapAt(Offset(rect.center.dx, rect.top + 2));
          await tester.pump();
          expect(chosen, label.toLowerCase());
        }
        expect(find.bySemanticsLabel('Passenger Passenger'), findsNothing);
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('shared account toggle padding accepts taps for both modes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      int? chosen;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: MobiToggle(
              labels: const ['Passenger', 'Driver'],
              selectedIndex: 0,
              onChanged: (value) => chosen = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final (index, label) in ['Passenger', 'Driver'].indexed) {
        final rect = tester.getRect(find.bySemanticsLabel(label));
        expect(rect.height, greaterThanOrEqualTo(48));
        await tester.tapAt(Offset(rect.center.dx, rect.top + 2));
        await tester.pump();
        expect(chosen, index);
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('driver availability has a named 48-point target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      bool? online;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: HomeHeader(
              isDriver: true,
              isDriverOnline: false,
              unreadCount: 0,
              onModeChanged: (_) {},
              onDriverOnlineToggle: (value) => online = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final target = find.bySemanticsLabel('Driver availability');
      final rect = tester.getRect(target);
      expect(rect.height, greaterThanOrEqualTo(48));
      await tester.tapAt(Offset(rect.center.dx, rect.top + 2));
      await tester.pump();
      expect(online, true);
    } finally {
      semantics.dispose();
    }
  });
}
