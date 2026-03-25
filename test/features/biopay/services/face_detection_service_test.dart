import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/services/face_detection_service.dart';

/// Minimal mock of google_mlkit_face_detection's Face for testing quality checks.
/// We use the real FaceDetectionService.checkQuality and estimateBrightness
/// which don't require ML Kit internals — just a Face-shaped object.
///
/// Since checkQuality takes a Face object from ML Kit, we test the
/// threshold constants and brightness estimation which don't need ML Kit.
void main() {
  late FaceDetectionService service;

  setUp(() {
    service = FaceDetectionService();
  });

  group('FaceDetectionService constants', () {
    test('minFaceWidthRatio is 0.25', () {
      expect(FaceDetectionService.minFaceWidthRatio, 0.25);
    });

    test('maxYawAngle is 20.0', () {
      expect(FaceDetectionService.maxYawAngle, 20.0);
    });

    test('minEyeOpenProbability is 0.5', () {
      expect(FaceDetectionService.minEyeOpenProbability, 0.5);
    });

    test('minBrightness is 0.23', () {
      expect(FaceDetectionService.minBrightness, 0.23);
    });

    test('maxBrightness is 0.88', () {
      expect(FaceDetectionService.maxBrightness, 0.88);
    });
  });

  group('estimateBrightness', () {
    test('all-black pixels return 0.0', () {
      final width = 4;
      final height = 4;
      final rgba = List<int>.filled(width * height * 4, 0);
      final result = service.estimateBrightness(
        rgba,
        imageWidth: width,
        imageHeight: height,
        sampleStride: 1,
      );
      expect(result, closeTo(0.0, 0.01));
    });

    test('all-white pixels return ~1.0', () {
      final width = 4;
      final height = 4;
      // RGBA where RGB are all 255
      final rgba = <int>[];
      for (int i = 0; i < width * height; i++) {
        rgba.addAll([255, 255, 255, 255]);
      }
      final result = service.estimateBrightness(
        rgba,
        imageWidth: width,
        imageHeight: height,
        sampleStride: 1,
      );
      expect(result, closeTo(1.0, 0.01));
    });

    test('mid-gray pixels return ~0.5', () {
      final width = 4;
      final height = 4;
      final rgba = <int>[];
      for (int i = 0; i < width * height; i++) {
        rgba.addAll([128, 128, 128, 255]);
      }
      final result = service.estimateBrightness(
        rgba,
        imageWidth: width,
        imageHeight: height,
        sampleStride: 1,
      );
      // (0.299*128 + 0.587*128 + 0.114*128) / 255.0 ≈ 0.502
      expect(result, closeTo(0.502, 0.01));
    });

    test('empty pixels return 0', () {
      final result = service.estimateBrightness(
        [],
        imageWidth: 0,
        imageHeight: 0,
      );
      expect(result, 0.0);
    });

    test('sub-region brightness estimation', () {
      final width = 8;
      final height = 8;
      // All black except a 4x4 white region in center
      final rgba = List<int>.filled(width * height * 4, 0);
      for (int y = 2; y < 6; y++) {
        for (int x = 2; x < 6; x++) {
          final offset = (y * width + x) * 4;
          rgba[offset] = 255;     // R
          rgba[offset + 1] = 255; // G
          rgba[offset + 2] = 255; // B
          rgba[offset + 3] = 255; // A
        }
      }

      // Full frame brightness should be ~0.25 (quarter is white)
      final fullBrightness = service.estimateBrightness(
        rgba,
        imageWidth: width,
        imageHeight: height,
        sampleStride: 1,
      );
      expect(fullBrightness, closeTo(0.25, 0.05));

      // White region only should be ~1.0
      final regionBrightness = service.estimateBrightness(
        rgba,
        imageWidth: width,
        imageHeight: height,
        region: const ui.Rect.fromLTWH(2, 2, 4, 4),
        sampleStride: 1,
      );
      expect(regionBrightness, closeTo(1.0, 0.01));
    });
  });
}
