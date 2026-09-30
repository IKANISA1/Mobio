import 'package:mobi_shared_types/models/admin/admin_models.dart';

/// Validates server fields before permissive presentation-model factories run.
/// Preview models can still be constructed without pretending to be RPC rows.
abstract final class AdminWireRecord {
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
  );
  static final _memberId = RegExp(r'^[0-9]{6}$');
  static const _roles = {'passenger', 'driver', 'admin'};
  static const _vehicles = {
    'cab',
    'moto',
    'bus',
    'trike',
    'truck',
    'private',
    'rentals',
  };
  static const _tripStates = {
    'active',
    'cancelled',
    'pending',
    'approved',
    'suspended',
    'blocked',
  };
  static const _redemptionStates = {
    'pending',
    'cash_sent',
    'cancelled',
    'failed',
  };

  static Object? _field(Map<String, dynamic> row, String key) {
    if (!row.containsKey(key)) {
      throw FormatException('Missing admin RPC field: $key');
    }
    return row[key];
  }

  static String _text(
    Map<String, dynamic> row,
    String key, {
    bool allowEmpty = false,
  }) {
    final value = _field(row, key);
    if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
      throw FormatException('Invalid admin RPC field: $key');
    }
    return value;
  }

  static void _optionalText(Map<String, dynamic> row, String key) {
    final value = _field(row, key);
    if (value != null && value is! String) {
      throw FormatException('Invalid admin RPC field: $key');
    }
  }

  static String _id(Map<String, dynamic> row, String key) {
    final value = _text(row, key);
    if (!_uuid.hasMatch(value)) {
      throw FormatException('Invalid admin RPC ID: $key');
    }
    return value;
  }

  static void _member(
    Map<String, dynamic> row,
    String key, {
    bool nullable = false,
    bool allowEmpty = false,
  }) {
    final value = _field(row, key);
    if ((nullable && value == null) || (allowEmpty && value == '')) return;
    if (value is! String || !_memberId.hasMatch(value)) {
      throw FormatException('Invalid admin member ID: $key');
    }
  }

  static void _flag(Map<String, dynamic> row, String key) {
    if (_field(row, key) is! bool) {
      throw FormatException('Invalid admin RPC flag: $key');
    }
  }

  static int _integer(Map<String, dynamic> row, String key, {int minimum = 0}) {
    final value = _field(row, key);
    if (value is! int || value < minimum || value > 9007199254740991) {
      throw FormatException('Invalid admin RPC integer: $key');
    }
    return value;
  }

  static void _state(
    Map<String, dynamic> row,
    String key,
    Set<String> allowed,
  ) {
    if (!allowed.contains(_text(row, key))) {
      throw FormatException('Invalid admin RPC state: $key');
    }
  }

  static void _date(Map<String, dynamic> row, String key) {
    if (DateTime.tryParse(_text(row, key)) == null) {
      throw FormatException('Invalid admin RPC date: $key');
    }
  }

  static void _object(Map<String, dynamic> row, String key) {
    final value = _field(row, key);
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw FormatException('Invalid admin RPC object: $key');
    }
  }

  static AdminUserListItem user(Map<String, dynamic> row) {
    _id(row, 'id');
    _text(row, 'name', allowEmpty: true);
    _optionalText(row, 'display_name');
    _text(row, 'phone', allowEmpty: true);
    _state(row, 'role', _roles);
    _flag(row, 'is_driver');
    _state(row, 'vehicle_type', _vehicles);
    _member(row, 'member_id', nullable: true);
    _flag(row, 'has_face_id');
    _flag(row, 'is_online');
    _date(row, 'created_at');
    return AdminUserListItem.fromJson(row);
  }

  static AdminTripListItem trip(Map<String, dynamic> row) {
    _id(row, 'id');
    _id(row, 'author_id');
    _text(row, 'author_name', allowEmpty: true);
    _text(row, 'origin');
    _text(row, 'destination');
    _text(row, 'departure_date');
    _state(row, 'role', {'passenger', 'driver'});
    _state(row, 'vehicle_type', _vehicles);
    _state(row, 'status', _tripStates);
    _flag(row, 'is_active');
    _date(row, 'created_at');
    _member(row, 'member_id', nullable: true);
    return AdminTripListItem.fromJson(row);
  }

  static AdminDashboardStats dashboard(Map<String, dynamic> row) {
    for (final key in [
      'total_users',
      'active_drivers',
      'active_passengers',
      'total_trips',
      'active_trips',
      'cancelled_trips',
    ]) {
      _integer(row, key);
    }
    return AdminDashboardStats.fromJson(row);
  }

  static AdminTokenAdjustmentReceipt tokenAdjustment(
    Map<String, dynamic> row, {
    required String userId,
    required int amountTokens,
  }) {
    _id(row, 'ledger_entry_id');
    final returnedUser = _id(row, 'profile_id');
    final returnedAmount = _integer(row, 'amount_tokens', minimum: 1);
    _state(row, 'status', {'completed'});
    if (returnedUser != userId || returnedAmount != amountTokens) {
      throw const FormatException('Admin token adjustment receipt mismatch');
    }
    return AdminTokenAdjustmentReceipt.fromJson(row);
  }

  static AdminWhatsappNumberItem whatsapp(
    Map<String, dynamic> row, {
    String? expectedId,
    String? expectedPhone,
    String? expectedCountry,
    bool? expectedActive,
  }) {
    _id(row, 'id');
    final phone = _text(row, 'phone_e164');
    final country = _text(row, 'country_code');
    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone) ||
        !RegExp(r'^\+[1-9][0-9]{0,4}$').hasMatch(country) ||
        !phone.startsWith(country)) {
      throw const FormatException('Invalid admin WhatsApp number');
    }
    _optionalText(row, 'display_name');
    _flag(row, 'is_active');
    _date(row, 'created_at');
    _date(row, 'updated_at');
    if ((expectedId != null && row['id'] != expectedId) ||
        (expectedPhone != null && phone != expectedPhone) ||
        (expectedCountry != null && country != expectedCountry) ||
        (expectedActive != null && row['is_active'] != expectedActive)) {
      throw const FormatException('Admin WhatsApp receipt mismatch');
    }
    return AdminWhatsappNumberItem.fromJson(row);
  }

  static AdminPlatformSettings platformSettings(Map<String, dynamic> row) {
    final phone = _text(row, 'insurance_agent_whatsapp_e164');
    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone)) {
      throw const FormatException('Invalid insurance WhatsApp setting');
    }
    _member(row, 'token_redemption_admin_member_id', allowEmpty: true);
    return AdminPlatformSettings.fromJson(row);
  }

  static AdminTokenRedemptionItem redemption(
    Map<String, dynamic> row, {
    String? expectedRequestId,
    String? expectedStatus,
  }) {
    final id = _id(row, 'id');
    _id(row, 'requester_profile_id');
    _optionalText(row, 'requester_name');
    _optionalText(row, 'requester_phone');
    _member(row, 'requester_member_id', nullable: true);
    _member(row, 'admin_member_id');
    _optionalText(row, 'momo_number');
    _integer(row, 'amount_tokens', minimum: 1);
    _integer(row, 'amount_rwf', minimum: 1);
    _state(row, 'status', _redemptionStates);
    _optionalText(row, 'admin_note');
    _date(row, 'created_at');
    if ((expectedRequestId != null && id != expectedRequestId) ||
        (expectedStatus != null && row['status'] != expectedStatus)) {
      throw const FormatException('Admin redemption receipt mismatch');
    }
    return AdminTokenRedemptionItem.fromJson(row);
  }

  static AdminAccessAttemptItem accessAttempt(Map<String, dynamic> row) {
    _id(row, 'id');
    _text(row, 'phone_e164');
    _text(row, 'status');
    _optionalText(row, 'reason');
    _text(row, 'source_app');
    _object(row, 'metadata');
    _date(row, 'created_at');
    return AdminAccessAttemptItem.fromJson(row);
  }

  static AdminNotificationItem notification(
    Map<String, dynamic> row, {
    required String userId,
  }) {
    _id(row, 'id');
    if (_id(row, 'user_id') != userId) {
      throw const FormatException('Admin notification owner mismatch');
    }
    final type = _text(row, 'type');
    if (!type.startsWith('admin_')) {
      throw const FormatException('Invalid admin notification type');
    }
    _text(row, 'title', allowEmpty: true);
    _optionalText(row, 'body');
    _flag(row, 'is_read');
    _object(row, 'metadata');
    _date(row, 'created_at');
    return AdminNotificationItem.fromJson(row);
  }

  static void _optionalId(Map<String, dynamic> row, String key) {
    if (_field(row, key) != null) _id(row, key);
  }

  static void _optionalDate(Map<String, dynamic> row, String key) {
    if (_field(row, key) != null) _date(row, key);
  }

  static AdminAuditLogItem audit(
    Map<String, dynamic> row, {
    String? expectedCampaignId,
  }) {
    _id(row, 'id');
    _optionalId(row, 'admin_id');
    _text(row, 'admin_name');
    _text(row, 'action');
    _text(row, 'target_type');
    _optionalId(row, 'target_id');
    _object(row, 'details');
    _date(row, 'created_at');
    if (expectedCampaignId != null &&
        (row['target_type'] != 'campaign_approval' ||
            row['target_id'] != expectedCampaignId)) {
      throw const FormatException('Campaign audit target mismatch');
    }
    return AdminAuditLogItem.fromJson(row);
  }

  static AdminUserReportItem report(Map<String, dynamic> row) {
    _id(row, 'id');
    _id(row, 'reporter_id');
    _id(row, 'reported_id');
    for (final key in [
      'reporter_name',
      'reported_name',
      'reporter_phone',
      'reported_phone',
      'resolution_notes',
    ]) {
      _optionalText(row, key);
    }
    for (final key in ['conversation_id', 'trip_id', 'reviewed_by']) {
      _optionalId(row, key);
    }
    _state(row, 'category', {
      'harassment',
      'spam',
      'unsafe_behavior',
      'fraud',
      'other',
    });
    _text(row, 'details', allowEmpty: true);
    _state(row, 'status', {'open', 'reviewing', 'resolved', 'dismissed'});
    _optionalDate(row, 'reviewed_at');
    _date(row, 'created_at');
    return AdminUserReportItem.fromJson(row);
  }

  static AdminOperationalHealthEventItem operationalHealth(
    Map<String, dynamic> row,
  ) {
    _id(row, 'id');
    _text(row, 'service');
    _text(row, 'component');
    _state(row, 'status', {'ok', 'warn', 'error'});
    _state(row, 'severity', {'info', 'warning', 'critical'});
    _text(row, 'message', allowEmpty: true);
    for (final key in [
      'issue_code',
      'function_name',
      'subject_type',
      'subject_id',
    ]) {
      _optionalText(row, key);
    }
    _optionalId(row, 'user_id');
    _text(row, 'user_name', allowEmpty: true);
    _object(row, 'metadata');
    _date(row, 'occurred_at');
    _state(row, 'ingest_origin', {'system', 'mobile_app'});
    _date(row, 'created_at');
    return AdminOperationalHealthEventItem.fromJson(row);
  }

  static AdminCampaignApprovalItem campaign(Map<String, dynamic> row) {
    _id(row, 'id');
    _id(row, 'organization_id');
    _text(row, 'organization_name');
    _text(row, 'organization_slug');
    _state(row, 'campaign_type', {'promo', 'system_announcement'});
    _text(row, 'title');
    _optionalText(row, 'body');
    _object(row, 'metadata');
    _state(row, 'status', {
      'pending_approval',
      'approved',
      'rejected',
      'sent',
      'cancelled',
    });
    _id(row, 'requested_by');
    _text(row, 'requested_by_name');
    for (final key in ['approved_by', 'sent_by']) {
      _optionalId(row, key);
    }
    for (final key in ['approved_by_name', 'sent_by_name', 'approval_notes']) {
      _optionalText(row, key);
    }
    for (final key in ['requested_at', 'created_at', 'updated_at']) {
      _date(row, key);
    }
    for (final key in ['approved_at', 'sent_at', 'latest_audit_at']) {
      _optionalDate(row, key);
    }
    for (final key in [
      'recipient_count',
      'eligible_recipient_count',
      'promotional_consent_count',
      'audit_event_count',
      'total_count',
    ]) {
      _integer(row, key);
    }
    return AdminCampaignApprovalItem.fromJson(row);
  }

  static AdminNotificationConsentSummary consentSummary(
    Map<String, dynamic> row,
  ) {
    _id(row, 'organization_id');
    _text(row, 'organization_name');
    for (final key in [
      'eligible_profile_count',
      'promotional_in_app_count',
      'promotional_push_count',
      'promotional_any_count',
      'revoked_or_denied_count',
    ]) {
      _integer(row, key);
    }
    return AdminNotificationConsentSummary.fromJson(row);
  }

  static AdminCampaignAudiencePreview audiencePreview(
    Map<String, dynamic> row, {
    required String campaignId,
  }) {
    if (_id(row, 'campaign_id') != campaignId) {
      throw const FormatException('Campaign audience target mismatch');
    }
    _id(row, 'organization_id');
    for (final key in [
      'eligible_recipient_count',
      'promotional_consent_count',
      'promotional_in_app_count',
      'promotional_push_count',
      'revoked_or_denied_count',
      'already_sent_count',
    ]) {
      _integer(row, key);
    }
    return AdminCampaignAudiencePreview.fromJson(row);
  }

  static AdminNotificationConsentTrendPoint consentTrend(
    Map<String, dynamic> row,
  ) {
    final day = _text(row, 'bucket_date');
    final parsed = DateTime.tryParse(day);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day) ||
        parsed == null ||
        parsed.toIso8601String().substring(0, 10) != day) {
      throw const FormatException('Invalid consent trend bucket date');
    }
    for (final key in [
      'granted_count',
      'revoked_or_denied_count',
      'in_app_granted_count',
      'push_granted_count',
    ]) {
      _integer(row, key);
    }
    return AdminNotificationConsentTrendPoint.fromJson(row);
  }
}
