import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/notifications/application/notification_services.dart';
import 'package:mobi_app/features/notifications/data/notification_consent_service.dart';
import 'package:mobi_app/features/notifications/data/push_notification_service.dart';
import 'package:mobi_app/features/profile/application/notification_consent_provider.dart';
import 'package:mobi_app/features/profile/presentation/widgets/profile_notification_consent_section.dart';
import 'package:mobi_design_system/theme/app_theme.dart';
import 'package:mobi_shared_types/models/notification_consent_settings.dart';

class _Consent extends Fake implements NotificationConsentService {
  int saves = 0;
  @override
  Future<NotificationConsentSettings> getSettings() async =>
      const NotificationConsentSettings();
  @override
  Future<NotificationConsentSettings> saveSettings(
    NotificationConsentSettings settings,
  ) async {
    saves++;
    return settings;
  }
}

class _Push extends Fake implements PushNotificationService {
  _Push(this.stage);
  final String stage;
  final permission = Completer<bool>();
  final registration = Completer<void>();
  int requests = 0, registrations = 0;
  @override
  Future<bool> hasPermission() async =>
      stage == 'check' ? permission.future : stage != 'request';
  @override
  Future<bool> requestPermission() {
    requests++;
    return permission.future;
  }

  @override
  Future<void> registerToken() {
    registrations++;
    return registration.future;
  }
}

void main() {
  for (final stage in ['check', 'request', 'register']) {
    testWidgets('session replacement during push $stage cannot save consent', (
      tester,
    ) async {
      var generation = 0;
      AccountSnapshot capture() =>
          AccountSnapshot('user', 'session', generation);
      bool current(AccountSnapshot account) => account.generation == generation;
      final consent = _Consent();
      final push = _Push(stage);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationConsentProvider.overrideWith(
              () => NotificationConsentController.test(
                captureAccount: capture,
                isCurrent: current,
              ),
            ),
            notificationConsentServiceProvider.overrideWithValue(consent),
            pushNotificationServiceProvider.overrideWithValue(push),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: ProfileNotificationConsentSection.test(
                captureAccount: capture,
                isCurrent: current,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Promotional push notifications'));
      await tester.pumpAndSettle();
      if (stage == 'request') {
        await tester.tap(find.text('ENABLE NOTIFICATIONS'));
        await tester.pumpAndSettle();
        expect(push.requests, 1);
      }
      if (stage == 'register') expect(push.registrations, 1);
      generation++;
      AccountContext.changes.value++;
      if (stage == 'register') {
        push.registration.complete();
      } else {
        push.permission.complete(true);
      }
      await tester.pumpAndSettle();
      expect(consent.saves, 0);
      expect(push.registrations, stage == 'register' ? 1 : 0);
      expect(push.requests, stage == 'request' ? 1 : 0);
      expect(find.text('Notification consent updated.'), findsNothing);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile).last).value,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
