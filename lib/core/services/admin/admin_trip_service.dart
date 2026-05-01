import 'package:mobi_app/core/services/admin/admin_base_service.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/models/admin/admin_models.dart';

class AdminTripService extends AdminBaseService {
  AdminTripService({super.supabase});

  Future<List<AdminTripListItem>> listTrips({
    String? status,
    String? role,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final rows = await supabaseClient.rpc(
        'rpc_admin_list_trips',
        params: {
          'p_status': status,
          'p_role': role,
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      final list = rows as List<dynamic>? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(AdminTripListItem.fromJson)
          .toList();
    } on Object catch (error) {
      AppLogger.error('Error fetching admin trips: $error');
      rethrow;
    }
  }

  Future<void> cancelTrip({required String tripId, String? reason}) async {
    try {
      await supabaseClient.rpc(
        'rpc_admin_cancel_trip',
        params: {'p_trip_id': tripId, 'p_reason': reason},
      );
    } on Object catch (error) {
      AppLogger.error('Error cancelling admin trip: $error');
      rethrow;
    }
  }
}
