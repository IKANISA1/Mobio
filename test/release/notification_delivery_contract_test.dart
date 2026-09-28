import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('notification delivery contract', () {
    const migrationPath =
        'supabase/migrations/20260612103000_full_stack_notification_delivery.sql';
    const vaultMigrationPath =
        'supabase/migrations/20260612104500_notification_trigger_vault_secret.sql';

    late final String migration;
    late final String vaultMigration;
    late final String sendPush;
    late final String pushWorker;
    late final String pushProvider;
    late final String pushOutbox;
    late final String pushService;
    late final String notificationService;
    late final String router;
    late final String wrappers;
    late final String inbox;
    late final String home;

    setUpAll(() {
      migration = File(migrationPath).readAsStringSync();
      vaultMigration = File(vaultMigrationPath).readAsStringSync();
      sendPush = File(
        'supabase/functions/send-push/index.ts',
      ).readAsStringSync();
      pushWorker = File('supabase/functions/push-outbox-worker/index.ts').readAsStringSync();
      pushProvider = File('supabase/functions/_shared/push-provider.ts').readAsStringSync();
      pushOutbox = File('supabase/functions/_shared/push-outbox.ts').readAsStringSync();
      pushService = File(
        'lib/features/notifications/data/push_notification_service.dart',
      ).readAsStringSync();
      notificationService = File(
        'lib/features/notifications/data/notification_service.dart',
      ).readAsStringSync();
      router = File('lib/app/router/app_router.dart').readAsStringSync();
      wrappers = File('lib/app/router/screen_wrappers.dart').readAsStringSync();
      inbox = File(
        'lib/features/notifications/presentation/notifications_screen.dart',
      ).readAsStringSync();
      home = File(
        'lib/features/home/presentation/home_screen.dart',
      ).readAsStringSync();
    });

    test('creates the missing push delivery tables and audit trail', () {
      for (final table in const [
        'public.fcm_tokens',
        'public.notification_delivery_attempts',
        'public.notification_type_catalog',
      ]) {
        expect(migration, contains('create table if not exists $table'));
        expect(
          migration,
          contains('alter table $table enable row level security'),
        );
      }

      expect(migration, contains('visible_in_app boolean'));
      expect(migration, contains('idx_notifications_in_app_user_unread'));
      expect(migration, contains('token text not null unique'));
      expect(
        migration,
        contains(
          "status in ('queued', 'sent', 'failed', 'skipped', 'invalid_token')",
        ),
      );
    });

    test(
      'owns the database trigger that fans notification inserts into push',
      () {
        expect(
          migration,
          contains(
            'create or replace function public.fn_send_push_on_notification',
          ),
        );
        expect(migration, contains('trg_send_push_on_notification_insert'));
        expect(migration, contains('/functions/v1/send-push'));
        expect(migration, contains('push_consent_not_granted'));
        expect(migration, contains('no_active_fcm_token'));
        expect(migration, contains('push_channel_not_requested'));
        expect(vaultMigration, contains('vault.decrypted_secrets'));
        expect(vaultMigration, contains('mobio_send_push_service_role_key'));
      },
    );

    test('keeps promotional fanout channel-specific', () {
      expect(migration, contains("consent.channel = 'in_app'"));
      expect(migration, contains("consent.channel = 'push'"));
      expect(migration, contains('visible_in_app'));
      expect(migration, contains("'channels'"));
      expect(
        migration,
        isNot(
          contains(
            "consent.channel in ('in_app', 'push')\n            and consent.status = 'granted'",
          ),
        ),
      );
    });

    test('legacy dispatch is retired and durable worker uses FCM v1', () {
      expect(sendPush, contains('legacy_push_dispatch_retired'));
      expect(sendPush, contains('status:410'));
      expect(pushWorker, contains('handlePushWorker'));
      expect(pushWorker, contains('MOBIO_PUSH_WORKER_SECRET'));
      expect(pushProvider, contains('FIREBASE_SERVICE_ACCOUNT_JSON'));
      expect(pushProvider, contains('FCM_SERVICE_ACCOUNT_JSON'));
      expect(pushProvider, contains('firebase.messaging'));
      expect(pushProvider, contains('messages:send'));
      expect(pushProvider, contains('mobio_default'));
      expect(pushProvider, contains("outcome:'invalid_token'"));
      expect(pushOutbox, contains('invalid_token'));
    });

    test('Flutter handles foreground, background, and killed-state opens', () {
      expect(pushService, contains('FirebaseMessaging.onMessage.listen'));
      expect(
        pushService,
        contains('FirebaseMessaging.onMessageOpenedApp.listen'),
      );
      expect(pushService, contains('getInitialMessage'));
      expect(pushService, contains('_binding!.accepts(envelope)'));
      expect(pushService, contains("'/notifications'"));
      expect(pushService, isNot(contains("path.startsWith('/trip/')")));
    });

    test(
      'in-app notifications have a visible inbox and exclude push-only rows',
      () {
        expect(router, contains("path: '/notifications'"));
        expect(wrappers, contains('NotificationsScreenWrapper'));
        expect(home, contains('onNotifications'));
        expect(inbox, contains('class NotificationsScreen'));
        expect(inbox, contains('markAllAsRead'));
        expect(notificationService, contains(".eq('visible_in_app', true)"));
        expect(notificationService, contains('visibleInApp'));
        expect(notificationService, contains('_activeNotificationRoute'));
        expect(notificationService, contains('_isActiveNotificationPath'));
        expect(notificationService, contains("'public_transport_booking'"));
        expect(notificationService, contains("=> '/bookings'"));
        expect(notificationService, contains("'chat_message'"));
        expect(notificationService, contains("=> '/chat'"));
        expect(notificationService, isNot(contains('return value;')));
      },
    );
  });
}
