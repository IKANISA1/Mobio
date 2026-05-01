import 'package:mobi_app/core/services/admin/admin_base_service.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/models/admin/admin_models.dart';

class AdminDashboardService extends AdminBaseService {
  AdminDashboardService({super.supabase});

  Future<AdminDashboardStats> getDashboardStats() async {
    try {
      final data = await supabaseClient.rpc('get_dashboard_stats');
      return AdminDashboardStats.fromJson(data as Map<String, dynamic>?);
    } on Object catch (error) {
      AppLogger.error('Error fetching admin dashboard stats: $error');
      rethrow;
    }
  }

  Future<List<AdminAccessAttemptItem>> listAdminAccessAttempts({
    int limit = 20,
  }) async {
    try {
      final rows = await supabaseClient.rpc(
        'rpc_admin_list_access_attempts',
        params: {'p_limit': limit},
      );

      final list = rows as List<dynamic>? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(AdminAccessAttemptItem.fromJson)
          .toList();
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
      final rows = await supabaseClient
          .from('notifications')
          .select(
            'id, user_id, type, title, body, is_read, metadata, created_at',
          )
          .eq('user_id', userId)
          .like('type', 'admin_%')
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AdminNotificationItem.fromJson)
          .toList();
    } on Object catch (error) {
      AppLogger.error('Error fetching admin notifications: $error');
      rethrow;
    }
  }

  Future<void> markAdminNotificationRead(String notificationId) async {
    final userId = currentUserId;
    if (userId == null) {
      return;
    }

    try {
      await supabaseClient
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', userId);
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
      await supabaseClient
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false)
          .like('type', 'admin_%');
    } on Object catch (error) {
      AppLogger.error('Error marking all admin notifications as read: $error');
      rethrow;
    }
  }
}
