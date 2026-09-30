import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/bookings/application/booking_services.dart';
import 'package:mobi_app/features/bookings/data/public_transport_service.dart';
import 'package:mobi_app/features/profile/application/edit_profile_provider.dart';

class DelayedAgencyCatalog extends PublicTransportService {
  final replies = <Completer<List<String>>>[];
  @override
  Future<List<String>> getAgencyNames({bool includeInactive = false}) {
    final reply = Completer<List<String>>();
    replies.add(reply);
    return reply.future;
  }
}

void main() {
  test(
    'account invalidation discards the loaded form before a save can dispatch',
    () async {
      final catalog = DelayedAgencyCatalog();
      final container = ProviderContainer(
        overrides: [publicTransportServiceProvider.overrideWithValue(catalog)],
      );
      addTearDown(container.dispose);
      final listener = container.listen(editProfileProvider, (_, _) {});
      addTearDown(listener.close);
      final initial = container.read(editProfileProvider.future);
      await Future<void>.delayed(Duration.zero);
      catalog.replies.single.complete(['A catalog']);
      await initial;
      final controller = container.read(editProfileProvider.notifier);
      AccountContext.changes.value++;
      expect(container.read(editProfileProvider).isLoading, isTrue);
      expect(
        await controller.saveProfile(
          momoNumber: '0788000001',
          momoPayCode: '',
          vehicleNumberPlate: 'RAA 123 A',
          busAgencyName: '',
          busPassengerCapacity: '',
          rentalVehicleModel: '',
        ),
        isFalse,
      );
      await Future<void>.delayed(Duration.zero);
      catalog.replies.last.complete(['B catalog']);
      final reloaded = await container.read(editProfileProvider.future);
      expect(reloaded.transportAgencyNames, ['B catalog']);
    },
  );

  test(
    'an old initial catalog cannot hydrate the replacement generation',
    () async {
      final catalog = DelayedAgencyCatalog();
      final container = ProviderContainer(
        overrides: [publicTransportServiceProvider.overrideWithValue(catalog)],
      );
      addTearDown(container.dispose);
      final listener = container.listen(editProfileProvider, (_, _) {});
      addTearDown(listener.close);
      container.read(editProfileProvider);
      await Future<void>.delayed(Duration.zero);
      AccountContext.changes.value++;
      await Future<void>.delayed(Duration.zero);
      expect(catalog.replies.length, 2);
      catalog.replies.last.complete(['Current catalog']);
      final current = await container.read(editProfileProvider.future);
      catalog.replies.first.complete(['Stale catalog']);
      await Future<void>.delayed(Duration.zero);
      expect(current.transportAgencyNames, ['Current catalog']);
      expect(container.read(editProfileProvider).value!.transportAgencyNames, [
        'Current catalog',
      ]);
    },
  );
}
