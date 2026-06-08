import 'package:mobi_app/core/services/admin/admin_base_service.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/models/admin/admin_models.dart';

class AdminComplianceService extends AdminBaseService {
  AdminComplianceService({super.supabase});

  Future<List<AdminAuditLogItem>> listAuditLogs({
    String? action,
    String? targetType,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final rows = await supabaseClient.rpc(
        'rpc_admin_list_audit_logs',
        params: {
          'p_limit': limit,
          'p_offset': offset,
          'p_action': _nullableText(action),
          'p_target_type': _nullableText(targetType),
          'p_search': _nullableText(search),
        },
      );

      final list = rows as List<dynamic>? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(AdminAuditLogItem.fromJson)
          .toList();
    } on Object catch (error) {
      AppLogger.error('Error fetching admin audit logs: $error');
      rethrow;
    }
  }

  Future<List<AdminUserReportItem>> listUserReports({
    String status = 'open',
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final rows = await supabaseClient.rpc(
        'rpc_admin_list_user_reports',
        params: {
          'p_status': status,
          'p_search': _nullableText(search),
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      final list = rows as List<dynamic>? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(AdminUserReportItem.fromJson)
          .toList();
    } on Object catch (error) {
      AppLogger.error('Error fetching user reports: $error');
      rethrow;
    }
  }

  Future<void> reviewUserReport({
    required String reportId,
    required String status,
    String? notes,
  }) async {
    try {
      await supabaseClient.rpc(
        'rpc_admin_review_user_report',
        params: {
          'p_report_id': reportId,
          'p_status': status,
          'p_resolution_notes': _nullableText(notes),
        },
      );
    } on Object catch (error) {
      AppLogger.error('Error reviewing user report: $error');
      rethrow;
    }
  }

  Future<List<AdminOperationalHealthEventItem>> listOperationalHealthEvents({
    String? status,
    String? severity,
    String? service,
    String? search,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final rows = await supabaseClient.rpc(
        'rpc_admin_list_operational_health_events',
        params: {
          'p_status': _nullableText(status),
          'p_severity': _nullableText(severity),
          'p_service': _nullableText(service),
          'p_search': _nullableText(search),
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      final list = rows as List<dynamic>? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(AdminOperationalHealthEventItem.fromJson)
          .toList();
    } on Object catch (error) {
      AppLogger.error('Error fetching operational health events: $error');
      rethrow;
    }
  }

  String? _nullableText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
