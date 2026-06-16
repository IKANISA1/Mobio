import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/services/public_transport_service.dart';
import 'package:mobi_app/core/theme/app_theme.dart';
import 'package:mobi_app/features/profile/widgets/profile_vehicle_section.dart';
import 'package:mobi_app/models/vehicle_type_model.dart';

void main() {
  testWidgets('ProfileVehicleSection shows bus fields only for bus drivers', (
    tester,
  ) async {
    final plateController = TextEditingController();
    final agencyController = TextEditingController();
    final capacityController = TextEditingController();
    final rentalModelController = TextEditingController();
    addTearDown(plateController.dispose);
    addTearDown(agencyController.dispose);
    addTearDown(capacityController.dispose);
    addTearDown(rentalModelController.dispose);

    Future<void> pump(String selectedVehicleId) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileVehicleSection(
                vehicleTypes: VehicleTypeModel.fallbackTypes,
                selectedVehicleId: selectedVehicleId,
                onVehicleTypeChanged: (_) {},
                plateController: plateController,
                busAgencyController: agencyController,
                busCapacityController: capacityController,
                rentalModelController: rentalModelController,
                transportAgencyNames:
                    PublicTransportService.fallbackAgencyNames,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump('cab');
    expect(find.text('Number plate'), findsOneWidget);
    expect(
      find.text('One free trip credit every day for 12 months.'),
      findsNothing,
    );
    expect(find.text('Bus details'), findsNothing);
    expect(find.text('Select agency'), findsNothing);
    expect(find.widgetWithText(TextField, 'Passenger capacity'), findsNothing);

    await pump('moto');
    expect(
      find.text('One free trip credit every day for 12 months.'),
      findsOneWidget,
    );

    await pump('private');
    expect(
      find.text('One free trip credit every day for 30 days.'),
      findsOneWidget,
    );

    await pump('bus');
    expect(find.text('Bus details'), findsOneWidget);
    expect(find.text('Select agency'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'Passenger capacity'),
      findsOneWidget,
    );

    await pump('rentals');
    expect(find.text('Rental model'), findsOneWidget);
    expect(
      find.text('One free trip credit every day for 30 days.'),
      findsOneWidget,
    );
    for (final model in ProfileVehicleSection.rentalModelOptions) {
      expect(find.text(model), findsWidgets);
    }

    await pump('private');
    expect(find.text('Vehicle model'), findsOneWidget);
    expect(find.text('Rental model'), findsNothing);
    for (final model in ProfileVehicleSection.rentalModelOptions) {
      expect(find.text(model), findsWidgets);
    }
  });
}
