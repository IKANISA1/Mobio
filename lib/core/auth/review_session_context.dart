import 'dart:async';

import 'package:flutter/foundation.dart';

/// Review Auth is transport only. This identity never authorizes production
/// AccountContext work; the server separately denies its production requests.
class ReviewTransportIdentity {
  const ReviewTransportIdentity(this.userId, this.sessionId);
  final String userId;
  final String sessionId;
  String get key => '$userId:$sessionId';
}

class ReviewAccessUnavailable implements Exception {
  const ReviewAccessUnavailable();
  @override
  String toString() => 'STORE_REVIEW_ACCESS_UNAVAILABLE';
}

class ReviewSessionLease {
  const ReviewSessionLease._({
    required this.identity,
    required this.role,
    required this.generation,
    required this.fixtureVersion,
    required this.remaining,
    required this.serverNow,
    required this.responseElapsed,
  });

  static const supportedFixtureVersion = 'mobio-marketplace-v1';
  final ReviewTransportIdentity identity;
  final String role;
  final int generation;
  final String fixtureVersion;
  final Duration remaining;
  final DateTime serverNow;
  final Duration responseElapsed;

  /// Parse only a fresh status response obtained with the exact restored Auth
  /// bearer. JSON parsing alone proves neither JWT validity nor server access.
  static ReviewSessionLease parse(
    Object? value, {
    required ReviewTransportIdentity expected,
    required Duration elapsed,
  }) {
    try {
      if (value is! Map ||
          value['active'] != true ||
          value['mode'] != 'synthetic_review' ||
          value['user_id'] != expected.userId ||
          value['session_id'] != expected.sessionId ||
          !const ['passenger', 'driver'].contains(value['role']) ||
          value['generation'] is! int ||
          (value['generation'] as int) < 1 ||
          (value['generation'] as int) > 2147483647 ||
          value['fixture_version'] != supportedFixtureVersion ||
          elapsed.isNegative) {
        throw const ReviewAccessUnavailable();
      }
      DateTime timestamp(String field) {
        final raw = value[field];
        if (raw is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(raw)) {
          throw const ReviewAccessUnavailable();
        }
        return DateTime.parse(raw).toUtc();
      }

      final now = timestamp('server_now');
      final authenticated = timestamp('authenticated_at');
      final expires = timestamp('expires_at');
      final total = expires.difference(authenticated);
      final remaining = expires.difference(now) - elapsed;
      if (authenticated.isAfter(now) ||
          total <= Duration.zero ||
          total > const Duration(hours: 1) ||
          remaining <= Duration.zero ||
          remaining > const Duration(hours: 1)) {
        throw const ReviewAccessUnavailable();
      }
      return ReviewSessionLease._(
        identity: expected,
        role: value['role'] as String,
        generation: value['generation'] as int,
        fixtureVersion: value['fixture_version'] as String,
        remaining: remaining,
        serverNow: now,
        responseElapsed: elapsed,
      );
    } on Object {
      throw const ReviewAccessUnavailable();
    }
  }
}

class ReviewValidationTicket {
  ReviewValidationTicket._(this.revision, this.identity, this.startedAt);
  final int revision;
  final ReviewTransportIdentity identity;
  final Duration startedAt;
}

class ReviewActionToken {
  ReviewActionToken._(this._context, this._revision, this._identity);
  final ReviewSessionContext _context;
  final int _revision;
  final String _identity;
  bool get isCurrent =>
      _context.lease != null &&
      _context.revision == _revision &&
      _context.lease?.identity.key == _identity;
  void requireCurrent() {
    if (!isCurrent) throw const ReviewAccessUnavailable();
  }
}

/// Ephemeral authority for the bundled synthetic journey. Restart, resume,
/// replacement, logout, status failure and expiry all require fresh status.
/// Uses elapsed time rather than the device wall clock for lease expiration.
class ReviewSessionContext extends ChangeNotifier {
  ReviewSessionContext({
    required ReviewTransportIdentity? Function() readTransport,
    Duration Function()? elapsedTime,
  }) : _readTransport = readTransport,
       _elapsedTime = elapsedTime ?? (Stopwatch()..start()).elapsedAsFunction;

  final ReviewTransportIdentity? Function() _readTransport;
  final Duration Function() _elapsedTime;
  final Set<VoidCallback> _authorityListeners = {};
  ReviewSessionLease? _lease;
  Duration? _deadline;
  Duration? _acceptedAt;
  Duration _lastElapsed = Duration.zero;
  Timer? _expiry;
  int _revision = 0;
  bool _disposed = false;
  bool _pending = false;
  bool _notificationQueued = false;
  int get revision => _revision;
  bool get pending => _pending;

  /// Transport presence can suppress ordinary external effects, but does not
  /// admit a reviewer task. Task authority still requires accepted status.
  bool get hasTransport => transportIdentity != null;

  /// Read-only transport tuple for clearing a replaced volatile world while
  /// status is pending. It provides no current review action capability.
  ReviewTransportIdentity? get transportIdentity =>
      _disposed ? null : _readTransport();

  /// Volatile authority owners clear/quarantine their state before ordinary UI
  /// listeners observe a transition. These callbacks must not perform I/O.
  void addAuthorityListener(VoidCallback listener) {
    if (_disposed) throw const ReviewAccessUnavailable();
    _authorityListeners.add(listener);
  }

  void removeAuthorityListener(VoidCallback listener) =>
      _authorityListeners.remove(listener);

  void _notifyAuthorityListeners() {
    for (final listener in List<VoidCallback>.of(_authorityListeners)) {
      if (!_authorityListeners.contains(listener)) continue;
      try {
        listener();
      } on Object catch (error, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'review session authority',
            context: ErrorDescription('notifying a volatile authority owner'),
          ),
        );
      }
    }
  }

  Duration _readElapsed() {
    final now = _elapsedTime();
    if (now.isNegative || now < _lastElapsed) {
      _clear(notify: false);
      _queueNotification();
      throw const ReviewAccessUnavailable();
    }
    _lastElapsed = now;
    return now;
  }

  ReviewSessionLease? get lease {
    final value = _lease;
    if (value == null) return null;
    Duration now;
    try {
      now = _readElapsed();
    } on ReviewAccessUnavailable {
      return null;
    }
    if (_readTransport()?.key != value.identity.key ||
        _deadline == null ||
        now >= _deadline!) {
      // Revoke synchronously, notify outside a consumer's build/getter.
      _clear(notify: false);
      _queueNotification();
      return null;
    }
    return value;
  }

  bool get hasAccess => lease != null;

  /// Unlike the lease's initial duration, this decreases after acceptance.
  Duration get remaining =>
      lease == null ? Duration.zero : _deadline! - _lastElapsed;

  /// Conservative server-time upper bound for local future-departure checks.
  /// No device wall clock is used and no production authority is granted.
  DateTime? get serverTimeUpperBound {
    final value = lease;
    if (value == null || _acceptedAt == null) return null;
    return value.serverNow.add(
      value.responseElapsed + (_lastElapsed - _acceptedAt!),
    );
  }

  ReviewValidationTicket beginValidation({
    Duration elapsedAlready = Duration.zero,
  }) {
    final identity = _readTransport();
    _clear(notify: false, notifyAuthority: false);
    if (_disposed || identity == null || elapsedAlready.isNegative) {
      _notifyAuthorityListeners();
      _queueNotification();
      throw const ReviewAccessUnavailable();
    }
    final now = _readElapsed();
    _pending = true;
    _notifyAuthorityListeners();
    notifyListeners();
    return ReviewValidationTicket._(_revision, identity, now - elapsedAlready);
  }

  bool _isCurrent(ReviewValidationTicket ticket) =>
      !_disposed &&
      _pending &&
      ticket.revision == _revision &&
      ticket.identity.key == _readTransport()?.key;

  void acceptStatus(ReviewValidationTicket ticket, Object? status) {
    if (!_isCurrent(ticket)) throw const ReviewAccessUnavailable();
    final now = _readElapsed();
    final value = ReviewSessionLease.parse(
      status,
      expected: ticket.identity,
      elapsed: now - ticket.startedAt,
    );
    if (!_isCurrent(ticket)) throw const ReviewAccessUnavailable();
    _pending = false;
    _revision++;
    _lease = value;
    _acceptedAt = now;
    _deadline = now + value.remaining;
    final revision = _revision;
    _expiry = Timer(value.remaining, () {
      if (revision == _revision) invalidate();
    });
    _notifyAuthorityListeners();
    notifyListeners();
  }

  /// A late failure from account A cannot clear account B's accepted lease.
  void rejectStatus(ReviewValidationTicket ticket) {
    if (_isCurrent(ticket)) invalidate();
  }

  ReviewActionToken capture() {
    final value = lease;
    if (value == null) throw const ReviewAccessUnavailable();
    return ReviewActionToken._(this, _revision, value.identity.key);
  }

  void _clear({bool notify = true, bool notifyAuthority = true}) {
    _revision++;
    _pending = false;
    _lease = null;
    _deadline = null;
    _acceptedAt = null;
    _expiry?.cancel();
    _expiry = null;
    if (notifyAuthority) _notifyAuthorityListeners();
    if (notify && !_disposed) notifyListeners();
  }

  void _queueNotification() {
    if (_notificationQueued || _disposed) return;
    _notificationQueued = true;
    scheduleMicrotask(() {
      _notificationQueued = false;
      if (!_disposed) notifyListeners();
    });
  }

  void invalidate() => _clear();

  @override
  void dispose() {
    _disposed = true;
    _clear(notify: false);
    _authorityListeners.clear();
    super.dispose();
  }
}

extension on Stopwatch {
  Duration elapsedAsFunction() => elapsed;
}
