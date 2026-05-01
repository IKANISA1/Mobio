import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/models/notification_consent_settings.dart';

final notificationConsentProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationConsentController,
      NotificationConsentSettings
    >(NotificationConsentController.new);

class NotificationConsentController
    extends AsyncNotifier<NotificationConsentSettings> {
  @override
  Future<NotificationConsentSettings> build() {
    return ref.read(notificationConsentServiceProvider).getSettings();
  }

  Future<void> setPromotionalInApp(bool value) async {
    final current = state.value ?? const NotificationConsentSettings();
    await _save(current.copyWith(promotionalInApp: value));
  }

  Future<void> setPromotionalPush(bool value) async {
    final current = state.value ?? const NotificationConsentSettings();
    await _save(current.copyWith(promotionalPush: value));
  }

  Future<void> _save(NotificationConsentSettings settings) async {
    final previous = state;
    state = AsyncValue.data(settings);
    try {
      final saved = await ref
          .read(notificationConsentServiceProvider)
          .saveSettings(settings);
      state = AsyncValue.data(saved);
    } on Object catch (error, stackTrace) {
      state = previous;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
