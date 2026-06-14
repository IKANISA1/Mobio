import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/models/vehicle_type_model.dart';
import 'package:mobi_app/shared/widgets/vehicle_type_icon.dart';

void main() {
  testWidgets('trike renders the cargo tricycle SVG icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VehicleTypeIcon(
            vehicleType: VehicleTypeModel(
              id: 'trike',
              label: 'Trike',
              iconName: 'truck',
            ),
            size: 24,
            color: Colors.white,
          ),
        ),
      ),
    );

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(svg.semanticsLabel, 'Cargo tricycle');
  });

  testWidgets('fromId routes trike through the same SVG icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VehicleTypeIcon.fromId(
            vehicleTypeId: 'trike',
            size: 24,
            color: Colors.white,
          ),
        ),
      ),
    );

    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('private vehicle renders the private car SVG icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VehicleTypeIcon(
            vehicleType: VehicleTypeModel(
              id: 'private',
              label: 'Others',
              iconName: 'package',
            ),
            size: 24,
            color: Colors.white,
          ),
        ),
      ),
    );

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(svg.semanticsLabel, 'Private vehicle');
  });

  testWidgets('rentals render the rental vehicle SVG icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VehicleTypeIcon(
            vehicleType: VehicleTypeModel(
              id: 'rentals',
              label: 'Rentals',
              iconName: 'key-round',
            ),
            size: 24,
            color: Colors.white,
          ),
        ),
      ),
    );

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(svg.semanticsLabel, 'Rental vehicle');
  });
}
