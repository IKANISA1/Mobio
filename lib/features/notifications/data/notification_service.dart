import 'dart:async';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/errors/app_exception.dart' as app;
import 'package:mobi_app/core/errors/app_exception_mapper.dart';
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
  late final StreamSubscription<AuthState> _authSubscription;
  String? _observedUserId;
  String? _observedSessionId;
  int _accountGeneration = 0;
  bool _disposed = false;

  NotificationService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client {
    _observedUserId = _currentUserId;
    _observedSessionId = AccountContext.sessionId(
      _supabase.auth.currentSession,
    );
    _authSubscription = _supabase.auth.onAuthStateChange.listen((state) {
      final userId = state.session?.user.id;
      final sessionId = AccountContext.sessionId(state.session);
      if (_observedUserId != userId || _observedSessionId != sessionId) {
        _observedUserId = userId;
        _observedSessionId = sessionId;
        _accountGeneration++;
      }
    });
  }

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  String _requireUserId() {
    final userId = _currentUserId;
    if (_disposed || userId == null) throw const app.AuthException();
    return userId;
  }

  void _verifyAccount(String userId, int generation) {
    if (_disposed ||
        _currentUserId != userId ||
        AccountContext.sessionId(_supabase.auth.currentSession) !=
            _observedSessionId ||
        _accountGeneration != generation) {
      throw const app.AuthException(
        message: 'Your account changed. Refresh to continue.',
      );
    }
  }

  /// Stream of incoming notifications (realtime).
  Stream<AppNotification> get onNotification => _notificationController.stream;

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Fetches all notifications for the current user, newest first.
  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
    final userId = _currentUserId;
    if (userId == null) return [];
    final generation = _accountGeneration;

    try {
      final rows = await RequestDeadline.read(
        _supabase
            .from('notifications')
            .select()
            .eq('user_id', userId)
            .eq('visible_in_app', true)
            .order('created_at', ascending: false)
            .limit(limit),
      );

      _verifyAccount(userId, generation);
      return rows.map<AppNotification>(AppNotification.fromJson).toList();
    } on Object catch (e, st) {
      throw AppExceptionMapper.mapAndLog(
        e,
        st,
        'NotificationService.getNotifications',
      );
    }
  }

  /// Fetches only unread notifications.
  Future<List<AppNotification>> getUnreadNotifications() async {
    final userId = _currentUserId;
    if (userId == null) return [];
    final generation = _accountGeneration;

    try {
      final rows = await RequestDeadline.read(
        _supabase
            .from('notifications')
            .select()
            .eq('user_id', userId)
            .eq('is_read', false)
            .eq('visible_in_app', true)
            .order('created_at', ascending: false),
      );

      _verifyAccount(userId, generation);
      return rows.map<AppNotification>(AppNotification.fromJson).toList();
    } on Object catch (e, st) {
      throw AppExceptionMapper.mapAndLog(
        e,
        st,
        'NotificationService.getUnreadNotifications',
      );
    }
  }

  /// Returns the count of unread notifications using a server-side count query.
  Future<int> getUnreadCount() async {
    final userId = _currentUserId;
    if (userId == null) return 0;
    final generation = _accountGeneration;

    try {
      final result = await RequestDeadline.read(
        _supabase
            .from('notifications')
            .select('id')
            .eq('user_id', userId)
            .eq('is_read', false)
            .eq('visible_in_app', true)
            .count(CountOption.exact),
      );
      _verifyAccount(userId, generation);
      return result.count;
    } on Object catch (e, st) {
      throw AppExceptionMapper.mapAndLog(
        e,
        st,
        'NotificationService.getUnreadCount',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------------

  /// Marks a single notification as read.
  Future<void> markAsRead(String notificationId) async {
    final userId = _requireUserId();
    final generation = _accountGeneration;
    try {
      final rows = await RequestDeadline.mutation(
        _supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('id', notificationId)
            .eq('user_id', userId)
            .eq('visible_in_app', true)
            .select('id'),
        operation: 'mark_notification_read',
        operationId: notificationId,
      );
      _verifyAccount(userId, generation);
      if (rows.isEmpty) {
        throw const app.NotFoundException(
          message:
              'This notification is no longer available. Refresh to continue.',
        );
      }
    } on Object catch (e, st) {
      throw AppExceptionMapper.mapAndLog(
        e,
        st,
        'NotificationService.markAsRead',
      );
    }
  }

  /// Marks all unread notifications as read for the current user.
  Future<void> markAllAsRead() async {
    final userId = _requireUserId();
    final generation = _accountGeneration;

    try {
      await RequestDeadline.mutation(
        _supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', userId)
            .eq('is_read', false)
            .eq('visible_in_app', true),
        operation: 'mark_all_notifications_read',
        operationId: userId,
      );
      _verifyAccount(userId, generation);
    } on Object catch (e, st) {
      throw AppExceptionMapper.mapAndLog(
        e,
        st,
        'NotificationService.markAllAsRead',
      );
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

    final generation = _accountGeneration;

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
              _verifyAccount(userId, generation);
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
    if (_disposed) return;
    _disposed = true;
    unawaited(_authSubscription.cancel());
    stopListening();
    _notificationController.close();
  }
}
