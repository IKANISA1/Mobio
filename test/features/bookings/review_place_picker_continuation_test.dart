import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/bookings/presentation/widgets/review_place_picker_field.dart';
import 'package:mobi_design_system/theme/app_theme.dart';
import 'package:mobi_shared_types/models/place.dart';

void main() {
  const place = PlaceDetails(
    placeId: 'review-place',
    formattedAddress: 'Nyabugogo',
    latitude: -1.94,
    longitude: 30.06,
  );

  for (final revokeOriginal in [false, true]) {
    testWidgets(
      revokeOriginal
          ? 'open picker cannot adopt replacement authority or callback'
          : 'open picker keeps its originally captured selection callback',
      (tester) async {
        final replacement = ValueNotifier(false);
        addTearDown(replacement.dispose);
        var originalCurrent = true;
        var originalSelections = 0;
        var replacementSelections = 0;
        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigatorKey,
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: replacement,
                builder: (_, replaced, _) => ReviewPlacePickerField(
                  key: const ValueKey('preserved-picker'),
                  label: 'Destination',
                  placeholder: 'Choose destination',
                  icon: Icons.place,
                  places: const [place],
                  value: null,
                  isCurrent: replaced ? () => true : () => originalCurrent,
                  onSelected: replaced
                      ? (_) => replacementSelections++
                      : (_) => originalSelections++,
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byTooltip('Choose destination'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        originalCurrent = !revokeOriginal;
        replacement.value = true;
        await tester.pump();
        await tester.tap(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text('Nyabugogo'),
          ),
        );
        await tester.pumpAndSettle();
        expect(replacementSelections, 0);
        expect(originalSelections, revokeOriginal ? 0 : 1);
        if (revokeOriginal) {
          expect(find.byType(BottomSheet), findsOneWidget);
          navigatorKey.currentState!.pop(place);
          await tester.pumpAndSettle();
          expect(originalSelections, 0);
          expect(replacementSelections, 0);
        } else {
          expect(find.byType(BottomSheet), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
