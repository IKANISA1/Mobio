import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/profile/providers/edit_profile_provider.dart';

void main() {
  test('Others driver profile requires a selected vehicle model', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(editProfileProvider.future);
    final controller = container.read(editProfileProvider.notifier)
      ..setVehicleTypeId('private');

    await expectLater(
      controller.saveProfile(
        momoNumber: '0788767816',
        momoPayCode: '123456',
        vehicleNumberPlate: 'RAA 123 A',
        busAgencyName: '',
        busPassengerCapacity: '',
        rentalVehicleModel: '',
      ),
      throwsA(
        isA<ValidationException>().having(
          (error) => error.message,
          'message',
          'Select the vehicle model.',
        ),
      ),
    );

    final saved = await controller.saveProfile(
      momoNumber: '0788767816',
      momoPayCode: '123456',
      vehicleNumberPlate: 'RAA 123 A',
      busAgencyName: '',
      busPassengerCapacity: '',
      rentalVehicleModel: 'SUV',
    );

    expect(saved, isTrue);
  });
}
