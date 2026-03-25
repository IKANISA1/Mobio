import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

class MatchCache {
  final Duration ttl;
  final int maxEntries;
  final double similarityThreshold;

  static const String _prefsKey = 'biopay_match_cache';

  final List<_CacheEntry> _entries = [];
  bool _loaded = false;

  MatchCache({
    this.ttl = const Duration(hours: 24),
    this.maxEntries = 50,
    this.similarityThreshold = 0.72,
  });

  Future<void> loadFromDisk() async {
    if (_loaded) return;
    _loaded = true;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;

    try {
      final list = jsonDecode(raw) as List;
      final now = DateTime.now();
      for (final item in list) {
        final entry = _CacheEntry.fromJson(item as Map<String, dynamic>);
        if (entry.expiresAt.isAfter(now)) {
          _entries.add(entry);
        }
      }
    } catch (_) {
      await prefs.remove(_prefsKey);
    }
  }

  Future<void> _saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    _pruneExpired();
    final jsonList = _entries.map((e) => e.toJson()).toList();
    await prefs.setString(_prefsKey, jsonEncode(jsonList));
  }

  CachedMatch? findMatch(List<double> embedding) {
    _pruneExpired();

    for (final entry in _entries) {
      final similarity = _cosineSimilarity(embedding, entry.embedding);
      if (similarity >= similarityThreshold) {
        return CachedMatch(
          biopayId: entry.biopayId,
          displayName: entry.displayName,
          ussdString: entry.ussdString,
          similarity: similarity,
        );
      }
    }

    return null;
  }

  Future<void> addMatch({
    required List<double> embedding,
    required String biopayId,
    required String displayName,
    required String ussdString,
  }) async {
    _pruneExpired();
    _entries.removeWhere((e) => e.biopayId == biopayId);

    while (_entries.length >= maxEntries) {
      _entries.removeAt(0);
    }

    _entries.add(
      _CacheEntry(
        embedding: List.unmodifiable(embedding),
        biopayId: biopayId,
        displayName: displayName,
        ussdString: ussdString,
        expiresAt: DateTime.now().add(ttl),
      ),
    );

    await _saveToDisk();
  }

  Future<void> removeBiopayId(String biopayId) async {
    _pruneExpired();
    final originalLength = _entries.length;
    _entries.removeWhere((entry) => entry.biopayId == biopayId);
    if (_entries.length != originalLength) {
      await _saveToDisk();
    }
  }

  Future<void> clear() async {
    _entries.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  int get size {
    _pruneExpired();
    return _entries.length;
  }

  void _pruneExpired() {
    final now = DateTime.now();
    _entries.removeWhere((e) => e.expiresAt.isBefore(now));
  }

  static double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0;

    double dotProduct = 0;
    double normA = 0;
    double normB = 0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    final denominator = math.sqrt(normA) * math.sqrt(normB);
    if (denominator < 1e-10) return 0;

    return dotProduct / denominator;
  }
}

class _CacheEntry {
  final List<double> embedding;
  final String biopayId;
  final String displayName;
  final String ussdString;
  final DateTime expiresAt;

  _CacheEntry({
    required this.embedding,
    required this.biopayId,
    required this.displayName,
    required this.ussdString,
    required this.expiresAt,
  });

  Map<String, dynamic> toJson() => {
    'embedding': embedding,
    'biopayId': biopayId,
    'displayName': displayName,
    'ussdString': ussdString,
    'expiresAt': expiresAt.toIso8601String(),
  };

  factory _CacheEntry.fromJson(Map<String, dynamic> json) => _CacheEntry(
    embedding: (json['embedding'] as List).cast<double>(),
    biopayId: json['biopayId'] as String,
    displayName: json['displayName'] as String,
    ussdString: json['ussdString'] as String,
    expiresAt: DateTime.parse(json['expiresAt'] as String),
  );
}

class CachedMatch {
  final String biopayId;
  final String displayName;
  final String ussdString;
  final double similarity;

  const CachedMatch({
    required this.biopayId,
    required this.displayName,
    required this.ussdString,
    required this.similarity,
  });
}
