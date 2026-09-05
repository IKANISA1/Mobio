import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/shared/widgets/place_autocomplete_field.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
  testWidgets('PlaceAutocompleteField keeps a tall route input lane', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: PlaceAutocompleteField(
                label: 'From',
                placeholder: 'Departure location',
                iconBg: const Color(0xFF3C1F2A),
                iconColor: Colors.white,
                icon: LucideIcons.mapPin,
                onPlaceSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final textFieldSize = tester.getSize(find.byType(TextField));
    final iconSize = tester.getSize(find.byIcon(LucideIcons.mapPin));

    expect(textFieldSize.height, greaterThanOrEqualTo(46));
    expect(iconSize.width, greaterThanOrEqualTo(24));
  });
}
