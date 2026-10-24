import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/admin/data/admin_base_service.dart';
import 'package:mobi_app/features/admin/domain/admin_wire_record.dart';
import 'package:mobi_shared_types/models/admin/admin_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

class AdminBroadcastService extends AdminBaseService {
  AdminBroadcastService({super.supabase});

  Future<String> requestCampaignApproval({
    required String campaignType,
    required String title,
    String? body,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final result = await mutate(
        supabaseClient.rpc(
          'rpc_admin_request_campaign_approval',
          params: {
            'p_campaign_type': campaignType,
            'p_title': title,
            'p_body': body,
            'p_metadata': metadata ?? const {},
          },
        ),
        operation: 'request_campaign_approval',
      );
      return _confirmMutation(
        () => _requireUuid(result, 'campaign approval ID'),
        operation: 'request_campaign_approval',
      );
    } on Object catch (e) {
      AppLogger.error('Error requesting campaign approval: $e');
      rethrow;
    }
  }

  Future<String> requestPromoApproval({
    required String title,
    String? body,
    Map<String, dynamic>? metadata,
  }) => requestCampaignApproval(
    campaignType: 'promo',
    title: title,
    body: body,
    metadata: metadata,
  );

  Future<List<AdminCampaignApprovalItem>> listCampaignApprovals({
    String? status,
    String? campaignType,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      return _parseCampaignRows(
        await RequestDeadline.read(
          supabaseClient.rpc(
            'rpc_admin_list_campaign_approvals',
            params: {
              'p_status': _nullableText(status),
              'p_campaign_type': _nullableText(campaignType),
              'p_search': _nullableText(search),
              'p_limit': limit,
              'p_offset': offset,
            },
          ),
        ),
      );
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202') rethrow;
      try {
        return _parseCampaignRows(
          await RequestDeadline.read(
            supabaseClient.rpc(
              'rpc_admin_list_campaign_approvals',
              params: {
                'p_status': _nullableText(status),
                'p_campaign_type': _nullableText(campaignType),
                'p_limit': limit,
                'p_offset': offset,
              },
            ),
          ),
        );
      } on Object {
        AppLogger.error('Error listing campaign approvals: $e');
        rethrow;
      }
    }
  }

  Future<List<AdminNotificationConsentSummary>>
  getNotificationConsentSummary() async {
    try {
      final rows = await RequestDeadline.read(
        supabaseClient.rpc('rpc_admin_get_notification_consent_summary'),
      );
      return _parseRows(rows, AdminWireRecord.consentSummary);
    } on Object catch (e) {
      AppLogger.error('Error loading notification consent summary: $e');
      rethrow;
    }
  }

  Future<AdminCampaignAudiencePreview> getCampaignAudiencePreview({
    required String campaignId,
  }) async {
    try {
      final rows = await RequestDeadline.read(
        supabaseClient.rpc(
          'rpc_admin_get_campaign_audience_preview',
          params: {'p_campaign_id': campaignId},
        ),
      );
      return AdminWireRecord.audiencePreview(
        _firstRow(rows),
        campaignId: campaignId,
      );
    } on Object catch (e) {
      AppLogger.error('Error loading campaign audience preview: $e');
      rethrow;
    }
  }

  Future<List<AdminAuditLogItem>> listCampaignAuditTimeline({
    required String campaignId,
  }) async {
    try {
      final rows = await RequestDeadline.read(
        supabaseClient.rpc(
          'rpc_admin_get_campaign_audit_timeline',
          params: {'p_campaign_id': campaignId},
        ),
      );
      return _parseRows(
        rows,
        (row) => AdminWireRecord.audit(row, expectedCampaignId: campaignId),
      );
    } on Object catch (e) {
      AppLogger.error('Error loading campaign audit timeline: $e');
      rethrow;
    }
  }

  Future<List<AdminNotificationConsentTrendPoint>> getNotificationConsentTrend({
    int days = 30,
  }) async {
    try {
      final rows = await RequestDeadline.read(
        supabaseClient.rpc(
          'rpc_admin_get_notification_consent_trend',
          params: {'p_days': days},
        ),
      );
      return _parseRows(rows, AdminWireRecord.consentTrend);
    } on Object catch (e) {
      AppLogger.error('Error loading notification consent trend: $e');
      rethrow;
    }
  }

  Future<void> approveCampaign({
    required String campaignId,
    required bool approved,
    String? notes,
  }) async {
    try {
      await mutate(
        supabaseClient.rpc(
          'rpc_admin_approve_campaign',
          params: {
            'p_campaign_id': campaignId,
            'p_approved': approved,
            'p_notes': _nullableText(notes),
          },
        ),
        operation: 'approve_campaign',
        operationId: campaignId,
      );
    } on Object catch (e) {
      AppLogger.error('Error approving campaign: $e');
      rethrow;
    }
  }

  Future<int> sendApprovedCampaign({required String campaignId}) async {
    try {
      final count = await mutate(
        supabaseClient.rpc(
          'rpc_admin_send_approved_campaign',
          params: {'p_campaign_id': campaignId},
        ),
        operation: 'send_approved_campaign',
        operationId: campaignId,
      );
      return _confirmMutation(
        () => _requireCount(count),
        operation: 'send_approved_campaign',
        operationId: campaignId,
      );
    } on Object catch (e) {
      AppLogger.error('Error sending approved campaign: $e');
      rethrow;
    }
  }

  Future<int> sendPromo({
    required String title,
    String? body,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final count = await mutate(
        supabaseClient.rpc(
          'rpc_admin_send_promo',
          params: {
            'p_title': title,
            'p_body': body,
            'p_metadata': metadata ?? const {},
          },
        ),
        operation: 'send_promo',
      );
      return _confirmMutation(
        () => _requireCount(count),
        operation: 'send_promo',
      );
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
      final count = await mutate(
        supabaseClient.rpc(
          'rpc_admin_send_announcement',
          params: {
            'p_title': title,
            'p_body': body,
            'p_metadata': metadata ?? const {},
          },
        ),
        operation: 'send_announcement',
      );
      return _confirmMutation(
        () => _requireCount(count),
        operation: 'send_announcement',
      );
    } on Object catch (e) {
      AppLogger.error('Error sending announcement broadcast: $e');
      rethrow;
    }
  }

  String? _nullableText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  List<AdminCampaignApprovalItem> _parseCampaignRows(Object? rows) {
    return _parseRows(rows, AdminWireRecord.campaign);
  }

  Map<String, dynamic> _firstRow(Object? rows) {
    final row = rows is List && rows.length == 1 ? rows.single : rows;
    if (row is! Map) throw const FormatException('Invalid admin RPC row');
    return Map<String, dynamic>.from(row);
  }

  List<T> _parseRows<T>(Object? rows, T Function(Map<String, dynamic>) parse) {
    if (rows is! List) throw const FormatException('Invalid admin RPC rows');
    return rows.map((row) {
      if (row is! Map) throw const FormatException('Invalid admin RPC row');
      return parse(Map<String, dynamic>.from(row));
    }).toList();
  }

  int _requireCount(Object? value) {
    if (value is! int || value < 0) {
      throw const FormatException('Invalid admin RPC count');
    }
    return value;
  }

  String _requireUuid(Object? value, String label) {
    if (value is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
        ).hasMatch(value)) {
      throw FormatException('Invalid $label');
    }
    return value;
  }

  T _confirmMutation<T>(
    T Function() parse, {
    required String operation,
    String? operationId,
  }) {
    try {
      return parse();
    } on FormatException catch (error) {
      throw MutationOutcomeUnknownException(
        operation: operation,
        operationId: operationId,
        originalError: error,
        debugMessage: error.message,
      );
    }
  }
}
