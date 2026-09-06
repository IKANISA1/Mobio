import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/location/location_access_state.dart';
import 'package:mobi_app/features/home/presentation/widgets/home_hero_card.dart';
import 'package:mobi_app/features/nearby/presentation/widgets/nearby_location_notice.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
  for (final state in [
    LocationAccessState.denied,
    LocationAccessState.unavailable,
  ]) {
    testWidgets('$state shows recovery with no zero-results claim', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var enabled = 0;
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: NearbyLocationNotice(
                  accessState: state,
                  onEnableLocation: () => enabled++,
                  onRetry: () => retries++,
                ),
              ),
            ),
          ),
        ),
      );
      final title = state == LocationAccessState.denied
          ? 'Enable location'
          : 'Location unavailable';
      expect(find.text(title), findsOneWidget);
      expect(find.text('No drivers nearby'), findsNothing);
      await tester.tap(find.text(title));
      expect(enabled, state == LocationAccessState.denied ? 1 : 0);
      expect(retries, state == LocationAccessState.unavailable ? 1 : 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Home distinguishes unknown count from a successful zero', (
    tester,
  ) async {
    Future<void> show(int? count) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: HomeHeroCard(isDriver: false, nearbyCount: count, onTap: () {}),
        ),
      ),
    );
    await show(null);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    await show(0);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('—'), findsNothing);
  });
}
