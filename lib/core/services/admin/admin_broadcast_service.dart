import 'package:mobi_app/core/services/admin/admin_base_service.dart';
import 'package:mobi_app/core/utils/app_logger.dart';

class AdminBroadcastService extends AdminBaseService {
  AdminBroadcastService({super.supabase});

  Future<int> sendPromo({
    required String title,
    String? body,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final count = await supabaseClient.rpc(
        'rpc_admin_send_promo',
        params: {
          'p_title': title,
          'p_body': body,
          'p_metadata': metadata ?? const {},
        },
      );
      return count as int? ?? 0;
    } on Object catch (e) {
      AppLogger.error('Error sending promo broadcast: $e');
      rethrow;
    }
  }

  Future<int> sendAnnouncement({
    required String title,
    String? body,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final count = await supabaseClient.rpc(
        'rpc_admin_send_announcement',
        params: {
          'p_title': title,
          'p_body': body,
          'p_metadata': metadata ?? const {},
        },
      );
      return count as int? ?? 0;
    } on Object catch (e) {
      AppLogger.error('Error sending announcement broadcast: $e');
      rethrow;
    }
  }
}
