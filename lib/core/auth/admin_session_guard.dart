/// Client navigation gate, never server authority. Grants are accepted only
/// after the current Auth session reads its server-owned lease. Routing and
/// polling do not renew the idle deadline. Deadlines use elapsed monotonic time.
class AdminSessionGuard {
  AdminSessionGuard._();
  static final Stopwatch _clock=Stopwatch()..start();
  static String? _userId;
  static String? _sessionId;
  static int _idleDeadlineMs=0;
  static int _absoluteDeadlineMs=0;
  static const Duration sessionTimeout=Duration(minutes:15);
  static bool get isAdmin => isAdminFor(_userId,sessionId:_sessionId);
  static bool isAdminFor(String? userId,{String? sessionId}) {
    if (userId == null || userId!=_userId || sessionId==null || sessionId!=_sessionId ||
      _clock.elapsedMilliseconds>=_idleDeadlineMs || _clock.elapsedMilliseconds>=_absoluteDeadlineMs) return false;
    return true;
  }
  /// Kept for old callers, but a client allowlist/metadata response cannot grant.
  @Deprecated('Use acceptServerLease after the owner/session-bound RPC.')
  static void grant(String userId) => revoke();
  /// Kept for old callers. Only a successful server touch may extend activity.
  static void touch(String userId) {}
  static void acceptServerLease({required String userId,required String sessionId,
    required Duration idleRemaining,required Duration absoluteRemaining}) {
    if (idleRemaining<=Duration.zero || idleRemaining>const Duration(minutes:30) ||
      absoluteRemaining<=Duration.zero || absoluteRemaining>const Duration(hours:12) ||
      idleRemaining>absoluteRemaining) { revoke();throw StateError('INVALID_ADMIN_LEASE'); }
    final sameSession=_userId==userId && _sessionId==sessionId;
    final now=_clock.elapsedMilliseconds;
    final absolute=now+absoluteRemaining.inMilliseconds;
    _absoluteDeadlineMs=sameSession && _absoluteDeadlineMs<absolute ? _absoluteDeadlineMs:absolute;
    _idleDeadlineMs=now+idleRemaining.inMilliseconds;
    if (_idleDeadlineMs>_absoluteDeadlineMs) _idleDeadlineMs=_absoluteDeadlineMs;
    _userId=userId;_sessionId=sessionId;
  }
  static void revoke() { _userId=null;_sessionId=null;_idleDeadlineMs=0;_absoluteDeadlineMs=0; }
}
