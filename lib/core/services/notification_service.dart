import 'dart:async';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Data class representing an in-app notification.
class AppNotification {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String? body;
  final Map<String, dynamic> metadata;
  final bool isRead;
  final bool visibleInApp;
  final String createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.body,
    this.metadata = const {},
    this.isRead = false,
    this.visibleInApp = true,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String? ?? 'general',
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      isRead: json['is_read'] as bool? ?? false,
      visibleInApp: json['visible_in_app'] as bool? ?? true,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  String get route {
    return _activeNotificationRoute(metadata['route'], type);
  }
}

String _activeNotificationRoute(Object? raw, String type) {
  final parsed = raw is String ? Uri.tryParse(raw.trim()) : null;
  if (parsed != null &&
      !parsed.hasScheme &&
      !parsed.hasAuthority &&
      parsed.path.startsWith('/') &&
      !parsed.path.startsWith('//') &&
      _isActiveNotificationPath(parsed.path)) {
    return parsed.toString();
  }

  return switch (type) {
    'chat_message' || 'chat_reply' => '/chat',
    'public_transport_booking' ||
    'public_transport_schedule_change' => '/bookings',
    'trip_update' || 'trip_message' => '/bookings',
    'wallet_credit' || 'wallet_debit' || 'referral_reward' => '/wallet',
    'driver_plus' || 'driver_subscription' => '/mobio-plus',
    'biopay' || 'biopay_request' || 'biopay_confirmation' => '/biopay',
    _ => '/notifications',
  };
}

bool _isActiveNotificationPath(String path) {
  const exactActivePaths = {
    '/',
    '/bookings',
    '/chat',
    '/nearby',
    '/notifications',
    '/profile',
    '/profile/setup',
    '/schedule',
    '/wallet',
    '/mobio-plus',
    '/biopay',
    '/biopay/qr',
    '/biopay/scan',
    '/biopay/face-scan',
    '/biopay/enroll',
    '/biopay/nfc',
    '/biopay/nfc/write-card',
  };

  return exactActivePaths.contains(path) ||
      path.startsWith('/trip/') && path.length > '/trip/'.length;
}

/// Service for in-app notifications via Supabase.
///
/// Handles:
/// - Fetching unread/all notifications
/// - Marking notifications as read
/// - Realtime subscription for live updates
class NotificationService {
  final SupabaseClient _supabase;
  RealtimeChannel? _channel;
  String? _listeningUserId;
  final _notificationController = StreamController<AppNotification>.broadcast();

  NotificationService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Stream of incoming notifications (realtime).
  Stream<AppNotification> get onNotification => _notificationController.stream;

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Fetches all notifications for the current user, newest first.
  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final rows = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('visible_in_app', true)
          .order('created_at', ascending: false)
          .limit(limit);

      return rows.map<AppNotification>(AppNotification.fromJson).toList();
    } on Object catch (e) {
      AppLogger.error('Error fetching notifications: $e');
      return [];
    }
  }

  /// Fetches only unread notifications.
  Future<List<AppNotification>> getUnreadNotifications() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final rows = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false)
          .eq('visible_in_app', true)
          .order('created_at', ascending: false);

      return rows.map<AppNotification>(AppNotification.fromJson).toList();
    } on Object catch (e) {
      AppLogger.error('Error fetching unread notifications: $e');
      return [];
    }
  }

  /// Returns the count of unread notifications using a server-side count query.
  Future<int> getUnreadCount() async {
    final userId = _currentUserId;
    if (userId == null) return 0;

    try {
      final result = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false)
          .eq('visible_in_app', true)
          .count(CountOption.exact);
      return result.count;
    } on Object catch (e) {
      AppLogger.error('Error fetching unread count: $e');
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------------

  /// Marks a single notification as read.
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } on Object catch (e) {
      AppLogger.error('Error marking notification as read: $e');
    }
  }

  /// Marks all unread notifications as read for the current user.
  Future<void> markAllAsRead() async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false)
          .eq('visible_in_app', true);
    } on Object catch (e) {
      AppLogger.error('Error marking all notifications as read: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Realtime
  // ---------------------------------------------------------------------------

  /// Starts listening for new notifications in realtime.
  /// Call [stopListening] when done.
  void startListening() {
    final userId = _currentUserId;
    if (userId == null) {
      stopListening();
      return;
    }

    if (_channel != null && _listeningUserId == userId) {
      return;
    }

    stopListening();

    _channel = _supabase
        .channel('notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            try {
              final notification = AppNotification.fromJson(payload.newRecord);
              if (!notification.visibleInApp) {
                return;
              }
              _notificationController.add(notification);
            } on Object catch (e) {
              AppLogger.error('Error parsing realtime notification: $e');
            }
          },
        )
        .subscribe();
    _listeningUserId = userId;
  }

  /// Stops the realtime subscription.
  void stopListening() {
    _channel?.unsubscribe();
    _channel = null;
    _listeningUserId = null;
  }

  /// Disposes of resources.
  void dispose() {
    stopListening();
    _notificationController.close();
  }
}
