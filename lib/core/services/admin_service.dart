import 'package:mobi_app/core/services/admin/admin_broadcast_service.dart';
import 'package:mobi_app/core/services/admin/admin_compliance_service.dart';
import 'package:mobi_app/core/services/admin/admin_dashboard_service.dart';
import 'package:mobi_app/core/services/admin/admin_trip_service.dart';
import 'package:mobi_app/core/services/admin/admin_user_service.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/models/admin/admin_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

export 'package:mobi_app/models/admin/admin_models.dart';

class AdminService {
  AdminService({
    SupabaseClient? supabase,
    AdminDashboardService? dashboardService,
    AdminUserService? userService,
    AdminTripService? tripService,
    AdminBroadcastService? broadcastService,
    AdminComplianceService? complianceService,
  }) : _supabase = supabase ?? Supabase.instance.client,
       _dashboardService =
           dashboardService ?? AdminDashboardService(supabase: supabase),
       _userService = userService ?? AdminUserService(supabase: supabase),
       _tripService = tripService ?? AdminTripService(supabase: supabase),
       _broadcastService =
           broadcastService ?? AdminBroadcastService(supabase: supabase),
       _complianceService =
           complianceService ?? AdminComplianceService(supabase: supabase);

  final SupabaseClient _supabase;
  final AdminDashboardService _dashboardService;
  final AdminUserService _userService;
  final AdminTripService _tripService;
  final AdminBroadcastService _broadcastService;
  final AdminComplianceService _complianceService;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  Future<bool> checkAdminAccess(String phoneE164) async {
    try {
      final result = await _supabase.rpc(
        'rpc_check_admin_access',
        params: {'p_phone_e164': phoneE164},
      );
      return result == true;
    } on Object catch (error) {
      AppLogger.error('Error checking admin access: $error');
      return false;
    }
  }

  Future<AdminDashboardStats> getDashboardStats() =>
      _dashboardService.getDashboardStats();

  Future<List<AdminUserListItem>> listUsers({
    String? role,
    String? search,
    int limit = 50,
    int offset = 0,
  }) => _userService.listUsers(
    role: role,
    search: search,
    limit: limit,
    offset: offset,
  );

  Future<List<AdminTripListItem>> listTrips({
    String? status,
    String? role,
    int limit = 50,
    int offset = 0,
  }) => _tripService.listTrips(
    status: status,
    role: role,
    limit: limit,
    offset: offset,
  );

  Future<void> cancelTrip({required String tripId, String? reason}) =>
      _tripService.cancelTrip(tripId: tripId, reason: reason);

  Future<void> updateUserRole({required String userId, required String role}) =>
      _userService.updateUserRole(userId: userId, role: role);

  Future<List<AdminWhatsappNumberItem>> listWhatsappAdminNumbers() =>
      _userService.listWhatsappAdminNumbers();

  Future<AdminWhatsappNumberItem> upsertWhatsappAdminNumber({
    required String phoneE164,
    required String countryCode,
    String? displayName,
    bool isActive = true,
  }) => _userService.upsertWhatsappAdminNumber(
    phoneE164: phoneE164,
    countryCode: countryCode,
    displayName: displayName,
    isActive: isActive,
  );

  Future<AdminWhatsappNumberItem> setWhatsappAdminNumberActive({
    required String id,
    required bool isActive,
  }) => _userService.setWhatsappAdminNumberActive(id: id, isActive: isActive);

  Future<List<AdminAccessAttemptItem>> listAdminAccessAttempts({
    int limit = 20,
  }) => _dashboardService.listAdminAccessAttempts(limit: limit);

  Future<List<AdminNotificationItem>> listAdminNotifications({
    int limit = 12,
  }) => _dashboardService.listAdminNotifications(limit: limit);

  Future<void> markAdminNotificationRead(String notificationId) =>
      _dashboardService.markAdminNotificationRead(notificationId);

  Future<void> markAllAdminNotificationsRead() =>
      _dashboardService.markAllAdminNotificationsRead();

  Future<int> sendPromoNotification({
    required String title,
    String? body,
    Map<String, dynamic>? metadata,
  }) =>
      _broadcastService.sendPromo(title: title, body: body, metadata: metadata);

  Future<String> requestPromoApproval({
    required String title,
    String? body,
    Map<String, dynamic>? metadata,
  }) => _broadcastService.requestPromoApproval(
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
  }) => _broadcastService.listCampaignApprovals(
    status: status,
    campaignType: campaignType,
    search: search,
    limit: limit,
    offset: offset,
  );

  Future<List<AdminNotificationConsentSummary>>
  getNotificationConsentSummary() =>
      _broadcastService.getNotificationConsentSummary();

  Future<void> approveCampaign({
    required String campaignId,
    required bool approved,
    String? notes,
  }) => _broadcastService.approveCampaign(
    campaignId: campaignId,
    approved: approved,
    notes: notes,
  );

  Future<int> sendApprovedCampaign({required String campaignId}) =>
      _broadcastService.sendApprovedCampaign(campaignId: campaignId);

  Future<int> sendSystemAnnouncement({
    required String title,
    String? body,
    Map<String, dynamic>? metadata,
  }) => _broadcastService.sendAnnouncement(
    title: title,
    body: body,
    metadata: metadata,
  );

  Future<int> sendPromo({
    required String title,
    String? body,
    Map<String, dynamic>? metadata,
  }) =>
      _broadcastService.sendPromo(title: title, body: body, metadata: metadata);

  Future<int> sendAnnouncement({
    required String title,
    String? body,
    Map<String, dynamic>? metadata,
  }) => _broadcastService.sendAnnouncement(
    title: title,
    body: body,
    metadata: metadata,
  );

  Future<List<AdminAuditLogItem>> listAuditLogs({
    String? action,
    String? targetType,
    String? search,
    int limit = 50,
    int offset = 0,
  }) => _complianceService.listAuditLogs(
    action: action,
    targetType: targetType,
    search: search,
    limit: limit,
    offset: offset,
  );

  Future<List<AdminRiskFlagItem>> listRiskFlags({
    String status = 'open',
    String? severity,
    String? search,
    int limit = 50,
    int offset = 0,
  }) => _complianceService.listRiskFlags(
    status: status,
    severity: severity,
    search: search,
    limit: limit,
    offset: offset,
  );

  Future<void> reviewRiskFlag({
    required String riskFlagId,
    required String action,
    String? notes,
  }) => _complianceService.reviewRiskFlag(
    riskFlagId: riskFlagId,
    action: action,
    notes: notes,
  );
}
