import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/bookings/presentation/bookings_screen.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
  testWidgets('BookingsScreen local preview does not require Supabase', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: BookingsScreen(
              mode: 'passenger',
              onModeChanged: (_) {},
              onSchedule: () {},
              onTripDetails: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trips'), findsOneWidget);
    expect(find.textContaining('Coordinate pick up'), findsNothing);
    expect(find.textContaining('active records'), findsNothing);
    expect(find.text('Plan, track, and manage rides'), findsNothing);
    expect(find.textContaining('Supabase'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
