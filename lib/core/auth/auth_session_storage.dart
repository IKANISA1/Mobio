import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'session_persistence.dart';

class NativeSessionValueStore implements SessionValueStore {
  NativeSessionValueStore(
    this.namespace, {
    MethodChannel? channel,
    this.readTimeout = const Duration(seconds: 5),
  }) : _channel = channel ?? const MethodChannel('rw.mobi.app/secure_session');
  final String namespace;
  final MethodChannel _channel;
  final Duration readTimeout;
  @override
  Future<String?> read() => RequestDeadline.read(
    _channel.invokeMethod<String>('read', {'namespace': namespace}),
    timeout: readTimeout,
  );
  // Writes and clears remain on SessionPersistence's real-completion tail. A
  // timeout here could free that queue while an old native write still runs.
  Future<void> _mutate(String method, [String? value]) async {
    final result = await _channel.invokeMethod<bool>(method, {
      'namespace': namespace,
      if (value != null) 'value': value,
    });
    if (result != true) throw const SessionStorageFailure();
  }

  @override
  Future<void> write(String value) => _mutate('write', value);
  @override
  Future<void> clear() => _mutate('clear');
  @override
  Future<void> reset() => _mutate('reset');
}

/// Adapter for the existing locked supabase_flutter 2.12.0 LocalStorage API.
class AuthSessionStorage extends LocalStorage {
  AuthSessionStorage._(this.persistence);
  final SessionPersistence persistence;
  static AuthSessionStorage? _instance;
  static AuthSessionStorage get instance =>
      _instance ?? (throw const SessionStorageFailure());
  static bool get configured => _instance != null;

  static AuthSessionStorage configure(String url) {
    if (_instance != null) throw StateError('AUTH_STORAGE_ALREADY_CONFIGURED');
    final uri = Uri.parse(url);
    if (uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !const ['https', 'http'].contains(uri.scheme) ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        (uri.scheme == 'http' &&
            (!kDebugMode ||
                !const [
                  'localhost',
                  '127.0.0.1',
                  '::1',
                  '10.0.2.2',
                ].contains(uri.host))))
      throw const SessionStorageFailure();
    final origin = uri
        .replace(path: '')
        .toString()
        .replaceFirst(RegExp(r'/$'), '');
    final namespace = sha256.convert(utf8.encode(origin)).toString();
    final native =
        !kIsWeb &&
        const [
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform);
    final store = native
        ? NativeSessionValueStore(namespace)
        : MemorySessionValueStore();
    final legacyKey = 'sb-${uri.host.split('.').first}-auth-token';
    _instance = AuthSessionStorage._(
      SessionPersistence(
        store: store,
        issuer: '$origin/auth/v1',
        purgeLegacy: () async {
          final preferences = await SharedPreferences.getInstance();
          await preferences.reload();
          // Current SDK key plus historical SDK constant. No broad prefs.clear().
          for (final key in {legacyKey, supabasePersistSessionKey}) {
            if (preferences.containsKey(key) && !await preferences.remove(key))
              throw const SessionStorageFailure();
          }
          await preferences.reload();
          if ({
            legacyKey,
            supabasePersistSessionKey,
          }.any(preferences.containsKey))
            throw const SessionStorageFailure();
        },
      ),
    );
    return _instance!;
  }

  @override
  Future<void> initialize() => persistence.initialize();
  @override
  Future<String?> accessToken() => persistence.read();
  @override
  Future<bool> hasAccessToken() async => await persistence.read() != null;
  @override
  Future<void> persistSession(String persistSessionString) =>
      persistence.persistRefresh(persistSessionString);
  @override
  Future<void> removePersistedSession() => persistence.lockAndClear();
}
