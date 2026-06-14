import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/features/biopay/biopay_flow_shared.dart';

class BioPayFaceEnrollScreen extends ConsumerStatefulWidget {
  const BioPayFaceEnrollScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<BioPayFaceEnrollScreen> createState() =>
      _BioPayFaceEnrollScreenState();
}

class _BioPayFaceEnrollScreenState
    extends ConsumerState<BioPayFaceEnrollScreen> {
  static const _enrollmentChallenges = <_FaceEnrollmentChallenge>[
    _FaceEnrollmentChallenge(
      id: 'straight_1',
      title: 'Center',
      body: 'Place your face in the oval.',
      action: 'Capture center',
    ),
    _FaceEnrollmentChallenge(
      id: 'turn_pose',
      title: 'Turn',
      body: 'Turn your head slightly, then hold.',
      action: 'Capture turn',
    ),
    _FaceEnrollmentChallenge(
      id: 'straight_2',
      title: 'Hold',
      body: 'Face forward again.',
      action: 'Finish enrollment',
    ),
  ];

  CameraController? _camera;
  final List<List<int>> _capturedFrames = [];
  String? _sessionId;
  String? _error;
  int _captureStepIndex = 0;
  bool _busy = false;
  bool _enrolled = false;

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
      _captureStepIndex = 0;
      _capturedFrames.clear();
      _enrolled = false;
    });
    try {
      final faceService = ref.read(biopayFaceServiceProvider);
      final result = await faceService.createLivenessSession();
      await _ensureCamera();
      if (!mounted) return;
      setState(() {
        _sessionId = result.sessionId;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyCameraMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _captureEnroll() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await camera.takePicture();
      final imageBytes = await file.readAsBytes();
      _capturedFrames.add(imageBytes);
      if (_captureStepIndex < _enrollmentChallenges.length - 1) {
        if (!mounted) return;
        setState(() => _captureStepIndex += 1);
        return;
      }
      final result = await ref
          .read(biopayFaceServiceProvider)
          .enrollFace(
            faceProfileId:
                'mobio-face-${DateTime.now().microsecondsSinceEpoch}',
            imageBytes: _capturedFrames.last,
            challengeIds: _enrollmentChallenges
                .map((challenge) => challenge.id)
                .toList(growable: false),
            sampleCount: _capturedFrames.length,
            livenessSessionId: _sessionId,
          );
      if (!mounted) return;
      setState(() {
        _enrolled = result.status == 'enrolled';
        if (!_enrolled) {
          _capturedFrames.clear();
          _captureStepIndex = 0;
        }
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Face enrollment was not accepted.';
        _capturedFrames.clear();
        _captureStepIndex = 0;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ensureCamera() async {
    if (_camera?.value.isInitialized == true) return;
    final cameras = await availableCameras().timeout(
      const Duration(seconds: 8),
    );
    if (cameras.isEmpty) {
      throw StateError('No camera is available on this device.');
    }
    CameraDescription? front;
    for (final camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        front = camera;
        break;
      }
    }
    final controller = CameraController(
      front ?? cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize().timeout(const Duration(seconds: 8));
    _camera = controller;
  }

  String _friendlyCameraMessage(Object error) {
    if (error is CameraException) {
      final code = error.code.toLowerCase();
      if (code.contains('access') || code.contains('permission')) {
        return 'Camera permission is required to enroll your face.';
      }
      if (code.contains('inuse') || code.contains('in_use')) {
        return 'Camera is in use by another app. Close it and try again.';
      }
    }
    if (error is StateError && error.message.contains('No camera')) {
      return 'No camera is available on this device.';
    }
    if (error is TimeoutException) {
      return 'Camera is still opening. Hold steady or retry.';
    }
    return 'Face provider or camera unavailable.';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final readyForCapture = _camera?.value.isInitialized == true;
    final currentChallenge = _enrollmentChallenges[_captureStepIndex];
    final capturedCount = _enrolled
        ? _enrollmentChallenges.length
        : _capturedFrames.length;
    final primaryLabel = readyForCapture
        ? currentChallenge.action
        : 'Start Enrollment';

    return BioPayFlowScreen(
      title: 'Face enroll',
      primaryLabel: primaryLabel,
      isPrimaryLoading: _busy,
      onBack: widget.onBack,
      onPrimary: _enrolled ? null : (readyForCapture ? _captureEnroll : _start),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BioPayFaceEnrollmentStatusPanel(
            title: _enrolled ? 'Saved' : currentChallenge.title,
            body: _enrolled
                ? 'AWS face identity ready.'
                : currentChallenge.body,
            capturedCount: capturedCount,
            totalSteps: _enrollmentChallenges.length,
            sessionReady: _sessionId != null,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (readyForCapture)
            BioPayCameraFrame(
              controller: _camera!,
              capturedCount: capturedCount,
              totalSteps: _enrollmentChallenges.length,
              currentStepId: currentChallenge.id,
              showFaceGuide: true,
            )
          else
            BioPayFaceEnrollmentStandby(iconColor: cs.primary),
          const SizedBox(height: AppSpacing.lg),
          BioPayPoseCueStrip(
            capturedCount: capturedCount,
            totalSteps: _enrollmentChallenges.length,
            currentStepId: currentChallenge.id,
            hasError: _error != null,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            BioPayInlineError(message: _error!),
          ],
        ],
      ),
    );
  }
}

class _FaceEnrollmentChallenge {
  const _FaceEnrollmentChallenge({
    required this.id,
    required this.title,
    required this.body,
    required this.action,
  });

  final String id;
  final String title;
  final String body;
  final String action;
}
