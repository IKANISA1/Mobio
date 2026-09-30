import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/admin/data/admin_base_service.dart';
import 'package:mobi_app/features/admin/domain/admin_wire_record.dart';
import 'package:mobi_shared_types/models/admin/admin_models.dart';

class AdminTripService extends AdminBaseService {
  AdminTripService({super.supabase});

  Future<List<AdminTripListItem>> listTrips({
    String? status,
    String? role,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final rows = await read(
        supabaseClient.rpc(
          'rpc_admin_list_trips',
          params: {
            'p_status': status,
            'p_role': role,
            'p_search': search?.trim().isEmpty == true ? null : search?.trim(),
            'p_limit': limit,
            'p_offset': offset,
          },
        ),
      );

      return requireRows(
        rows,
        'rpc_admin_list_trips',
      ).map(AdminWireRecord.trip).toList();
    } on Object catch (error) {
      AppLogger.error('Error fetching admin trips: $error');
      rethrow;
    }
  }

  Future<void> cancelTrip({required String tripId, String? reason}) async {
    try {
      await mutate(
        supabaseClient.rpc(
          'rpc_admin_cancel_trip',
          params: {'p_trip_id': tripId, 'p_reason': reason},
        ),
        operation: 'rpc_admin_cancel_trip',
        operationId: tripId,
      );
    } on Object catch (error) {
      AppLogger.error('Error cancelling admin trip: $error');
      rethrow;
    }
  }
}
