class AdminDashboardStats {
  final int totalUsers;
  final int activeDrivers;
  final int activePassengers;
  final int totalTrips;
  final int activeTrips;
  final int cancelledTrips;
  final int completedTrips;

  const AdminDashboardStats({
    required this.totalUsers,
    required this.activeDrivers,
    required this.activePassengers,
    required this.totalTrips,
    required this.activeTrips,
    required this.cancelledTrips,
    required this.completedTrips,
  });

  factory AdminDashboardStats.fromJson(Map<String, dynamic>? json) {
    return AdminDashboardStats(
      totalUsers: _toInt(json?['total_users']),
      activeDrivers: _toInt(json?['active_drivers']),
      activePassengers: _toInt(json?['active_passengers']),
      totalTrips: _toInt(json?['total_trips']),
      activeTrips: _toInt(json?['active_trips']),
      cancelledTrips: _toInt(json?['cancelled_trips']),
      completedTrips: _toInt(json?['completed_trips']),
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

class AdminRiskFlagItem {
  final String id;
  final String profileId;
  final String profileName;
  final String? profilePhone;
  final String? transactionId;
  final String? intentId;
  final String flagType;
  final String severity;
  final String? description;
  final bool resolved;
  final String? resolvedBy;
  final String? resolvedByName;
  final String? resolvedAt;
  final String? createdAt;
  final double? amount;
  final String? currency;
  final String? paymentMethod;
  final String? intentStatus;
  final String? transactionRef;
  final String? transactionNetwork;
  final double? transactionAmount;
  final String? transactionCurrency;
  final String? transactionTimestamp;

  const AdminRiskFlagItem({
    required this.id,
    required this.profileId,
    required this.profileName,
    required this.flagType,
    required this.severity,
    required this.resolved,
    this.profilePhone,
    this.transactionId,
    this.intentId,
    this.description,
    this.resolvedBy,
    this.resolvedByName,
    this.resolvedAt,
    this.createdAt,
    this.amount,
    this.currency,
    this.paymentMethod,
    this.intentStatus,
    this.transactionRef,
    this.transactionNetwork,
    this.transactionAmount,
    this.transactionCurrency,
    this.transactionTimestamp,
  });

  bool get isOpen => !resolved;

  factory AdminRiskFlagItem.fromJson(Map<String, dynamic> json) {
    return AdminRiskFlagItem(
      id: json['id'] as String? ?? '',
      profileId: json['profile_id'] as String? ?? '',
      profileName: (json['profile_name'] as String?)?.trim().isNotEmpty == true
          ? json['profile_name'] as String
          : 'Unknown member',
      profilePhone: json['profile_phone'] as String?,
      transactionId: json['transaction_id'] as String?,
      intentId: json['intent_id'] as String?,
      flagType: json['flag_type'] as String? ?? 'manual_flag',
      severity: json['severity'] as String? ?? 'low',
      description: json['description'] as String?,
      resolved: json['resolved'] as bool? ?? false,
      resolvedBy: json['resolved_by'] as String?,
      resolvedByName: json['resolved_by_name'] as String?,
      resolvedAt: json['resolved_at'] as String?,
      createdAt: json['created_at'] as String?,
      amount: _toDouble(json['amount']),
      currency: json['currency'] as String?,
      paymentMethod: json['payment_method'] as String?,
      intentStatus: json['intent_status'] as String?,
      transactionRef: json['transaction_ref'] as String?,
      transactionNetwork: json['transaction_network'] as String?,
      transactionAmount: _toDouble(json['transaction_amount']),
      transactionCurrency: json['transaction_currency'] as String?,
      transactionTimestamp: json['transaction_timestamp'] as String?,
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

Map<String, dynamic> _toMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}
