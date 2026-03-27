import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/providers/app_providers.dart';

void main() {
  group('App Providers', () {
    test('modeProvider defaults to passenger', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(modeProvider), 'passenger');
    });

    test('modeProvider can switch to driver', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(modeProvider.notifier).set('driver');
      expect(container.read(modeProvider), 'driver');
    });

    test('roleProvider defaults to passenger', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(roleProvider), 'passenger');
    });

    test('roleProvider can switch to admin', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(roleProvider.notifier).set('admin');
      expect(container.read(roleProvider), 'admin');
    });

    test('activeTripProvider defaults to null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(activeTripProvider), isNull);
    });
  });
}
