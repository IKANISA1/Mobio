import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_shared_types/models/notification_consent_settings.dart';

void main() {
  group('NotificationConsentSettings', () {
    test('parses granted promotional channels from database rows', () {
      final settings = NotificationConsentSettings.fromRows(const [
        {
          'consent_type': 'promotional',
          'channel': 'in_app',
          'status': 'granted',
        },
        {'consent_type': 'promotional', 'channel': 'push', 'status': 'revoked'},
      ]);

      expect(settings.promotionalInApp, isTrue);
      expect(settings.promotionalPush, isFalse);
      expect(settings.hasAnyPromotionalConsent, isTrue);
    });

    test('ignores non-promotional consent rows', () {
      final settings = NotificationConsentSettings.fromRows(const [
        {'consent_type': 'operational', 'channel': 'push', 'status': 'granted'},
      ]);

      expect(settings.promotionalInApp, isFalse);
      expect(settings.promotionalPush, isFalse);
    });
  });
}
