import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:mobi_app/features/biopay/models/biopay_models.dart';

/// On-device face detection using Google ML Kit.
class FaceDetectionService {
  FaceDetector? _detector;

  /// Quality thresholds.
  static const double minFaceWidthRatio =
      0.25; // Face must be ≥25% of frame width
  static const double maxYawAngle = 20.0; // degrees
  static const double minEyeOpenProbability = 0.5;
  static const double minBrightness = 0.23;
  static const double maxBrightness = 0.88;

  void initialize({FaceDetectorMode mode = FaceDetectorMode.accurate}) {
    if (_detector != null) return;
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableContours: false,
        enableTracking: true,
        performanceMode: mode,
        minFaceSize: 0.15,
      ),
    );
  }

  Future<List<Face>> detectFaces(
    CameraImage image,
    CameraDescription camera,
  ) async {
    if (_detector == null) {
      throw StateError('FaceDetectionService not initialized');
    }

    final inputImage = _convertCameraImage(image, camera);
    if (inputImage == null) return [];

    return _detector!.processImage(inputImage);
  }

  Future<List<Face>> detectFacesFromFilePath(String imagePath) async {
    if (_detector == null) {
      throw StateError('FaceDetectionService not initialized');
    }

    final inputImage = InputImage.fromFilePath(imagePath);
    return _detector!.processImage(inputImage);
  }

  double estimateBrightness(
    Object image, {
    int? imageWidth,
    int? imageHeight,
    ui.Rect? region,
    int sampleStride = 8,
  }) {
    if (image is CameraImage) {
      return _estimateCameraBrightness(image, sampleStride: sampleStride);
    }

    if (image is List && image.isEmpty) {
      return 0;
    }

    if (image is List<int>) {
      return _estimateRgbaBrightness(
        image,
        imageWidth: imageWidth ?? 0,
        imageHeight: imageHeight ?? 0,
        region: region,
        sampleStride: sampleStride,
      );
    }

    throw ArgumentError.value(
      image,
      'image',
      'Expected CameraImage or RGBA bytes.',
    );
  }

  double _estimateCameraBrightness(CameraImage image, {int sampleStride = 8}) {
    final yPlane = image.planes.first.bytes;
    double brightnessSum = 0;
    int count = 0;
    for (int i = 0; i < yPlane.length; i += sampleStride) {
      brightnessSum += yPlane[i];
      count++;
    }
    return count > 0 ? (brightnessSum / count) / 255.0 : 0.5;
  }

  double _estimateRgbaBrightness(
    List<int> rgba, {
    required int imageWidth,
    required int imageHeight,
    ui.Rect? region,
    int sampleStride = 8,
  }) {
    if (rgba.isEmpty || imageWidth <= 0 || imageHeight <= 0) {
      return 0;
    }

    final bounds =
        region ??
        ui.Rect.fromLTWH(0, 0, imageWidth.toDouble(), imageHeight.toDouble());
    final left = bounds.left.clamp(0, imageWidth).floor();
    final top = bounds.top.clamp(0, imageHeight).floor();
    final right = bounds.right.clamp(0, imageWidth).ceil();
    final bottom = bounds.bottom.clamp(0, imageHeight).ceil();
    final stride = sampleStride <= 0 ? 1 : sampleStride;

    double brightnessSum = 0;
    int count = 0;
    for (var y = top; y < bottom; y += stride) {
      for (var x = left; x < right; x += stride) {
        final offset = (y * imageWidth + x) * 4;
        if (offset + 2 >= rgba.length) {
          continue;
        }
        final r = rgba[offset];
        final g = rgba[offset + 1];
        final b = rgba[offset + 2];
        brightnessSum += (0.299 * r) + (0.587 * g) + (0.114 * b);
        count++;
      }
    }

    return count == 0 ? 0 : (brightnessSum / count) / 255.0;
  }

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

    // Yaw check
    final yaw = face.headEulerAngleY ?? 0;
    if (yaw.abs() > maxYawAngle) {
      issues.add(FaceQualityIssue.yawTooHigh);
    }

    // Eye-open check
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

  Future<void> dispose() async {
    await _detector?.close();
    _detector = null;
  }
}

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
