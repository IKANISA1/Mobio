import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/notifications/application/notification_services.dart';
import 'package:mobi_app/features/notifications/data/notification_consent_service.dart';
import 'package:mobi_app/features/profile/application/notification_consent_provider.dart';
import 'package:mobi_shared_types/models/notification_consent_settings.dart';

class _Consent extends Fake implements NotificationConsentService {
  final pending = <Completer<NotificationConsentSettings>>[];
  final submitted = <NotificationConsentSettings>[];
  @override
  Future<NotificationConsentSettings> getSettings() async =>
      const NotificationConsentSettings();
  @override
  Future<NotificationConsentSettings> saveSettings(
    NotificationConsentSettings settings,
  ) {
    submitted.add(settings);
    final result = Completer<NotificationConsentSettings>();
    pending.add(result);
    return result.future;
  }
}

Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Consent service;
  var generation = 0;
  setUp(() {
    generation = 0;
    service = _Consent();
    container = ProviderContainer(
      overrides: [
        notificationConsentProvider.overrideWith(
          () => NotificationConsentController.test(
            captureAccount: () =>
                AccountSnapshot('user', 'session', generation),
            isCurrent: (snapshot) => snapshot.generation == generation,
          ),
        ),
        notificationConsentServiceProvider.overrideWithValue(service),
      ],
    )..listen(notificationConsentProvider, (_, _) {});
    addTearDown(container.dispose);
  });

  test(
    'older failed write cannot roll back the newer optimistic choice',
    () async {
      await container.read(notificationConsentProvider.future);
      final controller = container.read(notificationConsentProvider.notifier);
      final old = controller.setPromotionalInApp(true);
      final oldFailure = expectLater(old, throwsStateError);
      final latest = controller.setPromotionalPush(true);
      await _tick();
      expect(service.pending, hasLength(1));
      service.pending.first.completeError(StateError('lost old write'));
      await oldFailure;
      await _tick();
      expect(service.pending, hasLength(2));
      expect(
        container.read(notificationConsentProvider).value?.promotionalPush,
        isTrue,
      );
      service.pending.last.complete(service.submitted.last);
      await latest;
      expect(
        container.read(notificationConsentProvider).value?.promotionalInApp,
        isTrue,
      );
      expect(
        container.read(notificationConsentProvider).value?.promotionalPush,
        isTrue,
      );
    },
  );

  test(
    'account invalidation drops a queued save and late acknowledgement',
    () async {
      await container.read(notificationConsentProvider.future);
      final controller = container.read(notificationConsentProvider.notifier);
      final old = controller.setPromotionalInApp(true);
      final oldFailure = expectLater(old, throwsA(isA<StaleAccountWork>()));
      final queued = controller.setPromotionalPush(true);
      final queuedFailure = expectLater(
        queued,
        throwsA(isA<StaleAccountWork>()),
      );
      await _tick();
      generation++;
      AccountContext.changes.value++;
      await _tick();
      await container.read(notificationConsentProvider.future);
      service.pending.single.complete(service.submitted.single);
      await oldFailure;
      await queuedFailure;
      expect(service.pending, hasLength(1));
      expect(
        container.read(notificationConsentProvider).value?.promotionalInApp,
        isFalse,
      );
      expect(
        container.read(notificationConsentProvider).value?.promotionalPush,
        isFalse,
      );
    },
  );

  test('latest failed write restores the confirmed value', () async {
    await container.read(notificationConsentProvider.future);
    final pending = container
        .read(notificationConsentProvider.notifier)
        .setPromotionalPush(true);
    final failed = expectLater(pending, throwsStateError);
    await _tick();
    service.pending.single.completeError(StateError('failed'));
    await failed;
    expect(
      container.read(notificationConsentProvider).value?.promotionalPush,
      isFalse,
    );
  });

  test('disposed controller discards the late save', () async {
    await container.read(notificationConsentProvider.future);
    final pending = container
        .read(notificationConsentProvider.notifier)
        .setPromotionalPush(true);
    final failure = expectLater(pending, throwsA(isA<StaleAccountWork>()));
    await _tick();
    container.dispose();
    service.pending.single.complete(service.submitted.single);
    await failure;
  });
}
