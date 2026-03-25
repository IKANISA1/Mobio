import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// On-device face detection using Google ML Kit.
///
/// Provides face detection with landmark extraction for alignment,
/// quality checks (yaw, face size, multi-face rejection, lighting),
/// and optional eye-open classification.
class FaceDetectionService {
  FaceDetector? _detector;

  /// Quality thresholds.
  static const double minFaceWidthRatio =
      0.25; // Face must be ≥25% of frame width
  static const double maxYawAngle = 20.0; // degrees
  static const double minEyeOpenProbability = 0.5;
  static const double minBrightness = 0.23;
  static const double maxBrightness = 0.88;

  /// Initialize the ML Kit face detector with classification enabled.
  ///
  /// Use [FaceDetectorMode.fast] for real-time scanning (lower latency),
  /// [FaceDetectorMode.accurate] for enrollment (higher precision).
  void initialize({
    FaceDetectorMode mode = FaceDetectorMode.fast,
  }) {
    if (_detector != null) return;
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true, // eye-open guidance
        enableLandmarks: true, // for affine alignment
        enableContours: false,
        enableTracking: true,
        performanceMode: mode,
        minFaceSize: 0.15,
      ),
    );
  }

  /// Detect faces in a camera image.
  ///
  /// Returns the list of detected faces. The caller should check
  /// quality constraints before proceeding.
  Future<List<Face>> detectFaces(
    CameraImage image,
    CameraDescription camera,
  ) async {
    if (_detector == null) {
      throw StateError('FaceDetectionService not initialized');
    }

    final inputImage = _convertCameraImage(image, camera);
    if (inputImage == null) return [];

    return await _detector!.processImage(inputImage);
  }

  /// Detect faces in an encoded image file written by the camera package.
  Future<List<Face>> detectFacesFromFilePath(String imagePath) async {
    if (_detector == null) {
      throw StateError('FaceDetectionService not initialized');
    }

    final inputImage = InputImage.fromFilePath(imagePath);
    return _detector!.processImage(inputImage);
  }

  /// Check quality of a detected face against BioPay requirements.
  FaceQualityResult checkQuality(
    Face face,
    ui.Size frameSize, {
    double? meanBrightness,
  }) {
    final issues = <FaceQualityIssue>[];

    // Face size check
    final faceWidthRatio = face.boundingBox.width / frameSize.width;
    if (faceWidthRatio < minFaceWidthRatio) {
      issues.add(FaceQualityIssue.faceTooSmall);
    }

    // Yaw check (looking straight ahead)
    final yaw = face.headEulerAngleY ?? 0;
    if (yaw.abs() > maxYawAngle) {
      issues.add(FaceQualityIssue.yawTooHigh);
    }

    // Eye-open check (if classification available)
    final leftEyeOpen = face.leftEyeOpenProbability;
    final rightEyeOpen = face.rightEyeOpenProbability;
    if (leftEyeOpen != null && rightEyeOpen != null) {
      if (leftEyeOpen < minEyeOpenProbability ||
          rightEyeOpen < minEyeOpenProbability) {
        issues.add(FaceQualityIssue.eyesClosed);
      }
    }

    if (meanBrightness != null) {
      if (meanBrightness < minBrightness) {
        issues.add(FaceQualityIssue.lowLighting);
      } else if (meanBrightness > maxBrightness) {
        issues.add(FaceQualityIssue.tooBright);
      }
    }

    return FaceQualityResult(
      isAcceptable: issues.isEmpty,
      issues: issues,
      faceWidthRatio: faceWidthRatio,
      yawAngle: yaw,
      meanBrightness: meanBrightness,
    );
  }

  /// Estimate brightness from RGBA pixels, optionally constrained to a face region.
  double estimateBrightness(
    List<int> rgbaPixels, {
    required int imageWidth,
    required int imageHeight,
    ui.Rect? region,
    int sampleStride = 4,
  }) {
    if (rgbaPixels.isEmpty || imageWidth <= 0 || imageHeight <= 0) {
      return 0;
    }

    final boundedRegion =
        (region ??
                ui.Rect.fromLTWH(
                  0,
                  0,
                  imageWidth.toDouble(),
                  imageHeight.toDouble(),
                ))
            .intersect(
              ui.Rect.fromLTWH(
                0,
                0,
                imageWidth.toDouble(),
                imageHeight.toDouble(),
              ),
            );
    if (boundedRegion.isEmpty) return 0;

    final left = boundedRegion.left.floor().clamp(0, imageWidth - 1);
    final top = boundedRegion.top.floor().clamp(0, imageHeight - 1);
    final right = boundedRegion.right.ceil().clamp(left + 1, imageWidth);
    final bottom = boundedRegion.bottom.ceil().clamp(top + 1, imageHeight);

    double total = 0;
    int count = 0;
    for (int y = top; y < bottom; y += sampleStride) {
      for (int x = left; x < right; x += sampleStride) {
        final pixelOffset = (y * imageWidth + x) * 4;
        if (pixelOffset + 2 >= rgbaPixels.length) continue;
        final red = rgbaPixels[pixelOffset];
        final green = rgbaPixels[pixelOffset + 1];
        final blue = rgbaPixels[pixelOffset + 2];
        total += (0.299 * red + 0.587 * green + 0.114 * blue) / 255.0;
        count++;
      }
    }

    if (count == 0) return 0;
    return total / count;
  }

  /// Convert CameraImage to ML Kit InputImage.
  InputImage? _convertCameraImage(CameraImage image, CameraDescription camera) {
    final rotation = _rotationFromCamera(camera);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (format == null) return null;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: ui.Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  InputImageRotation? _rotationFromCamera(CameraDescription camera) {
    final sensorOrientation = camera.sensorOrientation;
    return switch (sensorOrientation) {
      0 => InputImageRotation.rotation0deg,
      90 => InputImageRotation.rotation90deg,
      180 => InputImageRotation.rotation180deg,
      270 => InputImageRotation.rotation270deg,
      _ => null,
    };
  }

  /// Release ML Kit resources.
  Future<void> dispose() async {
    await _detector?.close();
    _detector = null;
  }
}

/// Quality check result for a detected face.
class FaceQualityResult {
  final bool isAcceptable;
  final List<FaceQualityIssue> issues;
  final double faceWidthRatio;
  final double yawAngle;
  final double? meanBrightness;

  const FaceQualityResult({
    required this.isAcceptable,
    required this.issues,
    required this.faceWidthRatio,
    required this.yawAngle,
    this.meanBrightness,
  });
}

/// Possible quality issues with a detected face.
enum FaceQualityIssue {
  faceTooSmall,
  yawTooHigh,
  eyesClosed,
  multipleFaces,
  lowLighting,
  tooBright,
}
