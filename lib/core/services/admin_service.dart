import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

class AdminService {
  AdminService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  Future<AdminDashboardStats> getDashboardStats() async {
    try {
      final data = await _supabase.rpc('get_dashboard_stats');
      return AdminDashboardStats.fromJson(data as Map<String, dynamic>?);
    } catch (error) {
      AppLogger.error('Error fetching admin dashboard stats: $error');
      rethrow;
    }
  }

  Future<List<AdminUserListItem>> listUsers({
    String? role,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final rows = await _supabase.rpc(
        'rpc_admin_list_users',
        params: {
          'p_role': role,
          'p_search': search?.trim().isEmpty == true ? null : search?.trim(),
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      final list = rows as List<dynamic>? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(AdminUserListItem.fromJson)
          .toList();
    } catch (error) {
      AppLogger.error('Error fetching admin users: $error');
      rethrow;
    }
  }

  Future<void> updateUserRole({
    required String userId,
    required String role,
  }) async {
    try {
      await _supabase.rpc(
        'rpc_admin_update_user_role',
        params: {'p_user_id': userId, 'p_role': role},
      );
    } catch (error) {
      AppLogger.error('Error updating admin user role: $error');
      rethrow;
    }
  }

  Future<List<AdminWhatsappNumberItem>> listWhatsappAdminNumbers() async {
    try {
      final rows = await _supabase.rpc('rpc_admin_list_whatsapp_numbers');
      final list = rows as List<dynamic>? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(AdminWhatsappNumberItem.fromJson)
          .toList();
    } catch (error) {
      AppLogger.error('Error fetching admin WhatsApp numbers: $error');
      rethrow;
    }
  }

  Future<AdminWhatsappNumberItem> upsertWhatsappAdminNumber({
    required String phoneE164,
    required String countryCode,
    String? displayName,
    bool isActive = true,
  }) async {
    try {
      final rows = await _supabase.rpc(
        'rpc_admin_upsert_whatsapp_number',
        params: {
          'p_phone_e164': phoneE164,
          'p_country_code': countryCode,
          'p_display_name': displayName?.trim().isEmpty == true
              ? null
              : displayName?.trim(),
          'p_is_active': isActive,
        },
      );

      final list = rows as List<dynamic>? ?? const [];
      final typedRows = list.whereType<Map<String, dynamic>>().toList();
      if (typedRows.isEmpty) {
        throw StateError(
          'Admin WhatsApp number was not returned by the server.',
        );
      }

      return AdminWhatsappNumberItem.fromJson(typedRows.first);
    } catch (error) {
      AppLogger.error('Error upserting admin WhatsApp number: $error');
      rethrow;
    }
  }

  Future<AdminWhatsappNumberItem> setWhatsappAdminNumberActive({
    required String id,
    required bool isActive,
  }) async {
    try {
      final rows = await _supabase.rpc(
        'rpc_admin_set_whatsapp_number_active',
        params: {'p_id': id, 'p_is_active': isActive},
      );

      final list = rows as List<dynamic>? ?? const [];
      final typedRows = list.whereType<Map<String, dynamic>>().toList();
      if (typedRows.isEmpty) {
        throw StateError('Admin WhatsApp number update returned no row.');
      }

      return AdminWhatsappNumberItem.fromJson(typedRows.first);
    } catch (error) {
      AppLogger.error('Error updating admin WhatsApp number status: $error');
      rethrow;
    }
  }

  Future<List<AdminAccessAttemptItem>> listAdminAccessAttempts({
    int limit = 20,
  }) async {
    try {
      final rows = await _supabase.rpc(
        'rpc_admin_list_access_attempts',
        params: {'p_limit': limit},
      );

      final list = rows as List<dynamic>? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(AdminAccessAttemptItem.fromJson)
          .toList();
    } catch (error) {
      AppLogger.error('Error fetching admin access attempts: $error');
      rethrow;
    }
  }

  Future<List<AdminNotificationItem>> listAdminNotifications({
    int limit = 12,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      return const [];
    }

    try {
      final rows = await _supabase
          .from('notifications')
          .select(
            'id, user_id, type, title, body, is_read, metadata, created_at',
          )
          .eq('user_id', userId)
          .like('type', 'admin_%')
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AdminNotificationItem.fromJson)
          .toList();
    } catch (error) {
      AppLogger.error('Error fetching admin notifications: $error');
      rethrow;
    }
  }

  Future<void> markAdminNotificationRead(String notificationId) async {
    final userId = currentUserId;
    if (userId == null) {
      return;
    }

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', userId);
    } catch (error) {
      AppLogger.error('Error marking admin notification as read: $error');
      rethrow;
    }
  }

  Future<void> markAllAdminNotificationsRead() async {
    final userId = currentUserId;
    if (userId == null) {
      return;
    }

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false)
          .like('type', 'admin_%');
    } catch (error) {
      AppLogger.error('Error marking all admin notifications as read: $error');
      rethrow;
    }
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
