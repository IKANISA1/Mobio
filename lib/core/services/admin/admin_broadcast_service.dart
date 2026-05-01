import 'package:mobi_app/core/services/admin/admin_base_service.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/models/admin/admin_models.dart';

class AdminBroadcastService extends AdminBaseService {
  AdminBroadcastService({super.supabase});

  Future<String> requestCampaignApproval({
    required String campaignType,
    required String title,
    String? body,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final result = await supabaseClient.rpc(
        'rpc_admin_request_campaign_approval',
        params: {
          'p_campaign_type': campaignType,
          'p_title': title,
          'p_body': body,
          'p_metadata': metadata ?? const {},
        },
      );
      return result?.toString() ?? '';
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
        await supabaseClient.rpc(
          'rpc_admin_list_campaign_approvals',
          params: {
            'p_status': _nullableText(status),
            'p_campaign_type': _nullableText(campaignType),
            'p_search': _nullableText(search),
            'p_limit': limit,
            'p_offset': offset,
          },
        ),
      );
    } on Object catch (e) {
      try {
        return _parseCampaignRows(
          await supabaseClient.rpc(
            'rpc_admin_list_campaign_approvals',
            params: {
              'p_status': _nullableText(status),
              'p_campaign_type': _nullableText(campaignType),
              'p_limit': limit,
              'p_offset': offset,
            },
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
      final rows = await supabaseClient.rpc(
        'rpc_admin_get_notification_consent_summary',
      );
      final list = rows as List<dynamic>? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(AdminNotificationConsentSummary.fromJson)
          .toList();
    } on Object catch (e) {
      AppLogger.error('Error loading notification consent summary: $e');
      return const [];
    }
  }

  Future<void> approveCampaign({
    required String campaignId,
    required bool approved,
    String? notes,
  }) async {
    try {
      await supabaseClient.rpc(
        'rpc_admin_approve_campaign',
        params: {
          'p_campaign_id': campaignId,
          'p_approved': approved,
          'p_notes': _nullableText(notes),
        },
      );
    } on Object catch (e) {
      AppLogger.error('Error approving campaign: $e');
      rethrow;
    }
  }

  Future<int> sendApprovedCampaign({required String campaignId}) async {
    try {
      final count = await supabaseClient.rpc(
        'rpc_admin_send_approved_campaign',
        params: {'p_campaign_id': campaignId},
      );
      return count as int? ?? 0;
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

  String? _nullableText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  List<AdminCampaignApprovalItem> _parseCampaignRows(Object? rows) {
    final list = rows as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(AdminCampaignApprovalItem.fromJson)
        .toList();
  }
}
