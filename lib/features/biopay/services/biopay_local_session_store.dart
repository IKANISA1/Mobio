import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobi_app/features/biopay/models/biopay_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef BiopaySecureRead = Future<String?> Function(String key);
typedef BiopaySecureWrite = Future<bool> Function(String key, String value);
typedef BiopaySecureDelete = Future<void> Function(String key);

class BiopayLocalSessionStore {
  BiopayLocalSessionStore({
    BiopaySecureRead? secureRead,
    BiopaySecureWrite? secureWrite,
    BiopaySecureDelete? secureDelete,
    Future<SharedPreferences> Function()? prefsLoader,
  }) : _secureRead = secureRead ?? _defaultSecureRead,
       _secureWrite = secureWrite ?? _defaultSecureWrite,
       _secureDelete = secureDelete ?? _defaultSecureDelete,
       _prefsLoader = prefsLoader ?? SharedPreferences.getInstance;

  static const storageKey = 'mobi.biopay.local_session';
  static const _secureStorageTimeout = Duration(seconds: 1);
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final BiopaySecureRead _secureRead;
  final BiopaySecureWrite _secureWrite;
  final BiopaySecureDelete _secureDelete;
  final Future<SharedPreferences> Function() _prefsLoader;

  Future<BiopayLocalSession?> load() async {
    final secureRaw = await _secureRead(storageKey);
    if (secureRaw != null && secureRaw.isNotEmpty) {
      final parsed = _tryParse(secureRaw);
      if (parsed != null) return parsed;
      await clear();
      return null;
    }

    final prefs = await _prefsLoader();
    final legacyRaw = prefs.getString(storageKey);
    if (legacyRaw == null || legacyRaw.isEmpty) {
      return null;
    }

    final parsed = _tryParse(legacyRaw);
    if (parsed == null) {
      await clear();
      return null;
    }

    final migrated = await _secureWrite(storageKey, legacyRaw);
    if (migrated) {
      await prefs.remove(storageKey);
    }
    return parsed;
  }

  Future<void> save(BiopayLocalSession session) async {
    final raw = jsonEncode(session.toJson());
    final wroteToSecureStorage = await _secureWrite(storageKey, raw);
    final prefs = await _prefsLoader();
    if (wroteToSecureStorage) {
      await prefs.remove(storageKey);
    } else {
      await prefs.setString(storageKey, raw);
    }
  }

  Future<void> clear() async {
    await _secureDelete(storageKey);
    final prefs = await _prefsLoader();
    await prefs.remove(storageKey);
  }

  BiopayLocalSession? _tryParse(String raw) {
    try {
      return BiopayLocalSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on Object catch (_) {
      return null;
    }
  }

  static Future<String?> _defaultSecureRead(String key) async {
    try {
      return await _secureStorage.read(key: key).timeout(_secureStorageTimeout);
    } on Object catch (_) {
      return null;
    }
  }

  static Future<bool> _defaultSecureWrite(String key, String value) async {
    try {
      await _secureStorage
          .write(key: key, value: value)
          .timeout(_secureStorageTimeout);
      return true;
    } on Object catch (_) {
      return false;
    }
  }

  static Future<void> _defaultSecureDelete(String key) async {
    try {
      await _secureStorage.delete(key: key).timeout(_secureStorageTimeout);
    } on Object catch (_) {
      // Ignore secure storage cleanup failures in test environments.
    }
  }
}
