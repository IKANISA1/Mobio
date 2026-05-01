import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/models/notification_consent_settings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationConsentService {
  NotificationConsentService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Future<NotificationConsentSettings> getSettings() async {
    final userId = _currentUserId;
    if (userId == null) return const NotificationConsentSettings();

    try {
      final rows = await _supabase
          .from('notification_consents')
          .select('consent_type, channel, status')
          .eq('profile_id', userId)
          .eq('consent_type', 'promotional')
          .inFilter('channel', const ['in_app', 'push']);

      return NotificationConsentSettings.fromRows(rows);
    } on Object catch (e) {
      AppLogger.error('Error loading notification consent settings: $e');
      rethrow;
    }
  }

  Future<NotificationConsentSettings> saveSettings(
    NotificationConsentSettings settings,
  ) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception(
        'User must be authenticated to update notification consent.',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final rows = [
      _rowFor(
        profileId: userId,
        channel: 'in_app',
        granted: settings.promotionalInApp,
        updatedAt: now,
      ),
      _rowFor(
        profileId: userId,
        channel: 'push',
        granted: settings.promotionalPush,
        updatedAt: now,
      ),
    ];

    try {
      await _supabase
          .from('notification_consents')
          .upsert(rows, onConflict: 'profile_id,consent_type,channel');
      return settings;
    } on Object catch (e) {
      AppLogger.error('Error saving notification consent settings: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _rowFor({
    required String profileId,
    required String channel,
    required bool granted,
    required String updatedAt,
  }) {
    return {
      'profile_id': profileId,
      'consent_type': 'promotional',
      'channel': channel,
      'status': granted ? 'granted' : 'revoked',
      'source': 'app_profile_settings',
      'metadata': {
        'updated_from': 'profile_notification_settings',
        'updated_at': updatedAt,
      },
    };
  }
}
