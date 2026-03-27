import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Landmark-based affine alignment for face normalization.
///
/// Uses ML Kit face landmarks (left eye, right eye, nose base) to compute
/// an affine transform that normalizes the face to a canonical 112×112 position
/// suitable for MobileFaceNet input.
///
/// Runs the alignment computation in a Dart isolate to avoid blocking the UI.
class FaceAlignmentService {
  /// Canonical target landmarks for 112×112 face crop (MobileFaceNet input).
  /// These positions center the face with eyes at ~40% height.
  static const List<List<double>> _canonicalLandmarks = [
    [38.2946, 51.6963], // left eye
    [73.5318, 51.5014], // right eye
    [56.0252, 71.7366], // nose tip
  ];

  /// Extract the 3 key landmarks from an ML Kit face.
  static List<math.Point<double>>? extractLandmarks(Face face) {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
    final noseBase = face.landmarks[FaceLandmarkType.noseBase]?.position;

    if (leftEye == null || rightEye == null || noseBase == null) return null;

    return [
      math.Point(leftEye.x.toDouble(), leftEye.y.toDouble()),
      math.Point(rightEye.x.toDouble(), rightEye.y.toDouble()),
      math.Point(noseBase.x.toDouble(), noseBase.y.toDouble()),
    ];
  }

  /// Compute the 2×3 affine transformation matrix that maps
  /// source landmarks to canonical 112×112 positions.
  ///
  /// Runs in an isolate for non-blocking computation.
  static Future<Float64List> computeAffineTransform(
    List<math.Point<double>> sourceLandmarks,
  ) async {
    return Isolate.run(() => _computeAffine(sourceLandmarks));
  }

  /// Synchronous affine transform computation (runs in isolate).
  static Float64List _computeAffine(List<math.Point<double>> src) {
    final srcMatrix = [
      [src[0].x, src[0].y, 1.0],
      [src[1].x, src[1].y, 1.0],
      [src[2].x, src[2].y, 1.0],
    ];

    final dstX = [
      _canonicalLandmarks[0][0],
      _canonicalLandmarks[1][0],
      _canonicalLandmarks[2][0],
    ];

    final dstY = [
      _canonicalLandmarks[0][1],
      _canonicalLandmarks[1][1],
      _canonicalLandmarks[2][1],
    ];

    // Solve using Cramer's rule for 3×3
    final det = _determinant3(srcMatrix);
    if (det.abs() < 1e-10) {
      // Degenerate — return identity
      return Float64List.fromList([1, 0, 0, 0, 1, 0]);
    }

    final a = _solveColumn(srcMatrix, dstX, det);
    final b = _solveColumn(srcMatrix, dstY, det);

    // Affine matrix: [a0 a1 a2; b0 b1 b2]
    return Float64List.fromList([a[0], a[1], a[2], b[0], b[1], b[2]]);
  }

  static double _determinant3(List<List<double>> m) {
    return m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
        m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
        m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
  }

  static List<double> _solveColumn(
    List<List<double>> matrix,
    List<double> rhs,
    double det,
  ) {
    // Cramer's rule
    final results = List<double>.filled(3, 0);
    for (int col = 0; col < 3; col++) {
      final modified = List<List<double>>.generate(
        3,
        (i) =>
            List<double>.generate(3, (j) => j == col ? rhs[i] : matrix[i][j]),
      );
      results[col] = _determinant3(modified) / det;
    }
    return results;
  }

  /// Apply affine transform to pixel data and produce a 112×112 normalized face.
  ///
  /// [pixelData] is the RGBA pixel buffer of the source image.
  /// [transform] is the 2×3 affine matrix from [computeAffineTransform].
  /// [srcWidth] and [srcHeight] are the source image dimensions.
  ///
  /// Returns a 112×112×3 float array (RGB, normalized to [-1, 1]).
  static Future<Float32List> applyTransform({
    required Uint8List pixelData,
    required Float64List transform,
    required int srcWidth,
    required int srcHeight,
  }) async {
    return Isolate.run(
      () => _applyTransformSync(
        pixelData: pixelData,
        transform: transform,
        srcWidth: srcWidth,
        srcHeight: srcHeight,
      ),
    );
  }

  static Float32List _applyTransformSync({
    required Uint8List pixelData,
    required Float64List transform,
    required int srcWidth,
    required int srcHeight,
  }) {
    const int outSize = 112;
    final output = Float32List(outSize * outSize * 3);

    // Invert the affine transform to map from output to source
    final inv = _invertAffine(transform);

    for (int y = 0; y < outSize; y++) {
      for (int x = 0; x < outSize; x++) {
        // Map output (x, y) to source coordinates
        final srcX = inv[0] * x + inv[1] * y + inv[2];
        final srcY = inv[3] * x + inv[4] * y + inv[5];

        // Bilinear interpolation
        final ix = srcX.floor();
        final iy = srcY.floor();
        final fx = srcX - ix;
        final fy = srcY - iy;

        for (int c = 0; c < 3; c++) {
          double val = 0;
          for (int dy = 0; dy <= 1; dy++) {
            for (int dx = 0; dx <= 1; dx++) {
              final px = ix + dx;
              final py = iy + dy;
              if (px >= 0 && px < srcWidth && py >= 0 && py < srcHeight) {
                final pixelIdx = (py * srcWidth + px) * 4 + c;
                final weight =
                    (dx == 0 ? 1 - fx : fx) * (dy == 0 ? 1 - fy : fy);
                val += pixelData[pixelIdx] * weight;
              }
            }
          }
          // Normalize to [-1, 1]
          output[(y * outSize + x) * 3 + c] = (val / 127.5) - 1.0;
        }
      }
    }

    return output;
  }

  /// Invert a 2×3 affine matrix to get the reverse mapping.
  static Float64List _invertAffine(Float64List m) {
    // M = [a b tx; c d ty; 0 0 1]
    final a = m[0], b = m[1], tx = m[2];
    final c = m[3], d = m[4], ty = m[5];
    final det = a * d - b * c;

    if (det.abs() < 1e-10) {
      return Float64List.fromList([1, 0, 0, 0, 1, 0]);
    }

    final invDet = 1.0 / det;
    return Float64List.fromList([
      d * invDet,
      -b * invDet,
      (b * ty - d * tx) * invDet,
      -c * invDet,
      a * invDet,
      (c * tx - a * ty) * invDet,
    ]);
  }
}
