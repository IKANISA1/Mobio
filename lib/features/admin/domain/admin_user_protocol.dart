/// Strict feature-local readers for the versioned Admin member contracts.
/// These readers validate evidence; they never grant account authority.
abstract final class AdminUserProtocol {
  static const version = 'mobio.admin-users.v1';
  static const roles = {'admin', 'driver', 'passenger'};
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static Map<String, dynamic> object(Object? value, String label) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw FormatException('Invalid Admin $label object.');
    }
    return Map<String, dynamic>.from(value);
  }

  static Object? field(Map<String, dynamic> row, String key) {
    if (!row.containsKey(key)) {
      throw FormatException('Missing Admin field: $key.');
    }
    return row[key];
  }

  static String text(Map<String, dynamic> row, String key) {
    final value = field(row, key);
    if (value is! String || value.isEmpty) {
      throw FormatException('Invalid Admin text: $key.');
    }
    return value;
  }

  static String? nullableText(Map<String, dynamic> row, String key) {
    final value = field(row, key);
    if (value == null) return null;
    if (value is! String || value.isEmpty) {
      throw FormatException('Invalid Admin optional text: $key.');
    }
    return value;
  }

  static String id(Map<String, dynamic> row, String key) {
    final value = text(row, key);
    if (!_uuid.hasMatch(value)) {
      throw FormatException('Invalid Admin identifier: $key.');
    }
    return value.toLowerCase();
  }

  static String? nullableId(Map<String, dynamic> row, String key) =>
      field(row, key) == null ? null : id(row, key);

  static int integer(
    Map<String, dynamic> row,
    String key, {
    int minimum = 0,
    int maximum = 9007199254740991,
  }) {
    final value = field(row, key);
    if (value is! int || value < minimum || value > maximum) {
      throw FormatException('Invalid Admin integer: $key.');
    }
    return value;
  }

  static bool flag(Map<String, dynamic> row, String key) {
    final value = field(row, key);
    if (value is! bool) {
      throw FormatException('Invalid Admin boolean: $key.');
    }
    return value;
  }

  static DateTime date(Map<String, dynamic> row, String key) {
    final value = DateTime.tryParse(text(row, key));
    if (value == null || !value.isUtc) {
      throw FormatException('Invalid Admin timestamp: $key.');
    }
    return value.toUtc();
  }

  static DateTime? nullableDate(Map<String, dynamic> row, String key) =>
      field(row, key) == null ? null : date(row, key);

  static String choice(
    Map<String, dynamic> row,
    String key,
    Set<String> choices,
  ) {
    final value = text(row, key);
    if (!choices.contains(value)) {
      throw FormatException('Invalid Admin choice: $key.');
    }
    return value;
  }

  static List<Map<String, dynamic>> objects(
    Map<String, dynamic> row,
    String key, {
    int maximum = 100,
  }) {
    final value = field(row, key);
    if (value is! List || value.length > maximum) {
      throw FormatException('Invalid Admin collection: $key.');
    }
    return value.map((item) => object(item, key)).toList(growable: false);
  }

  static void header(
    Map<String, dynamic> row, {
    required String actorId,
    required String sessionId,
  }) {
    if (text(row, 'protocol') != version ||
        id(row, 'actor_id') != actorId.toLowerCase() ||
        id(row, 'session_id') != sessionId.toLowerCase()) {
      throw const FormatException('Admin response authority binding mismatch.');
    }
  }
}

/// A conservative deadline measured by an injected monotonic clock.
/// Device wall time cannot extend a server lease. The full request round trip is
/// deducted because the response's server timestamp may precede its receipt.
class AdminMonotonicDeadline {
  AdminMonotonicDeadline({
    required DateTime serverNow,
    required DateTime expiresAt,
    required Duration requestStarted,
    required Duration responseReceived,
    required this._elapsed,
  }) : _serverNow = serverNow,
       _roundTrip = responseReceived - requestStarted,
       _received = responseReceived,
       _lastElapsed = responseReceived,
       _budget =
           expiresAt.difference(serverNow) -
           (responseReceived - requestStarted) {
    if (responseReceived < requestStarted) {
      throw const FormatException('Invalid Admin monotonic request interval.');
    }
  }

  final Duration Function() _elapsed;
  final DateTime _serverNow;
  final Duration _roundTrip;
  final Duration _received;
  final Duration _budget;
  Duration _lastElapsed;
  bool _revoked = false;

  Duration get remaining {
    if (_revoked) return Duration.zero;
    final now = _elapsed();
    if (now < _lastElapsed) {
      _revoked = true;
      return Duration.zero;
    }
    _lastElapsed = now;
    final sinceReceipt = now - _received;
    // A backwards/reset monotonic source cannot revive a captured deadline.
    if (sinceReceipt < Duration.zero) return Duration.zero;
    final value = _budget - sinceReceipt;
    if (value <= Duration.zero) _revoked = true;
    return value > Duration.zero ? value : Duration.zero;
  }

  bool get expired => remaining == Duration.zero;

  Duration ageUpperBound(DateTime asOf) {
    final sinceReceipt = _elapsed() - _received;
    final age =
        _serverNow.difference(asOf) +
        _roundTrip +
        (sinceReceipt < Duration.zero ? Duration.zero : sinceReceipt);
    return age > Duration.zero ? age : Duration.zero;
  }
}
