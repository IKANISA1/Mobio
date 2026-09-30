import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/admin/data/admin_base_service.dart';
import 'package:mobi_shared_types/models/admin/admin_models.dart';

class AdminDashboardService extends AdminBaseService {
  AdminDashboardService({super.supabase});

  Future<AdminDashboardStats> getDashboardStats() async {
    try {
      final data = await read(supabaseClient.rpc('get_dashboard_stats'));
      return AdminDashboardStats.fromJson(
        requireRow(data, 'get_dashboard_stats'),
      );
    } on Object catch (error) {
      AppLogger.error('Error fetching admin dashboard stats: $error');
      rethrow;
    }
  }

  Future<List<AdminAccessAttemptItem>> listAdminAccessAttempts({
    int limit = 20,
  }) async {
    try {
      final rows = await read(
        supabaseClient.rpc(
          'rpc_admin_list_access_attempts',
          params: {'p_limit': limit},
        ),
      );

      return requireRows(
        rows,
        'rpc_admin_list_access_attempts',
      ).map(AdminAccessAttemptItem.fromJson).toList();
    } on Object catch (error) {
      AppLogger.error('Error fetching admin access attempts: $error');
      rethrow;
    }
  }

  Future<List<AdminNotificationItem>> listAdminNotifications({
    int limit = 12,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      return const [];
    }

    try {
      final rows = await read(
        supabaseClient
            .from('notifications')
            .select(
              'id, user_id, type, title, body, is_read, metadata, created_at',
            )
            .eq('user_id', userId)
            .like('type', 'admin_%')
            .order('created_at', ascending: false)
            .limit(limit),
      );

      return requireRows(
        rows,
        'admin_notifications',
      ).map(AdminNotificationItem.fromJson).toList();
    } on Object catch (error) {
      AppLogger.error('Error fetching admin notifications: $error');
      rethrow;
    }
  }

  Future<AdminPlatformSettings> getPlatformSettings() async {
    try {
      final data = await read(
        supabaseClient.rpc('rpc_admin_get_platform_settings'),
      );
      return AdminPlatformSettings.fromJson(
        requireRow(data, 'rpc_admin_get_platform_settings'),
      );
    } on Object catch (error) {
      AppLogger.error('Error fetching platform settings: $error');
      rethrow;
    }
  }

  Future<AdminPlatformSettings> updatePlatformSetting({
    required String key,
    required String value,
  }) async {
    try {
      final data = await mutate(
        supabaseClient.rpc(
          'rpc_admin_upsert_platform_setting',
          params: {'p_key': key, 'p_value': value},
        ),
        operation: 'rpc_admin_upsert_platform_setting',
        operationId: key,
      );
      return AdminPlatformSettings.fromJson(
        requireRow(data, 'rpc_admin_upsert_platform_setting'),
      );
    } on Object catch (error) {
      AppLogger.error('Error updating platform setting: $error');
      rethrow;
    }
  }

  Future<List<AdminTokenRedemptionItem>> listTokenRedemptions({
    String status = 'pending',
    int limit = 8,
  }) async {
    try {
      final rows = await read(
        supabaseClient.rpc(
          'rpc_admin_list_token_redemption_requests',
          params: {'p_status': status, 'p_limit': limit},
        ),
      );

      return requireRows(
        rows,
        'rpc_admin_list_token_redemption_requests',
      ).map(AdminTokenRedemptionItem.fromJson).toList();
    } on Object catch (error) {
      AppLogger.error('Error fetching token redemptions: $error');
      rethrow;
    }
  }

  Future<AdminTokenRedemptionItem> updateTokenRedemptionStatus({
    required String requestId,
    required String status,
    String? adminNote,
  }) async {
    try {
      final data = await mutate(
        supabaseClient.rpc(
          'rpc_admin_update_token_redemption_status',
          params: {
            'p_request_id': requestId,
            'p_status': status,
            'p_admin_note': adminNote,
          },
        ),
        operation: 'rpc_admin_update_token_redemption_status',
        operationId: requestId,
      );
      return AdminTokenRedemptionItem.fromJson(
        requireRow(data, 'rpc_admin_update_token_redemption_status'),
      );
    } on Object catch (error) {
      AppLogger.error('Error updating token redemption: $error');
      rethrow;
    }
  }

  Future<void> markAdminNotificationRead(String notificationId) async {
    final userId = currentUserId;
    if (userId == null) {
      return;
    }

    try {
      await mutate(
        supabaseClient
            .from('notifications')
            .update({'is_read': true})
            .eq('id', notificationId)
            .eq('user_id', userId),
        operation: 'mark_admin_notification_read',
        operationId: notificationId,
      );
    } on Object catch (error) {
      AppLogger.error('Error marking admin notification as read: $error');
      rethrow;
    }
  }

  Future<void> markAllAdminNotificationsRead() async {
    final userId = currentUserId;
    if (userId == null) {
      return;
    }

    try {
      await mutate(
        supabaseClient
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', userId)
            .eq('is_read', false)
            .like('type', 'admin_%'),
        operation: 'mark_all_admin_notifications_read',
        operationId: userId,
      );
    } on Object catch (error) {
      AppLogger.error('Error marking all admin notifications as read: $error');
      rethrow;
    }
  }
}
