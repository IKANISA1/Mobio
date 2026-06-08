import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/theme/app_theme.dart';
import 'package:mobi_app/features/profile/providers/notification_consent_provider.dart';
import 'package:mobi_app/features/profile/widgets/profile_notification_consent_section.dart';
import 'package:mobi_app/models/notification_consent_settings.dart';

void main() {
  setUp(_FakeNotificationConsentController.reset);

  testWidgets('ProfileNotificationConsentSection toggles promo consent', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationConsentProvider.overrideWith(
            _FakeNotificationConsentController.new,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: ProfileNotificationConsentSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Promotional in-app notifications'), findsOneWidget);
    expect(find.text('Promotional push notifications'), findsOneWidget);

    await tester.tap(find.text('Promotional in-app notifications'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Promotional push notifications'));
    await tester.pumpAndSettle();

    expect(_FakeNotificationConsentController.inAppValues, [false]);
    expect(_FakeNotificationConsentController.pushValues, isEmpty);
    expect(find.text('Notification consent updated.'), findsWidgets);
    expect(find.text('NOTIFICATION ACCESS'), findsOneWidget);
  });
}

class _FakeNotificationConsentController extends NotificationConsentController {
  static var settings = const NotificationConsentSettings(
    promotionalInApp: true,
  );
  static final inAppValues = <bool>[];
  static final pushValues = <bool>[];

  static void reset() {
    settings = const NotificationConsentSettings(promotionalInApp: true);
    inAppValues.clear();
    pushValues.clear();
  }

  @override
  Future<NotificationConsentSettings> build() async => settings;

  @override
  Future<void> setPromotionalInApp(bool value) async {
    inAppValues.add(value);
    settings = settings.copyWith(promotionalInApp: value);
    state = AsyncValue.data(settings);
  }

  @override
  Future<void> setPromotionalPush(bool value) async {
    pushValues.add(value);
    settings = settings.copyWith(promotionalPush: value);
    state = AsyncValue.data(settings);
  }
}
