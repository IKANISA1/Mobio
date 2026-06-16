class AdminDashboardStats {
  final int totalUsers;
  final int activeDrivers;
  final int activePassengers;
  final int totalTrips;
  final int activeTrips;
  final int cancelledTrips;

  const AdminDashboardStats({
    required this.totalUsers,
    required this.activeDrivers,
    required this.activePassengers,
    required this.totalTrips,
    required this.activeTrips,
    required this.cancelledTrips,
  });

  factory AdminDashboardStats.fromJson(Map<String, dynamic>? json) {
    return AdminDashboardStats(
      totalUsers: _toInt(json?['total_users']),
      activeDrivers: _toInt(json?['active_drivers']),
      activePassengers: _toInt(json?['active_passengers']),
      totalTrips: _toInt(json?['total_trips']),
      activeTrips: _toInt(json?['active_trips']),
      cancelledTrips: _toInt(json?['cancelled_trips']),
    );
  }
}

class AdminUserListItem {
  final String id;
  final String name;
  final String phone;
  final String role;
  final bool isDriver;
  final String? vehicleType;
  final String? memberId;
  final bool hasFaceId;
  final bool isOnline;
  final String? createdAt;

  const AdminUserListItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.isDriver,
    required this.hasFaceId,
    required this.isOnline,
    this.vehicleType,
    this.memberId,
    this.createdAt,
  });

  factory AdminUserListItem.fromJson(Map<String, dynamic> json) {
    return AdminUserListItem(
      id: json['id'] as String? ?? '',
      name: (json['display_name'] as String?)?.trim().isNotEmpty == true
          ? json['display_name'] as String
          : ((json['name'] as String?)?.trim().isNotEmpty == true
                ? json['name'] as String
                : 'Unnamed member'),
      phone: (json['phone'] as String?)?.trim().isNotEmpty == true
          ? json['phone'] as String
          : 'No phone',
      role: json['role'] as String? ?? 'passenger',
      isDriver: json['is_driver'] as bool? ?? false,
      vehicleType: json['vehicle_type'] as String?,
      memberId: json['member_id'] as String?,
      hasFaceId: json['has_face_id'] as bool? ?? false,
      isOnline: json['is_online'] as bool? ?? false,
      createdAt: json['created_at'] as String?,
    );
  }
}

class AdminTokenAdjustmentReceipt {
  final String ledgerEntryId;
  final String profileId;
  final int amountTokens;
  final String status;

  const AdminTokenAdjustmentReceipt({
    required this.ledgerEntryId,
    required this.profileId,
    required this.amountTokens,
    required this.status,
  });

  factory AdminTokenAdjustmentReceipt.fromJson(Map<String, dynamic> json) {
    return AdminTokenAdjustmentReceipt(
      ledgerEntryId: json['ledger_entry_id'] as String? ?? '',
      profileId: json['profile_id'] as String? ?? '',
      amountTokens: (json['amount_tokens'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'completed',
    );
  }
}

class AdminTripListItem {
  final String id;
  final String authorId;
  final String authorName;
  final String origin;
  final String destination;
  final String? departureDate;
  final String role;
  final String vehicleType;
  final String status;
  final bool isActive;
  final String? createdAt;
  final String? memberId;

  const AdminTripListItem({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.origin,
    required this.destination,
    required this.role,
    required this.vehicleType,
    required this.status,
    required this.isActive,
    this.departureDate,
    this.createdAt,
    this.memberId,
  });

  factory AdminTripListItem.fromJson(Map<String, dynamic> json) {
    return AdminTripListItem(
      id: json['id'] as String? ?? '',
      authorId: json['author_id'] as String? ?? '',
      authorName: json['author_name'] as String? ?? 'Unknown',
      origin: json['origin'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      role: json['role'] as String? ?? 'passenger',
      vehicleType: json['vehicle_type'] as String? ?? 'cab',
      status: json['status'] as String? ?? 'active',
      isActive: json['is_active'] as bool? ?? false,
      departureDate: json['departure_date'] as String?,
      createdAt: json['created_at'] as String?,
      memberId: json['member_id'] as String?,
    );
  }
}

class AdminWhatsappNumberItem {
  final String id;
  final String phoneE164;
  final String countryCode;
  final String? displayName;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  const AdminWhatsappNumberItem({
    required this.id,
    required this.phoneE164,
    required this.countryCode,
    required this.isActive,
    this.displayName,
    this.createdAt,
    this.updatedAt,
  });

  factory AdminWhatsappNumberItem.fromJson(Map<String, dynamic> json) {
    return AdminWhatsappNumberItem(
      id: json['id'] as String? ?? '',
      phoneE164: json['phone_e164'] as String? ?? '',
      countryCode: json['country_code'] as String? ?? '',
      displayName: json['display_name'] as String?,
      isActive: json['is_active'] as bool? ?? false,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

class AdminPlatformSettings {
  final String insuranceAgentWhatsappE164;
  final String tokenRedemptionAdminMemberId;

  const AdminPlatformSettings({
    this.insuranceAgentWhatsappE164 = '+250795588248',
    this.tokenRedemptionAdminMemberId = '',
  });

  factory AdminPlatformSettings.fromJson(Map<String, dynamic>? json) {
    return AdminPlatformSettings(
      insuranceAgentWhatsappE164:
          json?['insurance_agent_whatsapp_e164'] as String? ?? '+250795588248',
      tokenRedemptionAdminMemberId:
          json?['token_redemption_admin_member_id'] as String? ?? '',
    );
  }
}

class AdminTokenRedemptionItem {
  final String id;
  final String requesterProfileId;
  final String? requesterName;
  final String? requesterPhone;
  final String? requesterMemberId;
  final String adminMemberId;
  final String? momoNumber;
  final int amountTokens;
  final int amountRwf;
  final String status;
  final String? adminNote;
  final String? createdAt;

  const AdminTokenRedemptionItem({
    required this.id,
    required this.requesterProfileId,
    required this.adminMemberId,
    required this.amountTokens,
    required this.amountRwf,
    required this.status,
    this.requesterName,
    this.requesterPhone,
    this.requesterMemberId,
    this.momoNumber,
    this.adminNote,
    this.createdAt,
  });

  factory AdminTokenRedemptionItem.fromJson(Map<String, dynamic> json) {
    return AdminTokenRedemptionItem(
      id: json['id'] as String? ?? '',
      requesterProfileId: json['requester_profile_id'] as String? ?? '',
      requesterName: json['requester_name'] as String?,
      requesterPhone: json['requester_phone'] as String?,
      requesterMemberId: json['requester_member_id'] as String?,
      adminMemberId: json['admin_member_id'] as String? ?? '',
      momoNumber: json['momo_number'] as String?,
      amountTokens: (json['amount_tokens'] as num?)?.toInt() ?? 0,
      amountRwf: (json['amount_rwf'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'pending',
      adminNote: json['admin_note'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

class AdminAccessAttemptItem {
  final String id;
  final String phoneE164;
  final String status;
  final String? reason;
  final String sourceApp;
  final Map<String, dynamic> metadata;
  final String? createdAt;

  const AdminAccessAttemptItem({
    required this.id,
    required this.phoneE164,
    required this.status,
    required this.sourceApp,
    this.reason,
    this.metadata = const {},
    this.createdAt,
  });

  factory AdminAccessAttemptItem.fromJson(Map<String, dynamic> json) {
    return AdminAccessAttemptItem(
      id: json['id'] as String? ?? '',
      phoneE164: json['phone_e164'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      reason: json['reason'] as String?,
      sourceApp: json['source_app'] as String? ?? 'unknown',
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
      createdAt: json['created_at'] as String?,
    );
  }
}

class AdminNotificationItem {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String? body;
  final Map<String, dynamic> metadata;
  final bool isRead;
  final String? createdAt;

  const AdminNotificationItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.body,
    this.metadata = const {},
    this.isRead = false,
    this.createdAt,
  });

  factory AdminNotificationItem.fromJson(Map<String, dynamic> json) {
    return AdminNotificationItem(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      type: json['type'] as String? ?? 'general',
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] as String?,
    );
  }
}

class AdminCampaignApprovalItem {
  final String id;
  final String organizationId;
  final String organizationName;
  final String organizationSlug;
  final String campaignType;
  final String title;
  final String? body;
  final Map<String, dynamic> metadata;
  final String status;
  final String requestedBy;
  final String requestedByName;
  final String? approvedBy;
  final String? approvedByName;
  final String? approvalNotes;
  final String? requestedAt;
  final String? approvedAt;
  final String? sentBy;
  final String? sentByName;
  final String? sentAt;
  final int recipientCount;
  final int eligibleRecipientCount;
  final int promotionalConsentCount;
  final int auditEventCount;
  final String? latestAuditAt;
  final int totalCount;
  final String? createdAt;
  final String? updatedAt;

  const AdminCampaignApprovalItem({
    required this.id,
    required this.organizationId,
    required this.organizationName,
    required this.organizationSlug,
    required this.campaignType,
    required this.title,
    required this.status,
    required this.requestedBy,
    required this.requestedByName,
    this.body,
    this.metadata = const {},
    this.approvedBy,
    this.approvedByName,
    this.approvalNotes,
    this.requestedAt,
    this.approvedAt,
    this.sentBy,
    this.sentByName,
    this.sentAt,
    this.recipientCount = 0,
    this.eligibleRecipientCount = 0,
    this.promotionalConsentCount = 0,
    this.auditEventCount = 0,
    this.latestAuditAt,
    this.totalCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status == 'pending_approval';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isSent => status == 'sent';
  bool get isPromo => campaignType == 'promo';
  int get consentCoveragePercent => eligibleRecipientCount <= 0
      ? 0
      : ((promotionalConsentCount / eligibleRecipientCount) * 100).round();

  factory AdminCampaignApprovalItem.fromJson(Map<String, dynamic> json) {
    return AdminCampaignApprovalItem(
      id: json['id'] as String? ?? '',
      organizationId: json['organization_id'] as String? ?? '',
      organizationName: json['organization_name'] as String? ?? 'Organization',
      organizationSlug: json['organization_slug'] as String? ?? '',
      campaignType: json['campaign_type'] as String? ?? 'promo',
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      metadata: _toMap(json['metadata']),
      status: json['status'] as String? ?? 'pending_approval',
      requestedBy: json['requested_by'] as String? ?? '',
      requestedByName:
          (json['requested_by_name'] as String?)?.trim().isNotEmpty == true
          ? json['requested_by_name'] as String
          : 'Platform admin',
      approvedBy: json['approved_by'] as String?,
      approvedByName: json['approved_by_name'] as String?,
      approvalNotes: json['approval_notes'] as String?,
      requestedAt: json['requested_at'] as String?,
      approvedAt: json['approved_at'] as String?,
      sentBy: json['sent_by'] as String?,
      sentByName: json['sent_by_name'] as String?,
      sentAt: json['sent_at'] as String?,
      recipientCount: _toInt(json['recipient_count']),
      eligibleRecipientCount: _toInt(json['eligible_recipient_count']),
      promotionalConsentCount: _toInt(json['promotional_consent_count']),
      auditEventCount: _toInt(json['audit_event_count']),
      latestAuditAt: json['latest_audit_at'] as String?,
      totalCount: _toInt(json['total_count']),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

class AdminNotificationConsentSummary {
  final String organizationId;
  final String organizationName;
  final int eligibleProfileCount;
  final int promotionalInAppCount;
  final int promotionalPushCount;
  final int promotionalAnyCount;
  final int revokedOrDeniedCount;

  const AdminNotificationConsentSummary({
    required this.organizationId,
    required this.organizationName,
    this.eligibleProfileCount = 0,
    this.promotionalInAppCount = 0,
    this.promotionalPushCount = 0,
    this.promotionalAnyCount = 0,
    this.revokedOrDeniedCount = 0,
  });

  int get promotionalCoveragePercent => eligibleProfileCount <= 0
      ? 0
      : ((promotionalAnyCount / eligibleProfileCount) * 100).round();

  factory AdminNotificationConsentSummary.fromJson(Map<String, dynamic> json) {
    return AdminNotificationConsentSummary(
      organizationId: json['organization_id'] as String? ?? '',
      organizationName: json['organization_name'] as String? ?? 'Organization',
      eligibleProfileCount: _toInt(json['eligible_profile_count']),
      promotionalInAppCount: _toInt(json['promotional_in_app_count']),
      promotionalPushCount: _toInt(json['promotional_push_count']),
      promotionalAnyCount: _toInt(json['promotional_any_count']),
      revokedOrDeniedCount: _toInt(json['revoked_or_denied_count']),
    );
  }
}

class AdminCampaignAudiencePreview {
  final String campaignId;
  final String organizationId;
  final int eligibleRecipientCount;
  final int promotionalConsentCount;
  final int promotionalInAppCount;
  final int promotionalPushCount;
  final int revokedOrDeniedCount;
  final int alreadySentCount;

  const AdminCampaignAudiencePreview({
    required this.campaignId,
    required this.organizationId,
    this.eligibleRecipientCount = 0,
    this.promotionalConsentCount = 0,
    this.promotionalInAppCount = 0,
    this.promotionalPushCount = 0,
    this.revokedOrDeniedCount = 0,
    this.alreadySentCount = 0,
  });

  bool get hasPromotionalRecipients => promotionalConsentCount > 0;

  int get promotionalCoveragePercent => eligibleRecipientCount <= 0
      ? 0
      : ((promotionalConsentCount / eligibleRecipientCount) * 100).round();

  factory AdminCampaignAudiencePreview.fromJson(Map<String, dynamic> json) {
    return AdminCampaignAudiencePreview(
      campaignId: json['campaign_id'] as String? ?? '',
      organizationId: json['organization_id'] as String? ?? '',
      eligibleRecipientCount: _toInt(json['eligible_recipient_count']),
      promotionalConsentCount: _toInt(json['promotional_consent_count']),
      promotionalInAppCount: _toInt(json['promotional_in_app_count']),
      promotionalPushCount: _toInt(json['promotional_push_count']),
      revokedOrDeniedCount: _toInt(json['revoked_or_denied_count']),
      alreadySentCount: _toInt(json['already_sent_count']),
    );
  }
}

class AdminNotificationConsentTrendPoint {
  final String bucketDate;
  final int grantedCount;
  final int revokedOrDeniedCount;
  final int inAppGrantedCount;
  final int pushGrantedCount;

  const AdminNotificationConsentTrendPoint({
    required this.bucketDate,
    this.grantedCount = 0,
    this.revokedOrDeniedCount = 0,
    this.inAppGrantedCount = 0,
    this.pushGrantedCount = 0,
  });

  int get netGrantedCount => grantedCount - revokedOrDeniedCount;

  factory AdminNotificationConsentTrendPoint.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminNotificationConsentTrendPoint(
      bucketDate: json['bucket_date'] as String? ?? '',
      grantedCount: _toInt(json['granted_count']),
      revokedOrDeniedCount: _toInt(json['revoked_or_denied_count']),
      inAppGrantedCount: _toInt(json['in_app_granted_count']),
      pushGrantedCount: _toInt(json['push_granted_count']),
    );
  }
}

class AdminAuditLogItem {
  final String id;
  final String? adminId;
  final String adminName;
  final String action;
  final String targetType;
  final String? targetId;
  final Map<String, dynamic> details;
  final String? createdAt;

  const AdminAuditLogItem({
    required this.id,
    required this.adminName,
    required this.action,
    required this.targetType,
    this.adminId,
    this.targetId,
    this.details = const {},
    this.createdAt,
  });

  factory AdminAuditLogItem.fromJson(Map<String, dynamic> json) {
    return AdminAuditLogItem(
      id: json['id'] as String? ?? '',
      adminId: json['admin_id'] as String?,
      adminName: (json['admin_name'] as String?)?.trim().isNotEmpty == true
          ? json['admin_name'] as String
          : 'Platform admin',
      action: json['action'] as String? ?? 'unknown_action',
      targetType: json['target_type'] as String? ?? 'unknown_target',
      targetId: json['target_id'] as String?,
      details: _toMap(json['details']),
      createdAt: json['created_at'] as String?,
    );
  }
}

class AdminOperationalHealthEventItem {
  final String id;
  final String service;
  final String component;
  final String status;
  final String severity;
  final String? issueCode;
  final String message;
  final String? functionName;
  final String? userId;
  final String userName;
  final String? subjectType;
  final String? subjectId;
  final Map<String, dynamic> metadata;
  final String? occurredAt;
  final String ingestOrigin;
  final String? createdAt;

  const AdminOperationalHealthEventItem({
    required this.id,
    required this.service,
    required this.component,
    required this.status,
    required this.severity,
    required this.message,
    required this.userName,
    required this.ingestOrigin,
    this.issueCode,
    this.functionName,
    this.userId,
    this.subjectType,
    this.subjectId,
    this.metadata = const {},
    this.occurredAt,
    this.createdAt,
  });

  bool get isError => status == 'error' || severity == 'critical';
  bool get isWarning => status == 'warn' || severity == 'warning';

  factory AdminOperationalHealthEventItem.fromJson(Map<String, dynamic> json) {
    return AdminOperationalHealthEventItem(
      id: json['id'] as String? ?? '',
      service: json['service'] as String? ?? 'unknown_service',
      component: json['component'] as String? ?? 'general',
      status: json['status'] as String? ?? 'ok',
      severity: json['severity'] as String? ?? 'info',
      issueCode: json['issue_code'] as String?,
      message: json['message'] as String? ?? 'No message',
      functionName: json['function_name'] as String?,
      userId: json['user_id'] as String?,
      userName: (json['user_name'] as String?)?.trim().isNotEmpty == true
          ? json['user_name'] as String
          : 'System',
      subjectType: json['subject_type'] as String?,
      subjectId: json['subject_id'] as String?,
      metadata: _toMap(json['metadata']),
      occurredAt: json['occurred_at'] as String?,
      ingestOrigin: json['ingest_origin'] as String? ?? 'system',
      createdAt: json['created_at'] as String?,
    );
  }
}

class AdminUserReportItem {
  final String id;
  final String reporterId;
  final String reporterName;
  final String? reporterPhone;
  final String reportedId;
  final String reportedName;
  final String? reportedPhone;
  final String? conversationId;
  final String? tripId;
  final String category;
  final String details;
  final String status;
  final String? resolutionNotes;
  final String? reviewedBy;
  final String? reviewedAt;
  final String? createdAt;

  const AdminUserReportItem({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.reportedId,
    required this.reportedName,
    required this.category,
    required this.details,
    required this.status,
    this.reporterPhone,
    this.reportedPhone,
    this.conversationId,
    this.tripId,
    this.resolutionNotes,
    this.reviewedBy,
    this.reviewedAt,
    this.createdAt,
  });

  bool get isOpen => status == 'open' || status == 'reviewing';
  bool get isResolved => status == 'resolved' || status == 'dismissed';

  factory AdminUserReportItem.fromJson(Map<String, dynamic> json) {
    return AdminUserReportItem(
      id: json['id'] as String? ?? '',
      reporterId: json['reporter_id'] as String? ?? '',
      reporterName:
          (json['reporter_name'] as String?)?.trim().isNotEmpty == true
          ? json['reporter_name'] as String
          : 'Unknown reporter',
      reporterPhone: json['reporter_phone'] as String?,
      reportedId: json['reported_id'] as String? ?? '',
      reportedName:
          (json['reported_name'] as String?)?.trim().isNotEmpty == true
          ? json['reported_name'] as String
          : 'Unknown reported user',
      reportedPhone: json['reported_phone'] as String?,
      conversationId: json['conversation_id'] as String?,
      tripId: json['trip_id'] as String?,
      category: json['category'] as String? ?? 'other',
      details: json['details'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      resolutionNotes: json['resolution_notes'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

Map<String, dynamic> _toMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}
