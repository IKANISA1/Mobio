import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/features/biopay/biopay_strings.dart';
import 'package:mobi_app/features/biopay/models/biopay_models.dart';
import 'package:mobi_app/features/biopay/models/face_scan_state.dart';
import 'package:mobi_app/features/biopay/services/embedding_service.dart';
import 'package:mobi_app/features/biopay/services/face_alignment_service.dart';
import 'package:mobi_app/features/biopay/services/face_detection_service.dart';
import 'package:mobi_app/features/biopay/services/stable_frame_gate.dart';
import 'package:mobi_app/features/biopay/services/ussd_launcher_service.dart';

final faceScanProvider =
    AsyncNotifierProvider.autoDispose<FaceScanController, FaceScanState>(
      FaceScanController.new,
    );

class FaceScanController extends AsyncNotifier<FaceScanState> {
  final _faceDetectionService = FaceDetectionService();
  final _embeddingService = EmbeddingService();
  final _gate = StableFrameGate.scan();
  final _ussdLauncher = UssdLauncherService();

  CameraController? _cameraController;
  CameraDescription? _selectedCamera;
  bool _isProcessingFrame = false;

  CameraController? get cameraController => _cameraController;

  @override
  FutureOr<FaceScanState> build() async {
    ref.onDispose(() {
      _cameraController?.dispose();
      _embeddingService.dispose();
      _faceDetectionService.dispose();
    });

    return const FaceScanState(phase: FaceScanPhase.loading);
  }

  Future<void> initializeScanner() async {
    final currentState = state.value ?? const FaceScanState();
    state = AsyncValue.data(
      currentState.copyWith(
        phase: FaceScanPhase.loading,
        statusMessage: 'Preparing camera...',
        errorMessage: null,
        isCameraDenied: false,
      ),
    );

    try {
      _faceDetectionService.initialize();
      await _embeddingService.initialize();
      await ref.read(bioPayServiceProvider).warmMatchCache();

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No camera is available on this device.');
      }

      final selectedCamera =
          cameras
              .where(
                (camera) => camera.lensDirection == CameraLensDirection.back,
              )
              .firstOrNull ??
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
      _gate.reset();
      _isProcessingFrame = false;

      final updatedState = state.value ?? const FaceScanState();
      state = AsyncValue.data(
        updatedState.copyWith(
          phase: FaceScanPhase.scanning,
          statusMessage: BiopayStrings.scanSearching,
        ),
      );

      await controller.startImageStream(_onCameraFrame);
    } on Object catch (e) {
      final updatedState = state.value ?? const FaceScanState();
      state = AsyncValue.data(
        updatedState.copyWith(
          phase: FaceScanPhase.error,
          errorMessage: 'Unable to start BioPay scanner: $e',
        ),
      );
    }
  }

  void setCameraDenied() {
    final currentState = state.value ?? const FaceScanState();
    state = AsyncValue.data(
      currentState.copyWith(
        phase: FaceScanPhase.error,
        isCameraDenied: true,
        errorMessage: 'Camera access is required to scan faces.',
      ),
    );
  }

  void _onCameraFrame(CameraImage image) {
    final currentState = state.value;
    if (currentState == null ||
        _isProcessingFrame ||
        currentState.phase != FaceScanPhase.scanning) {
      return;
    }
    _isProcessingFrame = true;
    _processLiveFrame(image).whenComplete(() {
      _isProcessingFrame = false;
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
            statusMessage: BiopayStrings.scanSearching,
            stabilityProgress: 0.0,
            activeQualityIssue: null,
          ),
        );
        return;
      }

      if (faces.length > 1) {
        _gate.reset();
        state = AsyncValue.data(
          currentState.copyWith(
            statusMessage: BiopayStrings.qualityMultipleFaces,
            stabilityProgress: 0.0,
            activeQualityIssue: FaceQualityIssue.multipleFaces,
          ),
        );
        return;
      }

      final face = faces.first;
      final frameWidth = image.width.toDouble();
      final frameHeight = image.height.toDouble();

      // Estimate brightness
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
            statusMessage: _messageForQualityIssue(quality.issues.first),
            stabilityProgress: 0.0,
            activeQualityIssue: quality.issues.first,
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
          statusMessage: 'Scanning...',
          stabilityProgress: _gate.progress,
          activeQualityIssue: null,
        ),
      );

      if (!isStable) return;

      // Stable and high quality — trigger matching
      await _cameraController?.stopImageStream();

      final current = state.value;
      if (current != null) {
        state = AsyncValue.data(
          current.copyWith(
            phase: FaceScanPhase.processing,
            statusMessage: 'Analyzing...',
          ),
        );
      }

      final controller = _cameraController;
      if (controller == null) return;
      final capture = await controller.takePicture();

      // Decode for alignment
      final decodedImage = await _decodeImage(capture.path);

      // Re-detect landmarks on the high-res capture
      final stillFaces = await _faceDetectionService.detectFacesFromFilePath(
        capture.path,
      );
      final landmarkFace = stillFaces.isNotEmpty ? stillFaces.first : face;

      try {
        await File(capture.path).delete();
      } on Object catch (error) {
        debugPrint('Unable to delete temporary scan capture: $error');
      }

      final landmarks = FaceAlignmentService.extractLandmarks(landmarkFace);
      if (landmarks == null) {
        _gate.reset();
        final current = state.value;
        if (current != null) {
          state = AsyncValue.data(
            current.copyWith(
              phase: FaceScanPhase.scanning,
              statusMessage: 'Keep face fully visible',
            ),
          );
        }
        if (_cameraController != null) {
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
      final match = await ref
          .read(bioPayServiceProvider)
          .matchFace(embedding: embedding);

      final finalState = state.value;
      if (finalState != null) {
        if (match.success && match.match != null) {
          state = AsyncValue.data(
            finalState.copyWith(
              phase: FaceScanPhase.matched,
              matchResult: match,
            ),
          );
        } else {
          state = AsyncValue.data(
            finalState.copyWith(
              phase: FaceScanPhase.noMatch,
              matchResult: match,
            ),
          );
        }
      }
    } on Object catch (e) {
      final current = state.value;
      if (current != null) {
        state = AsyncValue.data(
          current.copyWith(
            phase: FaceScanPhase.error,
            errorMessage: 'Scan failed: $e',
          ),
        );
      }
    }
  }

  Future<void> launchPayment() async {
    final current = state.value;
    final match = current?.matchResult?.match;
    final ussdString = match?.ussdString;
    if (ussdString == null || ussdString.isEmpty) return;

    try {
      await _ussdLauncher.launchUssdPayment(ussdString);
    } on Object catch (e) {
      if (current != null) {
        state = AsyncValue.data(
          current.copyWith(errorMessage: 'Unable to launch payment: $e'),
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
      FaceQualityIssue.faceTooSmall => BiopayStrings.qualityFaceTooSmall,
      FaceQualityIssue.yawTooHigh => BiopayStrings.qualityYawTooHigh,
      FaceQualityIssue.eyesClosed => BiopayStrings.qualityEyesClosed,
      FaceQualityIssue.multipleFaces => BiopayStrings.qualityMultipleFaces,
      FaceQualityIssue.lowLighting => BiopayStrings.qualityLowLight,
      FaceQualityIssue.tooBright => BiopayStrings.qualityTooBright,
    };
  }

  void reset() {
    initializeScanner();
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
