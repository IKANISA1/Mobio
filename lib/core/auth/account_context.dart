import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';
import 'package:mobi_app/core/auth/review_session_context.dart';
import 'auth_session_storage.dart';
import 'session_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountSnapshot {
  const AccountSnapshot(this.userId, this.sessionId, this.generation);
  final String userId;
  final String sessionId;
  final int generation;
  String get identity => '$userId:$sessionId';
}

/// A ticket is valid only for one foreground verification transition. It is not
/// an auth credential and is never persisted or sent to a backend.
class LoginAttempt {
  LoginAttempt._(
    this.revision,
    this.storageGeneration,
    this.previousSession,
    this.provider,
  );
  final int revision;
  final int storageGeneration;
  final String? previousSession;
  final String provider;
  StoredSessionIdentity? _restoredIdentity;
  late final Future<void> _prepared;
  bool _isPrepared = false;
  int? _committedRevision;
}

class AccountContext {
  AccountContext._();
  static final _epoch = AccountEpoch();
  static final changes = ValueNotifier<int>(0);
  static StreamSubscription<AuthState>? _subscription;
  static bool _notificationScheduled = false;
  static int _fenceRevision = 0;
  static Future<void> _diskTail = Future<void>.value();
  static Future<void> _sdkTail = Future<void>.value();
  static int _sdkOperations = 0;
  static int _logoutHolds = 0;
  static bool get _restorePending => _sdkOperations > 0;
  static void beginLogoutOperation() {
    _logoutHolds++;
  }

  static void endLogoutOperation() {
    if (_logoutHolds > 0) _logoutHolds--;
  }

  static Future<T> _sdk<T>(Future<T> Function() operation) {
    _sdkOperations++;
    final work = _sdkTail.then((_) => operation());
    _sdkTail = work.then<void>(
      (_) {
        _sdkOperations--;
      },
      onError: (Object _, StackTrace __) {
        _sdkOperations--;
      },
    );
    return work;
  }

  static Future<void> signOutSdkLocally() => _sdk(
    () => Supabase.instance.client.auth.signOut(scope: SignOutScope.local),
  );
  static Future<bool> bootstrapAnonymous() async {
    if (_exitRequested ||
        _activeLogin != null ||
        _restorePending ||
        _logoutHolds > 0)
      return false;
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession != null) return true;
    return (await _sdk(() => auth.signInAnonymously())).session != null;
  }

  static LoginAttempt? _activeLogin;
  static const _exitKey = 'mobio.auth.exit_requested.v1';
  static bool _exitRequested = false;
  static bool get exitRequested => _exitRequested;
  static String? _interactiveIdentity;
  static String? _interactiveProvider;
  static int _authorityRequest = 0;
  static final reviewSession = _createReviewSession();
  static ReviewSessionContext _createReviewSession() {
    final context = ReviewSessionContext(readTransport: _reviewTransport);
    context.addListener(_notifyChanged);
    return context;
  }

  static ReviewTransportIdentity? _reviewTransport() {
    try {
      if (_exitRequested || !AuthSessionStorage.configured) return null;
      final auth = Supabase.instance.client.auth;
      final sid = sessionId(auth.currentSession);
      final user = auth.currentUser;
      if (user == null ||
          user.isAnonymous ||
          sid == null ||
          user.appMetadata['provider'] != 'store_review' ||
          !AuthSessionStorage.instance.persistence.accepts(user.id, sid))
        return null;
      return ReviewTransportIdentity(user.id, sid);
    } on Object {
      return null;
    }
  }

  static bool get hasReviewTransport => _reviewTransport() != null;

  /// Cold restores and fresh login commits require the real caller-bound RPC.
  /// A provider tag or a structurally valid JWT is never a WhatsApp OTP proof.
  static Future<bool> validateInteractiveSession({
    bool requireSavedTransport = true,
  }) async {
    int? request;
    try {
      final auth = Supabase.instance.client.auth;
      final user = auth.currentUser;
      final sid = sessionId(auth.currentSession);
      final provider = user?.appMetadata['provider'];
      if (user == null ||
          user.isAnonymous ||
          sid == null ||
          !const [
            'whatsapp_cloud_otp',
            'admin_whatsapp_otp',
          ].contains(provider) ||
          (requireSavedTransport &&
              (_exitRequested ||
                  !AuthSessionStorage.instance.persistence.accepts(
                    user.id,
                    sid,
                  ))))
        return false;
      final key = '${user.id}:$sid';
      _synchronizeIdentity(key);
      final revision = _fenceRevision;
      request = ++_authorityRequest;
      _interactiveIdentity = null;
      _interactiveProvider = null;
      _notifyChanged();
      final result = await Supabase.instance.client
          .rpc('rpc_verified_interactive_session')
          .timeout(const Duration(seconds: 8));
      if (request != _authorityRequest ||
          revision != _fenceRevision ||
          auth.currentUser?.id != user.id ||
          sessionId(auth.currentSession) != sid ||
          auth.currentUser?.appMetadata['provider'] != provider)
        return false;
      if (result is! Map ||
          result['user_id'] != user.id ||
          result['session_id'] != sid) {
        _interactiveIdentity = null;
        _interactiveProvider = null;
        _notifyChanged();
        return false;
      }
      _interactiveIdentity = key;
      _interactiveProvider = provider as String;
      _notifyChanged();
      return true;
    } on Object {
      // The response can never promote a replacement account. Denied or
      // unavailable authority stays quarantined until an explicit fresh check.
      if (request != null && request == _authorityRequest) {
        _interactiveIdentity = null;
        _interactiveProvider = null;
        _notifyChanged();
      }
      return false;
    }
  }

  static void _notifyChanged() {
    if (_notificationScheduled) return;
    _notificationScheduled = true;
    scheduleMicrotask(() {
      _notificationScheduled = false;
      changes.value++;
    });
  }

  static int _synchronizeIdentity(String? identity) {
    final before = _epoch.generation;
    final generation = _epoch.update(identity);
    if (before != generation) {
      _authorityRequest++;
      _interactiveIdentity = null;
      _interactiveProvider = null;
      reviewSession.invalidate();
      AdminSessionGuard.revoke();
      _notifyChanged();
    }
    return generation;
  }

  static void attach() {
    AuthSessionStorage.instance.persistence.onStateChanged = () {
      if (AuthSessionStorage.instance.persistence.failed) {
        _authorityRequest++;
        _interactiveIdentity = null;
        _interactiveProvider = null;
        reviewSession.invalidate();
        AdminSessionGuard.revoke();
      }
      _notifyChanged();
    };
    _subscription ??= Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) {
        final auth = Supabase.instance.client.auth;
        final sid = sessionId(auth.currentSession);
        _synchronizeIdentity(
          sid == null ? null : '${auth.currentUser?.id}:$sid',
        );
        if (!_exitRequested &&
            !hasReviewTransport &&
            _interactiveIdentity != '${auth.currentUser?.id}:$sid' &&
            AuthSessionStorage.instance.persistence.accepts(
              auth.currentUser?.id ?? '',
              sid ?? '',
            )) {
          unawaited(validateInteractiveSession());
        }
      },
      onError: (Object _) {
        _notifyChanged();
      },
    );
    if (!_exitRequested && !hasReviewTransport)
      unawaited(validateInteractiveSession());
  }

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
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final sid = claims is Map ? claims['session_id'] : null;
      return sid is String &&
              sid.length == 36 &&
              RegExp(
                r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
              ).hasMatch(sid)
          ? sid
          : null;
    } on Object {
      return null;
    }
  }

  static bool get hasVerifiedSession {
    if (_exitRequested || !AuthSessionStorage.configured) return false;
    final auth = Supabase.instance.client.auth;
    final user = auth.currentUser;
    final sid = sessionId(auth.currentSession);
    _synchronizeIdentity(
      user == null || sid == null ? null : '${user.id}:$sid',
    );
    return user != null &&
        !user.isAnonymous &&
        sid != null &&
        const [
          'whatsapp_cloud_otp',
          'admin_whatsapp_otp',
        ].contains(user.appMetadata['provider']) &&
        _interactiveIdentity == '${user.id}:$sid' &&
        _interactiveProvider == user.appMetadata['provider'] &&
        AuthSessionStorage.instance.persistence.accepts(user.id, sid);
  }

  static AccountSnapshot capture() {
    if (!hasVerifiedSession) throw const StaleAccountWork();
    final auth = Supabase.instance.client.auth;
    final userId = auth.currentUser!.id;
    final sid = sessionId(auth.currentSession)!;
    return AccountSnapshot(userId, sid, _synchronizeIdentity('$userId:$sid'));
  }

  static bool isCurrent(AccountSnapshot snapshot) {
    try {
      final current = capture();
      return current.identity == snapshot.identity &&
          current.generation == snapshot.generation;
    } on Object {
      return false;
    }
  }

  static void requireCurrent(AccountSnapshot snapshot) {
    if (!isCurrent(snapshot)) throw const StaleAccountWork();
  }

  static Future<void> _disk(Future<void> Function() action) {
    final work = _diskTail.then((_) => action());
    _diskTail = work.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return work;
  }

  static Future<void> _saveExit() => _disk(() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_exitKey, true))
      throw StateError('EXIT_MARKER_WRITE_FAILED');
    await prefs.reload();
    if (prefs.getBool(_exitKey) != true)
      throw StateError('EXIT_MARKER_VERIFY_FAILED');
  });
  static void _invalidate() {
    _exitRequested = true;
    _fenceRevision++;
    _epoch.invalidate();
    _authorityRequest++;
    _interactiveIdentity = null;
    _interactiveProvider = null;
    reviewSession.invalidate();
    AdminSessionGuard.revoke();
    _notifyChanged();
  }

  static Future<void> beginExit() {
    _activeLogin = null;
    _invalidate();
    // Start both even if either fails. The native queue retains in-flight work
    // after a caller timeout, and logout never relies only on SDK signOut.
    final clear = AuthSessionStorage.instance.persistence.lockAndClear();
    return Future.wait<void>([_saveExit(), clear]).then((_) {});
  }

  static LoginAttempt beginLoginAttempt({required String provider}) {
    if (_activeLogin != null || _restorePending || _logoutHolds > 0)
      throw StateError('LOGIN_TRANSITION_PENDING');
    if (!const [
      'whatsapp_cloud_otp',
      'admin_whatsapp_otp',
      'store_review',
    ].contains(provider))
      throw const StaleAccountWork();
    final previous = sessionId(Supabase.instance.client.auth.currentSession);
    _invalidate();
    final clear = AuthSessionStorage.instance.persistence.lockAndClear();
    final ticket = LoginAttempt._(
      _fenceRevision,
      AuthSessionStorage.instance.persistence.generation,
      previous,
      provider,
    );
    _activeLogin = ticket;
    ticket._prepared = Future.wait<void>([_saveExit(), clear]).then((_) {
      requireLoginAttempt(ticket);
      ticket._isPrepared = true;
    });
    return ticket;
  }

  static Future<void> prepareLogin(LoginAttempt ticket) =>
      ticket._prepared.timeout(const Duration(seconds: 6));
  static void requireLoginAttempt(LoginAttempt ticket) {
    if (!identical(_activeLogin, ticket) ||
        ticket.revision != _fenceRevision ||
        ticket.storageGeneration !=
            AuthSessionStorage.instance.persistence.generation) {
      throw const StaleAccountWork();
    }
  }

  static Future<void> restoreServerSession(
    LoginAttempt ticket,
    Map<String, dynamic> serverSession,
  ) async {
    requireLoginAttempt(ticket);
    if (!ticket._isPrepared) throw const StaleAccountWork();
    final expected = StoredSessionIdentity.parse(
      jsonEncode(serverSession),
      issuer: AuthSessionStorage.instance.persistence.issuer,
    );
    if (expected.provider != ticket.provider ||
        expected.sessionId == ticket.previousSession ||
        _restorePending) {
      throw StateError('FRESH_VERIFIED_LOGIN_REQUIRED');
    }
    final auth = Supabase.instance.client.auth;
    // Auth mutation remains serialized until its original Future settles,
    // including when a UI timeout has already returned an unavailable result.
    final restore = _sdk(
      () => auth.setSession(serverSession['refresh_token'] as String),
    );
    final response = await restore.timeout(const Duration(seconds: 12));
    requireLoginAttempt(ticket);
    if (response.session == null || auth.currentSession == null)
      throw const StaleAccountWork();
    final actual = StoredSessionIdentity.parse(
      jsonEncode(response.session!.toJson()),
      issuer: AuthSessionStorage.instance.persistence.issuer,
    );
    if (actual.key != expected.key ||
        actual.provider != expected.provider ||
        auth.currentUser?.id != expected.userId ||
        sessionId(auth.currentSession) != expected.sessionId) {
      throw const StaleAccountWork();
    }
    _synchronizeIdentity(expected.key);
    ticket._restoredIdentity = expected;
  }

  static Future<void> completeVerifiedLogin(LoginAttempt ticket) async {
    requireLoginAttempt(ticket);
    if (ticket.provider == 'store_review' ||
        !await validateInteractiveSession(requireSavedTransport: false)) {
      throw const StaleAccountWork();
    }
    await _completeTransportLogin(ticket);
  }

  static Future<void> completeReviewLogin(
    LoginAttempt ticket, {
    required Object? status,
    required Duration Function() elapsedTime,
  }) async {
    requireLoginAttempt(ticket);
    final identity = ticket._restoredIdentity;
    if (ticket.provider != 'store_review' || identity == null)
      throw const StaleAccountWork();
    final expected = ReviewTransportIdentity(
      identity.userId,
      identity.sessionId,
    );
    ReviewSessionLease.parse(
      status,
      expected: expected,
      elapsed: elapsedTime(),
    );
    await _completeTransportLogin(ticket);
    final validation = reviewSession.beginValidation(
      elapsedAlready: elapsedTime(),
    );
    reviewSession.acceptStatus(validation, status);
  }

  static Future<void> _completeTransportLogin(LoginAttempt ticket) async {
    requireLoginAttempt(ticket);
    final expected = ticket._restoredIdentity;
    final auth = Supabase.instance.client.auth;
    bool sameLogin() =>
        identical(_activeLogin, ticket) &&
        ticket.revision == _fenceRevision &&
        expected != null &&
        auth.currentUser?.id == expected.userId &&
        sessionId(auth.currentSession) == expected.sessionId;
    if (!sameLogin() || auth.currentSession == null)
      throw const StaleAccountWork();
    await AuthSessionStorage.instance.persistence.acceptVerified(
      jsonEncode(auth.currentSession!.toJson()),
      expectedGeneration: ticket.storageGeneration,
    );
    requireLoginAttempt(ticket);
    // Serialized with every exit-marker write: an old completion can never
    // remove a newer logout marker. Do not timeout individual disk mutations.
    await _disk(() async {
      if (!sameLogin()) throw const StaleAccountWork();
      final prefs = await SharedPreferences.getInstance();
      if (!sameLogin()) throw const StaleAccountWork();
      if (!await prefs.remove(_exitKey))
        throw StateError('EXIT_MARKER_CLEAR_FAILED');
      await prefs.reload();
      if (!sameLogin()) {
        await prefs.setBool(_exitKey, true);
        throw const StaleAccountWork();
      }
      if (prefs.containsKey(_exitKey))
        throw StateError('EXIT_MARKER_CLEAR_FAILED');
    });
    if (!sameLogin()) throw const StaleAccountWork();
    _activeLogin = null;
    _exitRequested = false;
    _fenceRevision++;
    ticket._committedRevision = _fenceRevision;
    _epoch.invalidate();
    _notifyChanged();
  }

  static Future<void> cancelPendingLogin(LoginAttempt? ticket) async {
    // A normal route change after commit must not undo a successful login.
    if (ticket != null && identical(_activeLogin, ticket)) await beginExit();
  }

  static Future<void> abortLogin(LoginAttempt? ticket) async {
    if (ticket == null) return;
    if (identical(_activeLogin, ticket)) {
      await beginExit();
      return;
    }
    // A timeout/lease failure just after commit must revoke that exact login,
    // without signing out a newer verification that won a subsequent race.
    final expected = ticket._restoredIdentity;
    final auth = Supabase.instance.client.auth;
    if (_activeLogin == null &&
        ticket._committedRevision == _fenceRevision &&
        expected != null &&
        auth.currentUser?.id == expected.userId &&
        sessionId(auth.currentSession) == expected.sessionId) {
      await beginExit();
    }
  }
}
