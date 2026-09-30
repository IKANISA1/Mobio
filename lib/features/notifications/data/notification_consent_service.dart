import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_shared_types/models/notification_consent_settings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationConsentService {
  NotificationConsentService({
    SupabaseClient? supabase,
    AccountSnapshot Function()? captureAccount,
    void Function(AccountSnapshot)? requireCurrent,
  }) : _supabase = supabase ?? Supabase.instance.client,
       _captureOverride = captureAccount,
       _requireOverride = requireCurrent;

  final SupabaseClient _supabase;
  final AccountSnapshot Function()? _captureOverride;
  final void Function(AccountSnapshot)? _requireOverride;

  AccountSnapshot _captureAccount() {
    final account = _captureOverride?.call() ?? AccountContext.capture();
    _requireCurrent(account);
    return account;
  }

  void _requireCurrent(AccountSnapshot account) {
    if (_currentUserId != account.userId) throw const StaleAccountWork();
    (_requireOverride ?? AccountContext.requireCurrent)(account);
  }

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Future<NotificationConsentSettings> getSettings() async {
    final account = _captureAccount();
    final userId = account.userId;

    try {
      final rows = await RequestDeadline.read(
        _supabase
            .from('notification_consents')
            .select('consent_type, channel, status')
            .eq('profile_id', userId)
            .eq('consent_type', 'promotional')
            .inFilter('channel', const ['in_app', 'push']),
      );

      _requireCurrent(account);
      return NotificationConsentSettings.fromRows(rows);
    } on Object catch (e) {
      AppLogger.error('Error loading notification consent settings: $e');
      rethrow;
    }
  }

  Future<NotificationConsentSettings> saveSettings(
    NotificationConsentSettings settings,
  ) async {
    final account = _captureAccount();
    final userId = account.userId;

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
      await RequestDeadline.mutation(
        _supabase
            .from('notification_consents')
            .upsert(rows, onConflict: 'profile_id,consent_type,channel'),
        operation: 'save_notification_consent',
        operationId: userId,
      );
      _requireCurrent(account);
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
