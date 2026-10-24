import 'package:flutter/foundation.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSessionService {
  AdminSessionService._();
  static final _synchronizer = AdminSessionSynchronizer(
    captureAccount: AccountContext.capture,
    isCurrent: AccountContext.isCurrent,
    readLease: (userActivity) => Supabase.instance.client.rpc<dynamic>(
      'rpc_admin_session',
      params: {'p_action': userActivity ? 'touch' : 'status'},
    ),
  );
  static Future<bool> synchronize({bool userActivity = false}) =>
      _synchronizer.synchronize(userActivity: userActivity);
  static Future<void> revoke() async {
    _synchronizer.invalidate();
    AdminSessionGuard.revoke();
    try {
      await Supabase.instance.client
          .rpc<dynamic>('rpc_admin_session', params: {'p_action': 'revoke'})
          .timeout(const Duration(seconds: 3));
    } on Object {
      /* Local navigation is already locked; Auth logout follows. */
    }
  }
}

/// Lease reads coalesce only inside their originating account generation.
class AdminSessionSynchronizer {
  @visibleForTesting
  AdminSessionSynchronizer({
    required this.captureAccount,
    required this.isCurrent,
    required this.readLease,
  });
  final AccountSnapshot Function() captureAccount;
  final bool Function(AccountSnapshot) isCurrent;
  final Future<dynamic> Function(bool userActivity) readLease;
  final _inFlight = <(String, int), Future<bool>>{};
  int _invalidation = 0;

  void invalidate() {
    _invalidation++;
    _inFlight.clear();
  }

  Future<bool> synchronize({bool userActivity = false}) {
    AccountSnapshot snapshot;
    try {
      snapshot = captureAccount();
    } on Object {
      AdminSessionGuard.revoke();
      return Future.value(false);
    }
    final key = (snapshot.identity, snapshot.generation);
    final pending = _inFlight[key];
    // Status is never promoted into a touch by a subsequent joiner.
    if (pending != null) return pending;
    final revision = _invalidation;
    late final Future<bool> work;
    work = _read(snapshot, userActivity, revision).whenComplete(() {
      if (identical(_inFlight[key], work)) _inFlight.remove(key);
    });
    _inFlight[key] = work;
    return work;
  }

  Future<bool> _read(
    AccountSnapshot snapshot,
    bool userActivity,
    int revision,
  ) async {
    final elapsed = Stopwatch()..start();
    bool current() => revision == _invalidation && isCurrent(snapshot);
    try {
      final response = await readLease(
        userActivity,
      ).timeout(const Duration(seconds: 8));
      if (!current()) return false;
      if (response is! Map ||
          response['active'] != true ||
          response['user_id'] != snapshot.userId ||
          response['session_id'] != snapshot.sessionId) {
        throw StateError('ADMIN_LEASE_INACTIVE');
      }
      final serverNow = DateTime.parse(response['server_now'] as String);
      AdminSessionGuard.acceptServerLease(
        userId: snapshot.userId,
        sessionId: snapshot.sessionId,
        idleRemaining:
            DateTime.parse(
              response['idle_expires_at'] as String,
            ).difference(serverNow) -
            elapsed.elapsed,
        absoluteRemaining:
            DateTime.parse(
              response['absolute_expires_at'] as String,
            ).difference(serverNow) -
            elapsed.elapsed,
      );
      return true;
    } on Object {
      if (current()) AdminSessionGuard.revoke();
      return false;
    }
  }
}
