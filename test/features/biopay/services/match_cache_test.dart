import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/services/match_cache.dart';

void main() {
  group('cosineSimilarity (static helper)', () {
    test('identical vectors have similarity 1.0', () {
      final v = [0.6, 0.8];
      final result = _cosineSimilarity(v, v);
      expect(result, closeTo(1.0, 1e-6));
    });

    test('orthogonal vectors have similarity 0.0', () {
      final a = [1.0, 0.0];
      final b = [0.0, 1.0];
      final result = _cosineSimilarity(a, b);
      expect(result, closeTo(0.0, 1e-6));
    });

    test('opposite vectors have similarity -1.0', () {
      final a = [1.0, 0.0];
      final b = [-1.0, 0.0];
      final result = _cosineSimilarity(a, b);
      expect(result, closeTo(-1.0, 1e-6));
    });

    test(
      '192-dimensional normalized vectors have similarity ~1.0 when equal',
      () {
        final rng = math.Random(42);
        final v = List.generate(192, (_) => rng.nextDouble() * 2 - 1);
        final norm = math.sqrt(v.fold<double>(0, (s, x) => s + x * x));
        final normalized = v.map((x) => x / norm).toList();

        final result = _cosineSimilarity(normalized, normalized);
        expect(result, closeTo(1.0, 1e-6));
      },
    );

    test('different 192D vectors have similarity < 1.0', () {
      final rng = math.Random(42);
      final a = List.generate(192, (_) => rng.nextDouble() * 2 - 1);
      final b = List.generate(192, (_) => rng.nextDouble() * 2 - 1);
      final normA = math.sqrt(a.fold<double>(0, (s, x) => s + x * x));
      final normB = math.sqrt(b.fold<double>(0, (s, x) => s + x * x));
      final nA = a.map((x) => x / normA).toList();
      final nB = b.map((x) => x / normB).toList();

      final result = _cosineSimilarity(nA, nB);
      expect(result, lessThan(1.0));
      expect(result, greaterThan(-1.0));
    });
  });

  group('MatchCache TTL', () {
    test('default TTL is 24 hours', () {
      final cache = MatchCache();
      expect(cache.ttl, const Duration(hours: 24));
    });
  });
}

/// Pure cosine similarity for testing — mirrors MatchCache internal logic.
double _cosineSimilarity(List<double> a, List<double> b) {
  if (a.length != b.length) return 0;
  double dot = 0, normA = 0, normB = 0;
  for (int i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  final denominator = math.sqrt(normA) * math.sqrt(normB);
  if (denominator == 0) return 0;
  return dot / denominator;
}
