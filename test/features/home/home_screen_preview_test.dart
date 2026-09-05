import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/home/presentation/home_screen.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
  testWidgets('HomeScreen local preview fits narrow mobile viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: HomeScreen(
              mode: 'passenger',
              onModeChanged: (_) {},
              onChat: (_) {},
              onViewNearby: () {},
              onViewBookings: () {},
              onSchedule: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nearby'), findsWidgets);
    expect(find.text('Driver supply'), findsNothing);
    expect(find.text('Passenger demand'), findsNothing);
    expect(find.textContaining('Coordinate pick up'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
