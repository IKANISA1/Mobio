import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/router/app_router.dart';
import 'package:mobi_app/core/services/app_permission_service.dart';
import 'package:mobi_app/core/services/biopay_service.dart';
import 'package:mobi_app/core/services/country_service.dart';
import 'package:mobi_app/core/services/profile_service.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/features/biopay/biopay_strings.dart';
import 'package:mobi_app/features/biopay/models/biopay_handle.dart';
import 'package:mobi_app/features/biopay/models/biopay_models.dart';
import 'package:mobi_app/features/biopay/services/embedding_service.dart';
import 'package:mobi_app/features/biopay/services/enrollment_capture_session.dart';
import 'package:mobi_app/features/biopay/services/face_alignment_service.dart';
import 'package:mobi_app/features/biopay/services/face_detection_service.dart';
import 'package:mobi_app/features/biopay/services/stable_frame_gate.dart';
import 'package:mobi_app/features/biopay/widgets/biopay_consent_dialog.dart';
import 'package:mobi_app/features/biopay/widgets/oval_painter.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/permission_access_dialog.dart';
import 'package:mobi_app/shared/widgets/tappable_icon_button.dart';

class FaceEnrollmentScreen extends StatefulWidget {
  const FaceEnrollmentScreen({
    super.key,
    required this.onBack,
    this.isReEnrollment = false,
  });

  final VoidCallback onBack;
  final bool isReEnrollment;

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

enum _EnrollPhase { loading, ready, capturing, submitting, success, error }

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  final _momoValueController = TextEditingController();
  BiopayHandleType _handleType = BiopayHandleType.number;
  final _permissionService = AppPermissionService.instance;
  final _bioPayService = BioPayService();
  final _profileService = ProfileService();
  final _countryService = CountryService();
  final _faceDetectionService = FaceDetectionService();
  final _embeddingService = EmbeddingService();
  final _session = EnrollmentCaptureSession(requiredSamples: 5);
  final _gate = StableFrameGate.enrollment();

  CameraController? _cameraController;
  CameraDescription? _selectedCamera;
  ManagedBiopayProfile? _managedProfile;
  EnrollmentResult? _result;
  _EnrollPhase _phase = _EnrollPhase.loading;
  ScannerState _scannerState = ScannerState.searching;
  String _statusMessage = 'Preparing BioPay...';
  String? _errorMessage;
  bool _isProcessingCapture = false;
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _momoValueController.dispose();
    final controller = _cameraController;
    _cameraController = null;
    controller?.dispose();
    _embeddingService.dispose();
    _faceDetectionService.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _phase = _EnrollPhase.loading;
      _statusMessage = widget.isReEnrollment
          ? 'Loading BioPay profile...'
          : 'Preparing BioPay...';
      _errorMessage = null;
      _result = null;
    });

    if (!widget.isReEnrollment) {
      await _prefillRegistrationDetails();
      if (!mounted) return;
      setState(() => _phase = _EnrollPhase.ready);
      return;
    }

    try {
      final profile = await _bioPayService.getManagedProfile();
      if (!mounted) return;
      if (profile == null) {
        setState(() {
          _phase = _EnrollPhase.error;
          _errorMessage =
              'No linked BioPay profile is available for re-enrollment on this device.';
        });
        return;
      }

      _managedProfile = profile;
      setState(() => _phase = _EnrollPhase.ready);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _EnrollPhase.error;
        _errorMessage = 'Unable to load BioPay profile: $error';
      });
    }
  }

  Future<void> _prefillRegistrationDetails() async {
    try {
      await _countryService.warmCache();
      final profile = await _profileService.getMyProfile();
      if (profile == null) return;

      final handleType = BiopayHandleType.fromStorage(
        profile['biopay_handle_type'] as String?,
      );
      final handleValue = (profile['biopay_handle_value'] as String? ?? '')
          .trim();

      if (handleValue.isNotEmpty && _momoValueController.text.trim().isEmpty) {
        setState(() => _handleType = handleType);
        _momoValueController.text = handleValue;
      }
    } catch (_) {
      // Prefill is best-effort and should never block enrollment.
    }
  }

  /// Build the full USSD string from handle type + value using CountryService.
  Future<String?> _buildUssdFromHandle() async {
    final value = _momoValueController.text.trim();
    if (value.isEmpty) return null;
    // Default to Rwanda (+250) — the edge function normalizes the full string.
    return _countryService.buildBiopayUssd(
      dialingCode: '+250',
      handleType: _handleType,
      handleValue: value,
    );
  }

  /// Derive a display name for the BioPay backend (not shown to users).
  /// The API requires ≥2 chars; we use a generic anonymous identifier.
  String _deriveDisplayName() {
    return 'Mobio User';
  }

  Future<void> _openPrivacyCenter() {
    return context.push(AppRoutes.biopayPrivacy);
  }

  Future<void> _startCaptureFlow() async {
    // Client-side validation for new enrollments
    if (!widget.isReEnrollment) {
      final value = _momoValueController.text.trim();
      if (value.isEmpty) {
        _showSnackBar(
          _handleType == BiopayHandleType.number
              ? 'Enter your MoMo phone number.'
              : 'Enter your MoMo agent code.',
        );
        return;
      }
      if (_handleType == BiopayHandleType.number && value.length < 9) {
        _showSnackBar('Phone number must be at least 9 digits.');
        return;
      }
    }

    final consentAction = await BiopayConsentDialog.show(context);
    if (!mounted) return;
    if (consentAction == BiopayConsentDialogAction.viewPrivacyCenter) {
      await _openPrivacyCenter();
      return;
    }
    if (consentAction != BiopayConsentDialogAction.continueFlow) {
      return;
    }

    final action = await PermissionAccessDialog.show(
      context,
      config: PermissionAccessDialogConfig.biopayCamera(),
    );
    if (!mounted) return;
    if (action != PermissionAccessDialogAction.grantAccess) {
      _showSnackBar('Camera access is required for BioPay face capture.');
      return;
    }

    final hasAccess = await _permissionService.ensureBiopayCameraAccess();
    if (!mounted) return;
    if (!hasAccess) {
      setState(() {
        _phase = _EnrollPhase.error;
        _errorMessage = 'Camera access is required for BioPay face capture.';
      });
      return;
    }

    await _initializeCameraAndServices();
  }

  Future<void> _initializeCameraAndServices() async {
    setState(() {
      _phase = _EnrollPhase.loading;
      _statusMessage = 'Preparing camera...';
      _errorMessage = null;
      _scannerState = ScannerState.searching;
    });

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

      final previousController = _cameraController;
      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      await previousController?.dispose();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;
      _selectedCamera = selectedCamera;
      _session.reset();
      _gate.reset();
      _hasSubmitted = false;
      _isProcessingCapture = false;

      setState(() {
        _phase = _EnrollPhase.capturing;
        _scannerState = ScannerState.searching;
        _statusMessage = 'Hold still. We need 5 face samples.';
      });

      // Start live image stream instead of polling
      await controller.startImageStream(_onCameraFrame);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _EnrollPhase.error;
        _scannerState = ScannerState.error;
        _errorMessage = 'Camera setup failed: $error';
      });
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (_isProcessingCapture ||
        _hasSubmitted ||
        _phase != _EnrollPhase.capturing) {
      return;
    }
    _isProcessingCapture = true;
    _processLiveFrame(image).whenComplete(() {
      _isProcessingCapture = false;
    });
  }

  Future<void> _processLiveFrame(CameraImage image) async {
    final camera = _selectedCamera;
    if (camera == null || !mounted) return;

    try {
      final faces = await _faceDetectionService.detectFaces(image, camera);
      if (!mounted) return;

      if (faces.isEmpty) {
        _gate.reset();
        setState(() {
          _scannerState = ScannerState.searching;
          _statusMessage = 'No face found. Center your face in the frame.';
        });
        return;
      }

      if (faces.length > 1) {
        _gate.reset();
        setState(() {
          _scannerState = ScannerState.error;
          _statusMessage = BiopayStrings.qualityMultipleFaces;
        });
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
        setState(() {
          _scannerState = ScannerState.error;
          _statusMessage = _messageForQualityIssue(quality.issues.first);
        });
        return;
      }

      final isStable = _gate.onFrame(
        isQualityAcceptable: true,
        trackingId: face.trackingId,
      );

      if (!isStable) {
        setState(() {
          _scannerState = ScannerState.locked;
          _statusMessage = 'Hold still...';
        });
        return;
      }

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
      } catch (_) {}

      final landmarks = FaceAlignmentService.extractLandmarks(landmarkFace);
      if (landmarks == null) {
        _gate.reset();
        setState(() {
          _scannerState = ScannerState.searching;
          _statusMessage = 'Keep your eyes and nose visible.';
        });
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
      await HapticFeedback.lightImpact();
      if (!mounted) return;

      if (_session.isComplete) {
        _hasSubmitted = true;
        setState(() {
          _scannerState = ScannerState.captured;
          _statusMessage = 'Face capture complete. Finalizing...';
        });
        await _submitEnrollment();
        return;
      }

      setState(() {
        _scannerState = ScannerState.locked;
        _statusMessage =
            'Captured ${_session.sampleCount} of ${_session.requiredSamples} samples';
      });

      // Restart stream for next sample
      if (_cameraController != null && !_hasSubmitted) {
        await _cameraController!.startImageStream(_onCameraFrame);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _EnrollPhase.error;
        _scannerState = ScannerState.error;
        _errorMessage = 'Face capture failed: $error';
      });
    }
  }

  Future<_DecodedImage> _decodeImage(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.FrameInfo? frame;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      codec = await descriptor.instantiateCodec();
      frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) {
        throw StateError('Unable to decode the captured image.');
      }

      return _DecodedImage(
        width: frame.image.width,
        height: frame.image.height,
        rgbaPixels: Uint8List.fromList(byteData.buffer.asUint8List()),
      );
    } finally {
      frame?.image.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  Future<void> _submitEnrollment() async {
    final aggregate = _session.buildAggregate();
    await _releaseCamera();

    setState(() {
      _phase = _EnrollPhase.submitting;
      _statusMessage = widget.isReEnrollment
          ? 'Updating your BioPay face...'
          : 'Creating your BioPay profile...';
      _errorMessage = null;
    });

    try {
      final result = widget.isReEnrollment
          ? await _bioPayService.reEnrollFace(
              embedding: aggregate.embedding,
              qualityScore: aggregate.qualityScore,
            )
          : await () async {
              final ussd = await _buildUssdFromHandle();
              if (ussd == null || ussd.isEmpty) {
                throw StateError('Unable to build MoMo payment string.');
              }
              return _bioPayService.enrollFace(
                displayName: _deriveDisplayName(),
                ussdString: ussd,
                embedding: aggregate.embedding,
                qualityScore: aggregate.qualityScore,
              );
            }();

      if (!mounted) return;
      if (!result.success) {
        setState(() {
          _phase = _EnrollPhase.error;
          _errorMessage = result.error ?? 'BioPay enrollment failed.';
        });
        return;
      }

      setState(() {
        _result = result;
        _phase = _EnrollPhase.success;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _EnrollPhase.error;
        _errorMessage = 'BioPay enrollment failed: $error';
      });
    }
  }

  Future<void> _releaseCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      await controller.dispose();
    }
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

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: switch (_phase) {
                _EnrollPhase.loading => _buildLoadingView(),
                _EnrollPhase.ready => _buildReadyView(),
                _EnrollPhase.capturing => _buildCaptureView(),
                _EnrollPhase.submitting => _buildSubmittingView(),
                _EnrollPhase.success => _buildSuccessView(),
                _EnrollPhase.error => _buildErrorView(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TappableIconButton(
            icon: LucideIcons.chevronLeft,
            onTap: widget.onBack,
            color: Theme.of(context).colorScheme.primary,
          ),
          Text(
            widget.isReEnrollment ? 'RE-ENROLL FACE' : 'FACE ENROLLMENT',
            style: AppTypography.labelLg.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            _statusMessage,
            style: AppTypography.bodyMd.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      children: [
        Text(
          widget.isReEnrollment
              ? BiopayStrings.reenrollTitle
              : BiopayStrings.registerTitle,
          style: AppTypography.headlineLg,
        ),
        const SizedBox(height: 8),
        Text(
          widget.isReEnrollment
              ? BiopayStrings.reenrollSubtitle
              : BiopayStrings.registerSubtitle,
          style: AppTypography.bodyLg.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 48),
        if (widget.isReEnrollment)
          _buildReEnrollmentForm()
        else
          _buildRegistrationForm(),
      ],
    );
  }

  Widget _buildRegistrationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // MoMo type switcher
        Text('MoMo', style: AppTypography.labelSm),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).extension<MobiThemeExtension>()!.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              for (final type in BiopayHandleType.values)
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _handleType = type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _handleType == type
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        type.label,
                        style: AppTypography.labelLg.copyWith(
                          color: _handleType == type
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: _handleType == type
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _momoValueController,
          label: _handleType == BiopayHandleType.number
              ? 'Phone number'
              : 'Agent code',
          hintText: _handleType == BiopayHandleType.number
              ? '0788123456'
              : '123456',
          keyboardType: _handleType == BiopayHandleType.number
              ? TextInputType.phone
              : TextInputType.text,
        ),
        const SizedBox(height: 48),
        MobiButton(
          width: double.infinity,
          onPressed: _startCaptureFlow,
          child: Text(
            'START FACE CAPTURE',
            style: AppTypography.labelMd.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            BiopayStrings.registerConsent,
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _openPrivacyCenter,
            child: Text(
              'VIEW PRIVACY & DATA',
              style: AppTypography.labelMd.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReEnrollmentForm() {
    final profile = _managedProfile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (profile != null) ...[
          _infoRow('BioPay ID', profile.biopayId),
          _infoRow('Payment string', profile.ussdString),
          _infoRow(
            'Management code',
            profile.managementCodeHint != null
                ? 'Ends with ${profile.managementCodeHint}'
                : 'Stored on the server',
          ),
          const SizedBox(height: 24),
        ],
        MobiButton(
          width: double.infinity,
          variant: MobiButtonVariant.success,
          onPressed: _startCaptureFlow,
          child: Text(
            'START RE-ENROLLMENT',
            style: AppTypography.labelMd.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a camera preview that fills the available parent space.
  Widget _buildCameraFill(CameraController controller) {
    return RepaintBoundary(child: CameraPreview(controller));
  }

  Widget _buildCaptureView() {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return _buildLoadingView();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCameraFill(controller),
                  AnimatedBuilder(
                    animation: controller,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: OvalPainter(
                          state: _scannerState,
                          progress: _gate.progress == 0 ? 0.4 : _gate.progress,
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.54),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_session.sampleCount}/${_session.requiredSamples}',
                        style: AppTypography.labelMd.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMd.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _session.progress,
            minHeight: 8,
            backgroundColor: Theme.of(
              context,
            ).extension<MobiThemeExtension>()!.surfaceContainerLow,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 12),
          Text(
            'Hold the phone steady while Mobio captures 5 stable face samples.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            _statusMessage,
            style: AppTypography.titleMd,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Mobio is finalizing your BioPay profile.',
            style: AppTypography.bodyMd.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    final result = _result;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      children: [
        ClayCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(
                    LucideIcons.checkCircle,
                    color: Theme.of(context).colorScheme.primary,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  widget.isReEnrollment
                      ? 'Face re-enrollment complete'
                      : 'BioPay profile created',
                  style: AppTypography.headlineLg,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              if (result != null) ...[
                _infoRow('BioPay ID', result.biopayId ?? '—'),
                if (!widget.isReEnrollment && result.ussdString != null)
                  _infoRow('MoMo', result.ussdString!),
                if (!widget.isReEnrollment &&
                    (result.managementCode?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          BiopayStrings.managementCodeTitle,
                          style: AppTypography.titleMd.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          BiopayStrings.managementCodeBody,
                          style: AppTypography.bodyMd.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          result.managementCode!,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              MobiButton(
                width: double.infinity,
                onPressed: widget.onBack,
                child: Text(
                  'BACK TO BIOPAY',
                  style: AppTypography.labelMd.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Center(
        child: ClayCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  LucideIcons.alertTriangle,
                  color: Theme.of(context).colorScheme.error,
                  size: 42,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'BioPay enrollment failed',
                style: AppTypography.headlineMd.copyWith(letterSpacing: -1),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Try the BioPay capture flow again.',
                style: AppTypography.bodyMd.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              MobiButton(
                width: double.infinity,
                onPressed: widget.isReEnrollment
                    ? _bootstrap
                    : _startCaptureFlow,
                child: Text(
                  widget.isReEnrollment ? 'TRY AGAIN' : 'START AGAIN',
                  style: AppTypography.labelMd.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              MobiButton(
                width: double.infinity,
                variant: MobiButtonVariant.ghost,
                onPressed: widget.onBack,
                child: Text(
                  'GO BACK',
                  style: AppTypography.labelMd.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required TextInputType keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelSm),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: AppTypography.bodyLg,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: Theme.of(
              context,
            ).extension<MobiThemeExtension>()!.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: AppTypography.bodyMd)),
        ],
      ),
    );
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
