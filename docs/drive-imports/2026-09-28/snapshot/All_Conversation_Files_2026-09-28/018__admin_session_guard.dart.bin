/// Lightweight session-level admin flag set after a successful allowlist check.
///
/// This is intentionally separate from routing so screens and services can
/// extend or revoke admin access without importing router definitions.
class AdminSessionGuard {
  AdminSessionGuard._();

  static bool _isAdmin = false;
  static DateTime? _grantedAt;
  static String? _userId;

  /// Admin session timeout — 15 minutes of inactivity.
  static const Duration sessionTimeout = Duration(minutes: 15);

  /// Whether the current user passed the admin allowlist check this session
  /// AND the session has not expired.
  static bool get isAdmin {
    if (_userId == null) {
      return false;
    }

    return isAdminFor(_userId);
  }

  /// Whether the fallback admin grant belongs to [userId] and has not expired.
  static bool isAdminFor(String? userId) {
    if (!_isAdmin || _grantedAt == null) {
      return false;
    }

    if (userId == null || userId != _userId) {
      revoke();
      return false;
    }

    final elapsed = DateTime.now().difference(_grantedAt!);
    if (elapsed > sessionTimeout) {
      revoke();
      return false;
    }

    return true;
  }

  /// Called after the allowlist check succeeds.
  static void grant(String userId) {
    _isAdmin = true;
    _grantedAt = DateTime.now();
    _userId = userId;
  }

  /// Extends the session timeout.
  static void touch(String userId) {
    if (isAdminFor(userId)) {
      _grantedAt = DateTime.now();
    }
  }

  /// Called when the user exits admin mode or their access expires.
  static void revoke() {
    _isAdmin = false;
    _grantedAt = null;
    _userId = null;
  }
}
