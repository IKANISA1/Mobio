import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/bookings/presentation/widgets/trip_vehicle_grid.dart';
import 'package:mobi_app/shared/models/vehicle_type_model.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
  testWidgets('TripVehicleGrid gives vehicle cards distinct color palettes', (
    tester,
  ) async {
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: TripVehicleGrid(
              vehicleTypes: VehicleTypeModel.fallbackTypes,
              selectedVehicleId: 'private',
              onSelected: (id) => selected = id,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Moto Taxi'), findsOneWidget);
    expect(find.text('Bus'), findsOneWidget);
    expect(find.text('Cab'), findsOneWidget);
    expect(find.text('Others'), findsOneWidget);

    final decoratedTiles = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .where((widget) {
          final decoration = widget.decoration;
          return decoration is BoxDecoration && decoration.gradient != null;
        })
        .toList();

    expect(decoratedTiles, hasLength(VehicleTypeModel.fallbackTypes.length));

    final firstGradientColors = decoratedTiles.map((widget) {
      final decoration = widget.decoration! as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;
      return gradient.colors.first;
    }).toSet();

    expect(firstGradientColors.length, greaterThan(3));

    await tester.tap(find.text('Cab'));
    await tester.pumpAndSettle();

    expect(selected, 'cab');
  });
}
