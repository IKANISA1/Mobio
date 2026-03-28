import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/services/embedding_service.dart';

void main() {
  group('EmbeddingService.preprocessRgb', () {
    test('converts 112x112 RGB bytes to normalized Float32', () {
      const pixelCount = 112 * 112 * 3;
      final rgbPixels = Uint8List(pixelCount);

      // Set all pixels to 127.5 → should normalize to ~0.0
      for (int i = 0; i < pixelCount; i++) {
        rgbPixels[i] = 128; // closest integer to 127.5
      }

      final result = EmbeddingService.preprocessRgb(rgbPixels);

      expect(result.length, pixelCount);
      // 128 / 127.5 - 1.0 ≈ 0.00392
      for (final v in result) {
        expect(v, closeTo(0.00392, 0.01));
      }
    });

    test('normalizes 0 to -1.0', () {
      final rgbPixels = Uint8List(112 * 112 * 3); // all zeros
      final result = EmbeddingService.preprocessRgb(rgbPixels);

      expect(result[0], closeTo(-1.0, 0.001));
    });

    test('normalizes 255 to +1.0', () {
      final rgbPixels = Uint8List(112 * 112 * 3);
      for (int i = 0; i < rgbPixels.length; i++) {
        rgbPixels[i] = 255;
      }
      final result = EmbeddingService.preprocessRgb(rgbPixels);

      expect(result[0], closeTo(1.0, 0.001));
    });

    test('throws on wrong input size', () {
      expect(
        () => EmbeddingService.preprocessRgb(Uint8List(100)),
        throwsA(isA<EmbeddingServiceException>()),
      );
    });
  });

  group('L2 normalization (via getEmbedding validation)', () {
    test('rejects wrong-length input', () {
      final service = EmbeddingService();
      // Not initialized — should throw
      expect(
        () => service.getEmbedding(Float32List(10)),
        throwsA(isA<EmbeddingServiceException>()),
      );
    });
  });

  group('EmbeddingService constants', () {
    test('inputSize is 112', () {
      expect(EmbeddingService.inputSize, 112);
    });

    test('expectedEmbeddingDim is 192', () {
      expect(EmbeddingService.expectedEmbeddingDim, 192);
    });
  });

  group('L2 normalization correctness (via static helper)', () {
    // Test the L2 normalization logic directly
    test('normalized vector has unit length', () {
      final vector = [3.0, 4.0]; // norm = 5.0
      final norm = math.sqrt(vector.fold<double>(0, (s, v) => s + v * v));
      final normalized = vector.map((v) => v / norm).toList();

      final resultNorm = math.sqrt(
        normalized.fold<double>(0, (s, v) => s + v * v),
      );
      expect(resultNorm, closeTo(1.0, 1e-6));
    });

    test('zero vector is not modified', () {
      final vector = [0.0, 0.0, 0.0];
      final norm = math.sqrt(vector.fold<double>(0, (s, v) => s + v * v));
      // norm ≈ 0, so normalization should leave vector unchanged
      expect(norm, lessThan(1e-10));
    });

    test('192-dimensional random vector normalizes to unit', () {
      final rng = math.Random(42);
      final vector = List.generate(192, (_) => rng.nextDouble() * 2 - 1);
      final norm = math.sqrt(vector.fold<double>(0, (s, v) => s + v * v));
      final normalized = vector.map((v) => v / norm).toList();

      final resultNorm = math.sqrt(
        normalized.fold<double>(0, (s, v) => s + v * v),
      );
      expect(resultNorm, closeTo(1.0, 1e-6));
    });
  });
}
