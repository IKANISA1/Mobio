import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/platform/platform_io.dart';
import 'package:mobi_app/core/services/firebase_bootstrap_service.dart';
import 'package:mobi_app/core/services/firebase_remote_config_service.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Top-level handler for background/killed-state messages.
///
/// This MUST be a top-level function — not a method or closure —
/// because it runs in an isolate separate from the main app.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FirebaseBootstrapService.instance.ensureBackgroundInitialized();

  if (kDebugMode) {
    debugPrint('[push] Background message: ${message.messageId}');
  }
}

/// Full push notification service for Mobio.
///
/// Handles:
/// - FCM token registration + refresh
/// - Foreground notification display via local notifications
/// - Background/killed-state message handling
/// - Permission request (Android 13+)
/// - Token storage in Supabase `fcm_tokens` table
class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  final _localNotifications = FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<String>? _tokenRefreshSub;

  bool _initialized = false;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  bool get _isSupportedPlatform => Platform.isAndroid || Platform.isIOS;

  /// The default Android notification channel.
  static const _androidChannel = AndroidNotificationChannel(
    'mobio_default',
    'Mobio Notifications',
    description: 'Messages, scheduled trip posts, and account alerts',
    importance: Importance.high,
    showBadge: true,
  );

  /// Initialize the push notification system.
  ///
  /// Call once after Firebase.initializeApp() in main().
  Future<void> initialize() async {
    if (_initialized) return;
    if (!FirebaseBootstrapService.instance.isReady) {
      AppLogger.warning('[push] Firebase is not ready; skipping push init.');
      return;
    }
    if (!_isSupportedPlatform) {
      if (kDebugMode) {
        debugPrint('[push] Push notifications are mobile-only in this repo.');
      }
      return;
    }
    if (!FirebaseRemoteConfigService.instance.pushNotificationsEnabled) {
      if (kDebugMode) {
        debugPrint('[push] Push notifications disabled by Remote Config.');
      }
      return;
    }

    _initialized = true;

    // Register the background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Initialize local notifications for foreground display
    await _initLocalNotifications();

    // Create the Android notification channel
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_androidChannel);

    // Listen for foreground messages
    _foregroundSub = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    // Listen for token refresh
    _tokenRefreshSub = _messaging.onTokenRefresh.listen(_onTokenRefresh);

    // Set foreground notification presentation (iOS)
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    if (kDebugMode) {
      debugPrint('[push] PushNotificationService initialized');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Key to the root navigator — must be set by the app before notifications
  /// can route via taps. Set once in `main.dart` after router is created.
  GlobalKey<NavigatorState>? navigatorKey;

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (kDebugMode) {
      debugPrint('[push] Notification tapped: $payload');
    }

    if (payload == null || payload.isEmpty) return;

    final ctx = navigatorKey?.currentContext;
    if (ctx == null) {
      if (kDebugMode) {
        debugPrint('[push] No navigator context — cannot route');
      }
      return;
    }

    // Payload is a route path (e.g. /chat?peerId=...)
    if (payload.startsWith('/')) {
      GoRouter.of(ctx).push(payload);
    }
  }

  // ─── Foreground Message Handling ──────────────────────────────────────

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final data = message.data;
    final notifType = data['type'] as String? ?? '';

    if (kDebugMode) {
      debugPrint(
        '[push] Foreground: ${notification.title} — ${notification.body} '
        '(type: $notifType)',
      );
    }

    // Build a payload route for tap navigation
    String? payload;
    payload = data['route'] as String?;

    // Show a local notification since FCM won't display in foreground
    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title ?? 'Mobio',
      body: notification.body ?? '',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  /// Request notification permission.
  ///
  /// On Android 13+ this triggers the system dialog.
  /// On older Android, returns granted automatically.
  /// On iOS, requests alert/badge/sound permission.
  Future<bool> requestPermission() async {
    if (!_isSupportedPlatform) {
      return false;
    }

    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      return status.isGranted || status.isLimited;
    }

    // iOS uses Firebase's own permission request
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Check if notification permission is already granted.
  Future<bool> hasPermission() async {
    if (!_isSupportedPlatform) {
      return false;
    }

    if (Platform.isAndroid) {
      return (await Permission.notification.status).isGranted;
    }

    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  // ─── Token Management ────────────────────────────────────────────────

  /// Register the FCM token for the current user.
  ///
  /// Call after authentication is established.
  Future<void> registerToken() async {
    if (!SupabaseConfig.isConfigured ||
        !FirebaseBootstrapService.instance.isReady ||
        !_isSupportedPlatform ||
        !FirebaseRemoteConfigService.instance.pushNotificationsEnabled) {
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        AppLogger.warning('[push] FCM token is null or empty');
        return;
      }

      await _upsertToken(userId, token);

      if (kDebugMode) {
        debugPrint('[push] FCM token registered: ${token.substring(0, 20)}...');
      }
    } on Object catch (e) {
      AppLogger.error('[push] Failed to register FCM token: $e');
    }
  }

  /// Remove the FCM token for the current device (e.g., on logout).
  Future<void> unregisterToken() async {
    if (!SupabaseConfig.isConfigured || !_isSupportedPlatform) return;

    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;

      await Supabase.instance.client
          .from('fcm_tokens')
          .delete()
          .eq('token', token);

      if (kDebugMode) {
        debugPrint('[push] FCM token unregistered');
      }
    } on Object catch (e) {
      AppLogger.error('[push] Failed to unregister FCM token: $e');
    }
  }

  void _onTokenRefresh(String newToken) {
    if (!SupabaseConfig.isConfigured ||
        !_isSupportedPlatform ||
        !FirebaseRemoteConfigService.instance.pushNotificationsEnabled) {
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _upsertToken(userId, newToken).catchError((Object e) {
      AppLogger.error('[push] Failed to refresh FCM token: $e');
    });
  }

  Future<void> _upsertToken(String userId, String token) async {
    final platform = Platform.isIOS ? 'ios' : 'android';

    await Supabase.instance.client.from('fcm_tokens').upsert({
      'user_id': userId,
      'token': token,
      'platform': platform,
      'device_label': 'mobio-$platform',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'token');
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────

  void dispose() {
    _foregroundSub?.cancel();
    _foregroundSub = null;
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _initialized = false;
  }
}
