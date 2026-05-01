import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/features/biopay/biopay_strings.dart';
import 'package:mobi_app/features/biopay/models/biopay_handle.dart';
import 'package:mobi_app/features/biopay/models/biopay_models.dart';
import 'package:mobi_app/features/biopay/models/face_enrollment_state.dart';
import 'package:mobi_app/features/biopay/services/embedding_service.dart';
import 'package:mobi_app/features/biopay/services/enrollment_capture_session.dart';
import 'package:mobi_app/features/biopay/services/face_alignment_service.dart';
import 'package:mobi_app/features/biopay/services/face_detection_service.dart';
import 'package:mobi_app/features/biopay/services/stable_frame_gate.dart';

/// Provider for the enrollment arguments (isReEnrollment).
class FaceEnrollmentArgsNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool isReEnrollment) => state = isReEnrollment;
}

final faceEnrollmentArgsProvider =
    NotifierProvider<FaceEnrollmentArgsNotifier, bool>(
      FaceEnrollmentArgsNotifier.new,
    );

final faceEnrollmentProvider =
    AsyncNotifierProvider.autoDispose<
      FaceEnrollmentController,
      FaceEnrollmentState
    >(FaceEnrollmentController.new);

class FaceEnrollmentController extends AsyncNotifier<FaceEnrollmentState> {
  final _faceDetectionService = FaceDetectionService();
  final _embeddingService = EmbeddingService();
  final _session = EnrollmentCaptureSession(requiredSamples: 5);
  final _gate = StableFrameGate.enrollment();

  CameraController? _cameraController;
  CameraDescription? _selectedCamera;
  String? _handleValueForEnrollment;
  bool _isProcessingCapture = false;
  bool _hasSubmitted = false;

  CameraController? get cameraController => _cameraController;

  @override
  FutureOr<FaceEnrollmentState> build() async {
    final isReEnrollment = ref.watch(faceEnrollmentArgsProvider);

    ref.onDispose(() {
      _cameraController?.dispose();
      _embeddingService.dispose();
      _faceDetectionService.dispose();
    });

    return _bootstrap(isReEnrollment);
  }

  Future<FaceEnrollmentState> _bootstrap(bool isReEnrollment) async {
    final bioPayService = ref.read(bioPayServiceProvider);
    final profileService = ref.read(profileServiceProvider);
    final countryService = ref.read(countryServiceProvider);

    if (!isReEnrollment) {
      BiopayHandleType handleType = BiopayHandleType.number;

      try {
        await countryService.warmCache();
        final profile = await profileService.getMyProfile();
        if (profile != null) {
          handleType = BiopayHandleType.fromStorage(profile.biopayHandleType);
        }
      } on Object catch (error) {
        debugPrint('BioPay enrollment profile bootstrap fallback: $error');
      }

      return FaceEnrollmentState(
        phase: FaceEnrollPhase.ready,
        isReEnrollment: false,
        handleType: handleType,
        statusMessage: '',
      );
    }

    try {
      final profile = await bioPayService.getManagedProfile();
      if (profile == null) {
        return const FaceEnrollmentState(
          phase: FaceEnrollPhase.error,
          errorMessage: 'No linked profile found on this device.',
        );
      }

      return FaceEnrollmentState(
        phase: FaceEnrollPhase.ready,
        isReEnrollment: true,
        managedProfile: profile,
        statusMessage: '',
      );
    } on Object {
      return const FaceEnrollmentState(
        phase: FaceEnrollPhase.error,
        errorMessage: 'Unable to load profile. Please try again.',
      );
    }
  }

  void setHandleType(BiopayHandleType type) {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(currentState.copyWith(handleType: type));
  }

  Future<void> startCaptureFlow({String? handleValue}) async {
    final currentState = state.value;
    if (currentState == null) return;
    _handleValueForEnrollment = handleValue?.trim();

    state = AsyncValue.data(
      currentState.copyWith(
        phase: FaceEnrollPhase.loading,
        statusMessage: 'Starting camera...',
        errorMessage: null,
      ),
    );

    try {
      _faceDetectionService.initialize(mode: FaceDetectorMode.accurate);
      await _embeddingService.initialize();

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No camera is available on this device.');
      }

      final selectedCamera =
          cameras
              .where(
                (camera) => camera.lensDirection == CameraLensDirection.front,
              )
              .firstOrNull ??
          cameras.first;

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();

      _cameraController = controller;
      _selectedCamera = selectedCamera;
      _session.reset();
      _gate.reset();
      _hasSubmitted = false;
      _isProcessingCapture = false;

      final updatedState = state.value;
      if (updatedState != null) {
        state = AsyncValue.data(
          updatedState.copyWith(
            phase: FaceEnrollPhase.capturing,
            scannerState: ScannerState.searching,
            statusMessage: 'Hold still',
          ),
        );
      }

      await controller.startImageStream(_onCameraFrame);
    } on Object {
      final updatedState = state.value;
      if (updatedState != null) {
        state = AsyncValue.data(
          updatedState.copyWith(
            phase: FaceEnrollPhase.error,
            scannerState: ScannerState.error,
            errorMessage: 'Camera setup failed. Please try again.',
          ),
        );
      }
    }
  }

  void _onCameraFrame(CameraImage image) {
    final currentState = state.value;
    if (currentState == null ||
        _isProcessingCapture ||
        _hasSubmitted ||
        currentState.phase != FaceEnrollPhase.capturing) {
      return;
    }
    _isProcessingCapture = true;
    _processLiveFrame(image).whenComplete(() {
      _isProcessingCapture = false;
    });
  }

  Future<void> _processLiveFrame(CameraImage image) async {
    final camera = _selectedCamera;
    if (camera == null) return;

    try {
      final faces = await _faceDetectionService.detectFaces(image, camera);
      final currentState = state.value;
      if (currentState == null) return;

      if (faces.isEmpty) {
        _gate.reset();
        state = AsyncValue.data(
          currentState.copyWith(
            scannerState: ScannerState.searching,
            statusMessage: 'Center your face in the oval',
            activeQualityIssue: null,
            stabilityProgress: 0.0,
          ),
        );
        return;
      }

      if (faces.length > 1) {
        _gate.reset();
        state = AsyncValue.data(
          currentState.copyWith(
            scannerState: ScannerState.error,
            statusMessage: BiopayStrings.qualityMultipleFaces,
            activeQualityIssue: FaceQualityIssue.multipleFaces,
            stabilityProgress: 0.0,
          ),
        );
        return;
      }

      final face = faces.first;
      final frameWidth = image.width.toDouble();
      final frameHeight = image.height.toDouble();

      // Estimate brightness from Y (luminance) plane
      final yPlane = image.planes.first.bytes;
      double brightnessSum = 0;
      const sampleStride = 8;
      int count = 0;
      for (int i = 0; i < yPlane.length; i += sampleStride) {
        brightnessSum += yPlane[i];
        count++;
      }
      final meanBrightness = count > 0 ? (brightnessSum / count) / 255.0 : 0.5;

      final quality = _faceDetectionService.checkQuality(
        face,
        ui.Size(frameWidth, frameHeight),
        meanBrightness: meanBrightness,
      );
      if (!quality.isAcceptable) {
        _gate.reset();
        state = AsyncValue.data(
          currentState.copyWith(
            scannerState: ScannerState.error,
            statusMessage: _messageForQualityIssue(quality.issues.first),
            activeQualityIssue: quality.issues.first,
            stabilityProgress: 0.0,
          ),
        );
        return;
      }

      final isStable = _gate.onFrame(
        isQualityAcceptable: true,
        trackingId: face.trackingId,
      );

      state = AsyncValue.data(
        currentState.copyWith(
          scannerState: ScannerState.locked,
          statusMessage: 'Hold still',
          activeQualityIssue: null,
          stabilityProgress: _gate.progress,
        ),
      );

      if (!isStable) return;

      // Quality passed + stable — stop stream, take a still for alignment
      await _cameraController?.stopImageStream();

      final controller = _cameraController;
      if (controller == null || !controller.value.isInitialized) return;
      final capture = await controller.takePicture();

      // Decode RGBA for alignment
      final decodedImage = await _decodeImage(capture.path);

      // Re-detect the face landmarks from the still capture for accurate alignment
      final stillFaces = await _faceDetectionService.detectFacesFromFilePath(
        capture.path,
      );
      final landmarkFace = stillFaces.isNotEmpty ? stillFaces.first : face;

      // Clean up the temporary capture file
      try {
        await File(capture.path).delete();
      } on Object catch (error) {
        debugPrint('Unable to delete temporary enrollment capture: $error');
      }

      final landmarks = FaceAlignmentService.extractLandmarks(landmarkFace);
      if (landmarks == null) {
        _gate.reset();
        final s = state.value;
        if (s != null) {
          state = AsyncValue.data(
            s.copyWith(
              scannerState: ScannerState.searching,
              statusMessage: 'Keep your face fully visible',
              activeQualityIssue: null,
            ),
          );
        }
        // Restart stream for next attempt
        if (_cameraController != null && !_hasSubmitted) {
          await _cameraController!.startImageStream(_onCameraFrame);
        }
        return;
      }

      final transform = await FaceAlignmentService.computeAffineTransform(
        landmarks,
      );
      final alignedFace = await FaceAlignmentService.applyTransform(
        pixelData: decodedImage.rgbaPixels,
        transform: transform,
        srcWidth: decodedImage.width,
        srcHeight: decodedImage.height,
      );
      final embedding = _embeddingService.getEmbedding(alignedFace);

      final sizeScore = ((quality.faceWidthRatio - 0.25) / 0.35).clamp(
        0.0,
        1.0,
      );
      final yawScore = (1 - (quality.yawAngle.abs() / 20)).clamp(0.0, 1.0);
      final qualityScore = (sizeScore * 0.5) + (yawScore * 0.5);

      _session.addSample(embedding, qualityScore: qualityScore);

      if (_session.isComplete) {
        _hasSubmitted = true;
        final s = state.value;
        if (s != null) {
          state = AsyncValue.data(
            s.copyWith(
              scannerState: ScannerState.captured,
              statusMessage: 'Finalizing...',
              activeQualityIssue: null,
              sampleCount: _session.sampleCount,
            ),
          );
        }
        await submitEnrollment();
        return;
      }

      final s = state.value;
      if (s != null) {
        state = AsyncValue.data(
          s.copyWith(
            scannerState: ScannerState.locked,
            statusMessage:
                '${_session.sampleCount} of ${_session.requiredSamples}',
            activeQualityIssue: null,
            sampleCount: _session.sampleCount,
          ),
        );
      }

      // Restart stream for next sample
      if (_cameraController != null && !_hasSubmitted) {
        await _cameraController!.startImageStream(_onCameraFrame);
      }
    } on Object {
      final s = state.value;
      if (s != null) {
        state = AsyncValue.data(
          s.copyWith(
            phase: FaceEnrollPhase.error,
            scannerState: ScannerState.error,
            errorMessage: 'Face capture failed. Please try again.',
          ),
        );
      }
    }
  }

  Future<void> submitEnrollment({String? handleValueOverride}) async {
    final s = state.value;
    if (s == null) return;

    final bioPayService = ref.read(bioPayServiceProvider);
    final countryService = ref.read(countryServiceProvider);

    state = AsyncValue.data(
      s.copyWith(
        phase: FaceEnrollPhase.submitting,
        statusMessage: 'Uploading face data...',
      ),
    );

    try {
      final aggregate = _session.buildAggregate();
      EnrollmentResult result;
      if (s.isReEnrollment) {
        result = await bioPayService.reEnrollFace(
          embedding: aggregate.embedding,
          qualityScore: aggregate.qualityScore,
        );
      } else {
        final value = handleValueOverride ?? _handleValueForEnrollment ?? '';
        final ussdString = await countryService.buildBiopayUssd(
          dialingCode: '+250',
          handleType: s.handleType,
          handleValue: value,
        );
        if (ussdString == null || ussdString.isEmpty) {
          throw StateError('Unable to create the MoMo payment string.');
        }

        result = await bioPayService.enrollFace(
          displayName: 'Mobio User',
          ussdString: ussdString,
          embedding: aggregate.embedding,
          qualityScore: aggregate.qualityScore,
        );
      }

      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(
          finalState.copyWith(phase: FaceEnrollPhase.success, result: result),
        );
      }
    } on Object catch (e) {
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(
          finalState.copyWith(
            phase: FaceEnrollPhase.error,
            errorMessage: e.toString(),
          ),
        );
      }
    }
  }

  Future<_DecodedImage> _decodeImage(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return _DecodedImage(
      width: image.width,
      height: image.height,
      rgbaPixels: byteData!.buffer.asUint8List(),
    );
  }

  String _messageForQualityIssue(FaceQualityIssue issue) {
    return switch (issue) {
      FaceQualityIssue.faceTooSmall => BiopayStrings.qualityTooFar,
      FaceQualityIssue.yawTooHigh => BiopayStrings.qualityBadAngle,
      FaceQualityIssue.eyesClosed => 'Please keep your eyes open',
      FaceQualityIssue.multipleFaces => BiopayStrings.qualityMultipleFaces,
      FaceQualityIssue.lowLighting => BiopayStrings.qualityTooDark,
      FaceQualityIssue.tooBright => BiopayStrings.qualityTooBright,
    };
  }

  void retry() {
    final s = state.value;
    if (s == null) return;

    if (_session.isComplete) {
      submitEnrollment();
    } else {
      startCaptureFlow();
    }
  }
}

class _DecodedImage {
  const _DecodedImage({
    required this.width,
    required this.height,
    required this.rgbaPixels,
  });

  final int width;
  final int height;
  final Uint8List rgbaPixels;
}
