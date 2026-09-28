import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountSnapshot {
  const AccountSnapshot(this.userId, this.sessionId, this.generation);
  final String userId;
  final String sessionId;
  final int generation;
  String get identity => '$userId:$sessionId';
}
/// A durable exit marker is deliberately separate from SDK session persistence.
/// A failed/offline SDK sign-out cannot make a retained session trusted on reboot.
/// Only the explicit successful OTP login callbacks clear this marker.
class AccountContext {
  AccountContext._();
  static final _epoch = AccountEpoch();
  static final changes=ValueNotifier<int>(0);
  static StreamSubscription<AuthState>? _subscription;
  static bool _notificationScheduled = false;
  static int _fenceRevision = 0;
  static void _notifyChanged() {
    // Capture can run while a widget is building. Notify on the next microtask,
    // including when capture observes a new session before the Auth stream does.
    if (_notificationScheduled) return;
    _notificationScheduled = true;
    scheduleMicrotask(() { _notificationScheduled = false; changes.value++; });
  }
  static int _synchronizeIdentity(String? identity) {
    final before = _epoch.generation;
    final generation = _epoch.update(identity);
    if (before != generation) { AdminSessionGuard.revoke(); _notifyChanged(); }
    return generation;
  }
  static void attach() {
    _subscription ??= Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      final auth = Supabase.instance.client.auth;
      final sid = sessionId(auth.currentSession);
      _synchronizeIdentity(sid == null ? null : '${auth.currentUser?.id}:$sid');
    });
  }
  static const _exitKey = 'mobio.auth.exit_requested.v1';
  static bool _exitRequested = false;
  static String? _exitingSession;
  static bool get exitRequested => _exitRequested;
  static Future<void> restoreExitFence() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    _exitRequested = prefs.getBool(_exitKey) ?? false;
  }
  static String? sessionId(Session? session) {
    if (session == null) return null;
    try {
      final parts = session.accessToken.split('.');
      if (parts.length != 3) return null;
      final claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final sid = claims is Map ? claims['session_id'] : null;
      return sid is String && RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(sid) ? sid : null;
    } on Object { return null; }
  }
  static bool get hasVerifiedSession {
    if (_exitRequested) return false;
    final auth = Supabase.instance.client.auth;
    final user = auth.currentUser;
    final provider = user?.appMetadata['provider'];
    final sid = sessionId(auth.currentSession);
    _synchronizeIdentity(user == null || sid == null ? null : '${user.id}:$sid');
    return user != null && !user.isAnonymous && sessionId(auth.currentSession) != null &&
      (provider == 'whatsapp_cloud_otp' || provider == 'admin_whatsapp_otp');
  }
  static AccountSnapshot capture() {
    if (!hasVerifiedSession) throw const StaleAccountWork();
    final auth = Supabase.instance.client.auth;
    final userId = auth.currentUser!.id;
    final sid = sessionId(auth.currentSession)!;
    return AccountSnapshot(userId,sid,_synchronizeIdentity('$userId:$sid'));
  }
  static bool isCurrent(AccountSnapshot snapshot) {
    try {
      final current = capture();
      return current.identity == snapshot.identity && current.generation == snapshot.generation;
    } on Object { return false; }
  }
  static void requireCurrent(AccountSnapshot snapshot) {
    if (!isCurrent(snapshot)) throw const StaleAccountWork();
  }
  static Future<void> beginExit() async {
    _exitingSession = sessionId(Supabase.instance.client.auth.currentSession);
    _exitRequested = true;
    _fenceRevision++; _epoch.invalidate(); _notifyChanged();
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_exitKey,true)) throw StateError('EXIT_MARKER_WRITE_FAILED');
    await prefs.reload();
    if (prefs.getBool(_exitKey) != true) throw StateError('EXIT_MARKER_VERIFY_FAILED');
  }
  static Future<void> completeVerifiedLogin() async {
    final auth = Supabase.instance.client.auth;
    final sid = sessionId(auth.currentSession);
    final user = auth.currentUser;
    final revision = _fenceRevision;
    if (user == null || user.isAnonymous || sid == null || sid == _exitingSession ||
        !const ['whatsapp_cloud_otp', 'admin_whatsapp_otp'].contains(user.appMetadata['provider'])) {
      throw StateError('FRESH_VERIFIED_LOGIN_REQUIRED');
    }
    bool sameLogin() => revision == _fenceRevision &&
        auth.currentUser?.id == user.id && sessionId(auth.currentSession) == sid;
    final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 3));
    if (!sameLogin()) throw const StaleAccountWork();
    // remove/read-back is awaited rather than raced with a timeout: a late
    // removal must never silently clear a newer sign-out marker on disk.
    if (!await prefs.remove(_exitKey)) throw StateError('EXIT_MARKER_CLEAR_FAILED');
    await prefs.reload();
    if (!sameLogin()) {
      _exitRequested = true;
      await prefs.setBool(_exitKey, true);
      throw const StaleAccountWork();
    }
    if (prefs.containsKey(_exitKey)) throw StateError('EXIT_MARKER_CLEAR_FAILED');
    _exitRequested = false;
    _exitingSession = null;
    _fenceRevision++;
    _epoch.invalidate();
    _notifyChanged();
  }
}
