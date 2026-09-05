import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/app/app_providers.dart';
import 'package:mobi_app/core/constants/app_enums.dart';

void main() {
  group('App Providers', () {
    test('modeProvider defaults to passenger', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(modeProvider), AppMode.passenger);
    });

    test('modeProvider can switch to driver', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(modeProvider.notifier).set(AppMode.driver);
      expect(container.read(modeProvider), AppMode.driver);
    });

    test('roleProvider defaults to passenger', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(roleProvider), AppRole.passenger);
    });

    test('roleProvider can switch to admin', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(roleProvider.notifier).set(AppRole.admin);
      expect(container.read(roleProvider), AppRole.admin);
    });

    test('activeTripProvider defaults to null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(activeTripProvider), isNull);
    });

    test('AppRole.fromString handles edge cases', () {
      expect(AppRole.fromString(null), AppRole.passenger);
      expect(AppRole.fromString(''), AppRole.passenger);
      expect(AppRole.fromString('admin'), AppRole.admin);
      expect(AppRole.fromString('driver'), AppRole.driver);
      expect(AppRole.fromString('passenger'), AppRole.passenger);
      expect(AppRole.fromString('unknown'), AppRole.passenger);
    });

    test('AppMode.fromString handles edge cases', () {
      expect(AppMode.fromString(null), AppMode.passenger);
      expect(AppMode.fromString(''), AppMode.passenger);
      expect(AppMode.fromString('driver'), AppMode.driver);
      expect(AppMode.fromString('passenger'), AppMode.passenger);
      expect(AppMode.fromString('unknown'), AppMode.passenger);
    });

    test('AppRole convenience getters', () {
      expect(AppRole.admin.isAdmin, isTrue);
      expect(AppRole.admin.isDriver, isFalse);
      expect(AppRole.driver.isDriver, isTrue);
      expect(AppRole.passenger.isPassenger, isTrue);
    });
  });
}
