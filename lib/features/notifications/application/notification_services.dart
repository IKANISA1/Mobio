import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/backend/supabase_provider.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/features/notifications/data/notification_consent_service.dart';
import 'package:mobi_app/features/notifications/data/notification_service.dart';
import 'package:mobi_app/features/notifications/data/push_notification_service.dart';

final notificationServiceProvider = Provider((ref) {
  final service = NotificationService(
    supabase: ref.read(supabaseClientProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final notificationUiPreviewProvider = Provider(
  (ref) => SupabaseConfig.isLocalUiPreview,
);

final notificationConsentServiceProvider = Provider(
  (ref) =>
      NotificationConsentService(supabase: ref.read(supabaseClientProvider)),
);

final pushNotificationServiceProvider = Provider(
  (ref) => PushNotificationService.instance,
);
