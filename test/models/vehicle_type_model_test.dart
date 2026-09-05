import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/shared/models/vehicle_type_model.dart';

void main() {
  test('fallback vehicle types use the canonical display order', () {
    expect(VehicleTypeModel.fallbackTypes.map((type) => type.label), [
      'Moto Taxi',
      'Bus',
      'Cab',
      'Truck',
      'Trike',
      'Others',
      'Rentals',
    ]);
  });

  test('ordered normalizes remote vehicle type rows to canonical order', () {
    final unordered = [
      const VehicleTypeModel(id: 'private', label: 'Others', sortOrder: 1),
      const VehicleTypeModel(id: 'rentals', label: 'Rentals', sortOrder: 1),
      const VehicleTypeModel(id: 'truck', label: 'Truck', sortOrder: 2),
      const VehicleTypeModel(id: 'trike', label: 'Trike', sortOrder: 3),
      const VehicleTypeModel(id: 'bus', label: 'Bus', sortOrder: 4),
      const VehicleTypeModel(id: 'cab', label: 'Cab', sortOrder: 5),
      const VehicleTypeModel(id: 'moto', label: 'Moto Taxi', sortOrder: 6),
    ];

    expect(VehicleTypeModel.ordered(unordered).map((type) => type.label), [
      'Moto Taxi',
      'Bus',
      'Cab',
      'Truck',
      'Trike',
      'Others',
      'Rentals',
    ]);
  });
}
