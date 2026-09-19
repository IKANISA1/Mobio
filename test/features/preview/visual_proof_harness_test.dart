import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_home_screen.dart';
import 'package:mobi_app/features/bookings/presentation/bookings_screen.dart';
import 'package:mobi_app/features/home/presentation/home_screen.dart';
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
}
