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

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
