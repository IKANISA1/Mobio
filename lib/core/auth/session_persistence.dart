import 'dart:async';
import 'dart:convert';

/// Intentionally opaque storage; implementations may never fall back to prefs.
abstract interface class SessionValueStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
  Future<void> reset();
}

class SessionStorageFailure implements Exception {
  const SessionStorageFailure();
  @override
  String toString() => 'AUTH_STORAGE_UNAVAILABLE';
}

class InvalidStoredSession implements Exception {
  const InvalidStoredSession();
  @override
  String toString() => 'INVALID_STORED_SESSION';
}

class StoredSessionIdentity {
  const StoredSessionIdentity(
    this.userId,
    this.sessionId,
    this.provider,
    this.issuedAt,
  );
  final String userId;
  final String sessionId;
  final String provider;
  final int issuedAt;
  String get key => '$userId:$sessionId';
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// This is a storage-shape/identity check, NOT JWT signature verification or
  /// server authorization. Only the real Auth exchange may create login trust.
  static StoredSessionIdentity parse(String value, {required String issuer}) {
    try {
      if (utf8.encode(value).length > 65536) throw const InvalidStoredSession();
      final data = jsonDecode(value);
      if (data is! Map || data['user'] is! Map)
        throw const InvalidStoredSession();
      final user = data['user'] as Map;
      final token = data['access_token'];
      final refresh = data['refresh_token'];
      final uid = user['id'];
      final meta = user['app_metadata'];
      final provider = meta is Map ? meta['provider'] : null;
      if (uid is! String ||
          uid.length != 36 ||
          !_uuid.hasMatch(uid) ||
          user['is_anonymous'] == true ||
          token is! String ||
          token.isEmpty ||
          refresh is! String ||
          refresh.isEmpty ||
          !const [
            'whatsapp_cloud_otp',
            'admin_whatsapp_otp',
            'store_review',
          ].contains(provider)) {
        throw const InvalidStoredSession();
      }
      final parts = token.split('.');
      if (parts.length != 3) throw const InvalidStoredSession();
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (claims is! Map ||
          claims['iss'] != issuer ||
          claims['sub'] != uid ||
          claims['role'] != 'authenticated' ||
          claims['is_anonymous'] == true ||
          claims['session_id'] is! String ||
          (claims['session_id'] as String).length != 36 ||
          !_uuid.hasMatch(claims['session_id'] as String) ||
          claims['iat'] is! int ||
          (claims['iat'] as int) < 0) {
        throw const InvalidStoredSession();
      }
      return StoredSessionIdentity(
        uid,
        claims['session_id'] as String,
        provider as String,
        claims['iat'] as int,
      );
    } on Object {
      // No token or decoded claim is included in any exception.
      throw const InvalidStoredSession();
    }
  }
}

/// Serializes SDK writes, explicit login commits, and credential removal. A
/// deadline at the caller does not release this queue or cancel a native write.
class SessionPersistence {
  SessionPersistence({
    required this.store,
    required this.issuer,
    required this.purgeLegacy,
  });
  final SessionValueStore store;
  final String issuer;
  final Future<void> Function() purgeLegacy;
  void Function()? onStateChanged;
  Future<void> _tail = Future<void>.value();
  Future<void>? _initialization;
  bool _ready = false;
  bool _failed = false;
  int _generation = 0;
  String? _cached;
  StoredSessionIdentity? _accepted;

  int get generation => _generation;
  bool get failed => _failed;
  bool get isReady => _ready;
  String? get acceptedIdentity => !_failed ? _accepted?.key : null;
  bool accepts(String userId, String sessionId) =>
      _ready && !_failed && _accepted?.key == '$userId:$sessionId';

  Future<T> _serial<T>(Future<T> Function() action) {
    final work = _tail.then((_) => action());
    _tail = work.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return work;
  }

  void _fault() {
    _failed = true;
    _cached = null;
    _accepted = null;
    _generation++;
    onStateChanged?.call();
  }

  Future<void> initialize({
    bool discardSavedSession = false,
  }) => _initialization ??= _serial(() async {
    try {
      final value = discardSavedSession ? null : await store.read();
      if (discardSavedSession) await store.clear();
      // Legacy credentials are removed, NEVER imported/replayed under a new key.
      // This removes only the configured project's known SDK session slots.
      await purgeLegacy();
      if (value != null) {
        _accepted = StoredSessionIdentity.parse(value, issuer: issuer);
        _cached = value;
      }
      _ready = true;
    } on Object {
      _fault();
      throw const SessionStorageFailure();
    }
  });

  Future<String?> read() async {
    if (!_ready || _failed) throw const SessionStorageFailure();
    return _cached;
  }

  /// Ordinary SDK events may rotate only the explicitly accepted SAME session.
  /// Delayed login/anonymous events can never create a persistent login here.
  Future<void> persistRefresh(String value) {
    final revision = _generation;
    return _serial(() async {
      if (!_ready || _failed || _accepted == null || revision != _generation)
        return;
      try {
        final next = StoredSessionIdentity.parse(value, issuer: issuer);
        if (next.key != _accepted!.key ||
            next.provider != _accepted!.provider ||
            next.issuedAt < _accepted!.issuedAt)
          return;
        await store.write(value);
        if (revision != _generation)
          return; // A queued clear follows any in-flight write.
        if (await store.read() != value) throw const SessionStorageFailure();
        if (revision != _generation) return;
        _cached = value;
        _accepted = next;
      } on Object {
        // The SDK invokes persistence through an async listener. Quarantine
        // synchronously rather than throwing a secret-bearing unhandled error.
        _fault();
      }
    });
  }

  /// Invalidates trust synchronously, before awaiting filesystem or platform I/O.
  Future<void> lockAndClear() {
    _generation++;
    _cached = null;
    _accepted = null;
    onStateChanged?.call();
    return _serial(() async {
      try {
        await store.clear();
        await purgeLegacy();
      } on Object {
        _fault();
        throw const SessionStorageFailure();
      }
    });
  }

  /// Called only after a matching server-issued session has been restored by
  /// Auth and the corresponding login-attempt ticket is still current.
  Future<void> acceptVerified(
    String value, {
    required int expectedGeneration,
  }) => _serial(() async {
    if (!_ready || _failed || expectedGeneration != _generation)
      throw const SessionStorageFailure();
    try {
      final next = StoredSessionIdentity.parse(value, issuer: issuer);
      await store.write(value);
      if (expectedGeneration != _generation)
        throw const SessionStorageFailure();
      if (await store.read() != value) throw const SessionStorageFailure();
      if (expectedGeneration != _generation)
        throw const SessionStorageFailure();
      _cached = value;
      _accepted = next;
      onStateChanged?.call();
    } on Object {
      // A concurrent exit already queued removal. The durable exit marker stays
      // set until AccountContext completes its final, generation-checked commit.
      if (expectedGeneration == _generation) _fault();
      throw const SessionStorageFailure();
    }
  });

  /// Explicit recovery only. The UI requires confirmation, then app restart.
  /// It does not reset wallet/chat operations, biometric data or server records.
  Future<void> resetSavedLogin() {
    _generation++;
    _cached = null;
    _accepted = null;
    _failed = true;
    onStateChanged?.call();
    return _serial(() async {
      await store.reset();
      await purgeLegacy();
      if (await store.read() != null) throw const SessionStorageFailure();
    });
  }
}

/// Web and unsupported desktop targets intentionally persist nothing to disk.
/// A page/process restart requires login; this is not an HttpOnly-cookie scheme.
class MemorySessionValueStore implements SessionValueStore {
  String? _value;
  @override
  Future<String?> read() async => _value;
  @override
  Future<void> write(String value) async {
    _value = value;
  }

  @override
  Future<void> clear() async {
    _value = null;
  }

  @override
  Future<void> reset() => clear();
}
