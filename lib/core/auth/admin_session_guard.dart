/// Lightweight session-level admin flag set after a successful allowlist check.
///
/// This is intentionally separate from routing so screens and services can
/// extend or revoke admin access without importing router definitions.
class AdminSessionGuard {
  AdminSessionGuard._();

  static bool _isAdmin = false;
  static DateTime? _grantedAt;

  /// Admin session timeout — 15 minutes of inactivity.
  static const Duration sessionTimeout = Duration(minutes: 15);

  /// Whether the current user passed the admin allowlist check this session
  /// AND the session has not expired.
  static bool get isAdmin {
    if (!_isAdmin || _grantedAt == null) {
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
  static void grant() {
    _isAdmin = true;
    _grantedAt = DateTime.now();
  }

  /// Extends the session timeout.
  static void touch() {
    if (_isAdmin) {
      _grantedAt = DateTime.now();
    }
  }

  /// Called when the user exits admin mode or their access expires.
  static void revoke() {
    _isAdmin = false;
    _grantedAt = null;
  }
}
