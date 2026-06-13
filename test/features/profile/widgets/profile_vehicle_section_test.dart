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
    addTearDown(plateController.dispose);
    addTearDown(agencyController.dispose);
    addTearDown(capacityController.dispose);

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
    expect(find.text('Bus details'), findsNothing);
    expect(find.text('Select agency'), findsNothing);
    expect(find.widgetWithText(TextField, 'Passenger capacity'), findsNothing);

    await pump('bus');
    expect(find.text('Bus details'), findsOneWidget);
    expect(find.text('Select agency'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'Passenger capacity'),
      findsOneWidget,
    );
  });
}
