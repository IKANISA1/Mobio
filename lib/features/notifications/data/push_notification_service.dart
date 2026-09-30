import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/firebase/firebase_bootstrap_service.dart';
import 'package:mobi_app/core/firebase/firebase_remote_config_service.dart';
import 'package:mobi_app/core/platform/platform_io.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/notifications/domain/push_binding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background OS payloads contain generic copy only. Never log payloads/tokens.
  await FirebaseBootstrapService.instance.ensureBackgroundInitialized();
}

class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();
  static const _bindingKey = 'mobio.push.binding.v1';
  static const _deadline = Duration(seconds: 4);
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _seen = <String>{};
  final _seenOrder = Queue<String>();
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<String>? _tokenRefreshSub;
  int _lifecycle = 0;
  bool _initialized = false;
  bool _listeningAccount = false;
  Future<void>? _initializing;
  Future<void> _tokenWork = Future<void>.value();
  GlobalKey<NavigatorState>? _navigatorKey;
  Map<String, dynamic>? _pendingEnvelope;
  PushBinding? _binding;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  SupabaseClient get _client => Supabase.instance.client;
  bool get _supported => Platform.isAndroid || Platform.isIOS;
  static const _channel = AndroidNotificationChannel(
    'mobio_default',
    'Mobio Notifications',
    description: 'Messages, scheduled trip posts, and account alerts',
    importance: Importance.high,
    showBadge: true,
  );

  Future<void> initialize() {
    final pending = _initializing;
    if (pending != null) return pending;
    final lifecycle = _lifecycle;
    final work = _initialize(lifecycle).whenComplete(() {
      if (lifecycle == _lifecycle) _initializing = null;
    });
    _initializing = work;
    return work;
  }

  void _requireLifecycle(int lifecycle) {
    if (lifecycle != _lifecycle) throw StateError('PUSH_SERVICE_DISPOSED');
  }

  Future<void> _initialize(int lifecycle) async {
    if (_initialized ||
        !_supported ||
        !FirebaseBootstrapService.instance.isReady ||
        !FirebaseRemoteConfigService.instance.pushNotificationsEnabled)
      return;
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await _localNotifications
          .initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings('@mipmap/ic_launcher'),
              iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false,
              ),
            ),
            onDidReceiveNotificationResponse: _onLocalTap,
          )
          .timeout(_deadline);
      _requireLifecycle(lifecycle);
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel)
          .timeout(_deadline);
      _requireLifecycle(lifecycle);
      // The local checked handler owns foreground presentation on BOTH platforms.
      await _messaging
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: false,
            sound: false,
          )
          .timeout(_deadline);
      _requireLifecycle(lifecycle);
      final restoredBinding = await _readBinding().timeout(_deadline);
      _requireLifecycle(lifecycle);
      _binding = restoredBinding;
      if (!_listeningAccount) {
        AccountContext.changes.addListener(_onAccountChanged);
        _listeningAccount = true;
      }
      _foregroundSub = FirebaseMessaging.onMessage.listen(_onForeground);
      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_openEnvelope);
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) {
        unawaited(_registerToken(token));
      });
      _initialized = true;
      _onAccountChanged();
      try {
        final initial = await _messaging.getInitialMessage().timeout(_deadline);
        _requireLifecycle(lifecycle);
        if (initial != null) _openEnvelope(initial);
      } on Object {
        // A missing initial envelope must not tear down working foreground handlers.
        AppLogger.warning('[push] Initial notification envelope unavailable.');
      }
    } on Object {
      if (lifecycle == _lifecycle) dispose();
      AppLogger.warning(
        '[push] Initialization unavailable; in-app inbox remains available.',
      );
    }
  }

  set navigatorKey(GlobalKey<NavigatorState>? key) {
    _navigatorKey = key;
    _flushPending();
  }

  bool get _bindingIsCurrent {
    if (!SupabaseConfig.isConfigured || _binding == null) return false;
    try {
      final account = AccountContext.capture();
      return _binding!.belongsTo(account.userId, account.sessionId);
    } on Object {
      return false;
    }
  }

  void _onAccountChanged() {
    if (_bindingIsCurrent) return;
    _pendingEnvelope = null;
    _seen.clear();
    _seenOrder.clear();
    // Retain the opaque binding in memory for owning-session logout revocation.
    // It cannot present or navigate because _bindingIsCurrent is false.
    unawaited(
      _localNotifications.cancelAll().timeout(_deadline).catchError((Object _) {
        AppLogger.warning('[push] Local notification cleanup unavailable.');
      }),
    );
    if (_initialized) {
      try {
        AccountContext.capture();
        // No permission prompt: only register an already-authorized, fresh account.
        unawaited(registerToken());
      } on Object {
        /* Signed out or switching; wait for a verified account. */
      }
    }
  }

  void _onLocalTap(NotificationResponse response) {
    try {
      final raw = response.payload;
      if (raw == null || raw.length > 1024) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) _navigate(decoded);
    } on Object {
      /* Ignore stale or malformed notification envelopes. */
    }
  }

  void _openEnvelope(RemoteMessage message) => _navigate(message.data);
  void _navigate(Map<String, dynamic> envelope) {
    if (!_bindingIsCurrent || !_binding!.accepts(envelope)) return;
    final context = _navigatorKey?.currentContext;
    if (context == null) {
      _pendingEnvelope = Map<String, dynamic>.from(envelope);
      return;
    }
    _pendingEnvelope = null;
    try {
      GoRouter.of(context).push('/notifications');
    } on Object {
      AppLogger.warning('[push] Inbox navigation unavailable.');
    }
  }

  void _flushPending() {
    final envelope = _pendingEnvelope;
    if (envelope != null && _navigatorKey?.currentContext != null)
      _navigate(envelope);
  }

  void _onForeground(RemoteMessage message) {
    if (!_bindingIsCurrent || !_binding!.accepts(message.data)) return;
    final notificationId = message.data['notification_id'] as String;
    if (!_seen.add(notificationId)) return;
    _seenOrder.addLast(notificationId);
    if (_seenOrder.length > 256) _seen.remove(_seenOrder.removeFirst());
    // Do not trust title/body/route strings received over push. The inbox loads
    // real content under current Auth/RLS. Dedupe is bounded and process-local.
    unawaited(
      _localNotifications
          .show(
            id: int.parse(
              notificationId.replaceAll('-', '').substring(0, 7),
              radix: 16,
            ),
            title: 'Mobio',
            body: 'You have an update. Open Mobio to view it.',
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
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
            payload: jsonEncode({
              'protocol': 'mobio.push.v1',
              'binding_id': _binding!.bindingId,
              'notification_id': notificationId,
              'route': '/notifications',
            }),
          )
          .timeout(_deadline)
          .catchError((Object _) {
            AppLogger.warning('[push] Foreground presentation unavailable.');
          }),
    );
  }

  Future<bool> requestPermission() async {
    if (!_supported) return false;
    if (Platform.isAndroid) {
      final status = await Permission.notification.request().timeout(
        const Duration(seconds: 60),
      );
      return status.isGranted || status.isLimited;
    }
    final settings = await _messaging
        .requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        )
        .timeout(const Duration(seconds: 60));
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<bool> hasPermission() async {
    if (!_supported) return false;
    if (Platform.isAndroid)
      return (await Permission.notification.status.timeout(
        _deadline,
      )).isGranted;
    final settings = await _messaging.getNotificationSettings().timeout(
      _deadline,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> _serialize(Future<void> Function() action) {
    final task = _tokenWork.then((_) => action());
    _tokenWork = task.catchError((Object _) {});
    return task;
  }

  Future<PushBinding?> _readBinding() async {
    final prefs = await SharedPreferences.getInstance().timeout(_deadline);
    await prefs.reload().timeout(_deadline);
    final raw = prefs.getString(_bindingKey);
    if (raw == null) return null;
    if (raw.length > 1024)
      throw const FormatException('Invalid stored push binding');
    return PushBinding.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> registerToken() => _registerToken(null);
  Future<void> _registerToken(String? suppliedToken) async {
    if (!SupabaseConfig.isConfigured ||
        !FirebaseBootstrapService.instance.isReady ||
        !_supported ||
        !FirebaseRemoteConfigService.instance.pushNotificationsEnabled)
      return;
    try {
      final account = AccountContext.capture();
      final lifecycle = _lifecycle;
      await _serialize(() async {
        _requireLifecycle(lifecycle);
        AccountContext.requireCurrent(account);
        final granted = await hasPermission().timeout(_deadline);
        _requireLifecycle(lifecycle);
        AccountContext.requireCurrent(account);
        if (!granted) {
          await _revokeBinding(account.userId, account.sessionId);
          return;
        }
        final token =
            suppliedToken ?? await _messaging.getToken().timeout(_deadline);
        _requireLifecycle(lifecycle);
        AccountContext.requireCurrent(account);
        if (token == null || token.isEmpty) return;
        final result = await RequestDeadline.mutation(
          _client.rpc(
            'rpc_push_register',
            params: {
              'p_token': token,
              'p_platform': Platform.isIOS ? 'ios' : 'android',
              'p_session_id': account.sessionId,
            },
          ),
          operation: 'rpc_push_register',
          operationId: account.sessionId,
          timeout: _deadline,
        );
        _requireLifecycle(lifecycle);
        AccountContext.requireCurrent(account);
        final binding = PushBinding.fromJson(
          Map<String, dynamic>.from(result as Map),
        );
        if (!binding.belongsTo(account.userId, account.sessionId)) {
          throw const FormatException('Push binding ownership mismatch');
        }
        final prefs = await SharedPreferences.getInstance().timeout(_deadline);
        _requireLifecycle(lifecycle);
        AccountContext.requireCurrent(account);
        if (!await prefs
            .setString(_bindingKey, jsonEncode(binding.toJson()))
            .timeout(_deadline)) {
          throw StateError('PUSH_BINDING_SAVE_FAILED');
        }
        _requireLifecycle(lifecycle);
        AccountContext.requireCurrent(account);
        _binding = binding;
        _flushPending();
      });
    } on Object {
      AppLogger.warning(
        '[push] Registration not confirmed; inbox access is unaffected.',
      );
    }
  }

  Future<void> unregisterToken() async {
    if (!SupabaseConfig.isConfigured || !_supported) return;
    final owner = _client.auth.currentUser?.id;
    final session = AccountContext.sessionId(_client.auth.currentSession);
    if (owner == null || session == null) return;
    // Logout has already raised the local exit fence. Capture the still-owning
    // SDK session here; the server checks this exact session again on the RPC.
    try {
      await _serialize(() => _revokeBinding(owner, session));
    } on Object {
      AppLogger.warning('[push] Remote revocation not confirmed.');
    }
  }

  Future<void> _revokeBinding(String owner, String session) async {
    final binding = _binding ?? await _readBinding().timeout(_deadline);
    _pendingEnvelope = null;
    _seen.clear();
    _seenOrder.clear();
    if (binding == null || !binding.belongsTo(owner, session)) return;
    _binding = null;
    bool localCleanupFailed = false;
    try {
      await _localNotifications.cancelAll().timeout(_deadline);
    } on Object {
      localCleanupFailed = true;
    }
    try {
      final prefs = await SharedPreferences.getInstance().timeout(_deadline);
      // Registration/revocation are serialized; never remove a newer B binding.
      if (!await prefs.remove(_bindingKey).timeout(_deadline))
        localCleanupFailed = true;
    } on Object {
      localCleanupFailed = true;
    }
    // Native/storage cleanup failure does not prevent attempting server revocation.
    if (_client.auth.currentUser?.id == owner &&
        AccountContext.sessionId(_client.auth.currentSession) == session) {
      await RequestDeadline.mutation(
        _client.rpc(
          'rpc_push_unregister',
          params: {'p_binding_id': binding.bindingId, 'p_session_id': session},
        ),
        operation: 'rpc_push_unregister',
        operationId: binding.bindingId,
        timeout: _deadline,
      );
    }
    if (localCleanupFailed) throw StateError('PUSH_LOCAL_CLEANUP_INCOMPLETE');
  }

  void dispose() {
    _lifecycle++;
    _initializing = null;
    _binding = null;
    unawaited(_foregroundSub?.cancel());
    _foregroundSub = null;
    unawaited(_openedSub?.cancel());
    _openedSub = null;
    unawaited(_tokenRefreshSub?.cancel());
    _tokenRefreshSub = null;
    if (_listeningAccount)
      AccountContext.changes.removeListener(_onAccountChanged);
    _listeningAccount = false;
    _initialized = false;
    _pendingEnvelope = null;
    _seen.clear();
    _seenOrder.clear();
  }
}
