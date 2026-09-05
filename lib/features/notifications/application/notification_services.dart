import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/backend/supabase_provider.dart';
import 'package:mobi_app/features/notifications/data/notification_consent_service.dart';
import 'package:mobi_app/features/notifications/data/notification_service.dart';
import 'package:mobi_app/features/notifications/data/push_notification_service.dart';

final notificationServiceProvider = Provider(
  (ref) => NotificationService(supabase: ref.read(supabaseClientProvider)),
);

final notificationConsentServiceProvider = Provider(
  (ref) =>
      NotificationConsentService(supabase: ref.read(supabaseClientProvider)),
);

final pushNotificationServiceProvider = Provider(
  (ref) => PushNotificationService.instance,
);
