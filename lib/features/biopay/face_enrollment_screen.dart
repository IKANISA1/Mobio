import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/services/app_permission_service.dart';
import 'package:mobi_app/core/services/biopay_service.dart';
import 'package:mobi_app/core/services/country_service.dart';
import 'package:mobi_app/core/services/profile_service.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
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

import 'package:mobi_app/features/biopay/widgets/face_enrollment_capture.dart';
import 'package:mobi_app/features/biopay/widgets/oval_painter.dart';
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

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen>
    with SingleTickerProviderStateMixin {
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
  String _statusMessage = 'Preparing...';
  String? _errorMessage;
  bool _isProcessingCapture = false;
  bool _hasSubmitted = false;
  FaceQualityIssue? _activeQualityIssue;
  bool _showCapturePulse = false;
  int _capturePulseNonce = 0;
  late final AnimationController _ringPulseController;

  @override
  void initState() {
    super.initState();
    _ringPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _bootstrap();
  }

  @override
  void dispose() {
    _momoValueController.dispose();
    final controller = _cameraController;
    _cameraController = null;
    controller?.dispose();
    _ringPulseController.dispose();
    _embeddingService.dispose();
    _faceDetectionService.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _phase = _EnrollPhase.loading;
      _statusMessage = 'Preparing...';
      _errorMessage = null;
      _result = null;
      _activeQualityIssue = null;
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
          _errorMessage = 'No linked profile found on this device.';
        });
        return;
      }

      _managedProfile = profile;
      setState(() => _phase = _EnrollPhase.ready);
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _EnrollPhase.error;
        _errorMessage = 'Unable to load profile. Please try again.';
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
    } on Object catch (_) {
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

  Future<void> _triggerCapturePulse() async {
    final ticket = ++_capturePulseNonce;
    if (!mounted) return;
    setState(() => _showCapturePulse = true);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted || ticket != _capturePulseNonce) return;
    setState(() => _showCapturePulse = false);
  }

  Future<void> _copyManagementCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    _showSnackBar('Management code copied to clipboard.');
  }

  Future<void> _retryFromError() async {
    if (_session.isComplete) {
      await _submitEnrollment();
      return;
    }
    await _startCaptureFlow();
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

    // Request camera permission
    final action = await PermissionAccessDialog.show(
      context,
      config: PermissionAccessDialogConfig.biopayCamera(),
    );
    if (!mounted) return;
    if (action != PermissionAccessDialogAction.grantAccess) {
      _showSnackBar('Camera access is required for BioPay face capture.');
      return;
    }
    
    // Prevent modal barrier deadlock by waiting for the dialog's dismiss animation
    await Future.delayed(const Duration(milliseconds: 350));

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
      _statusMessage = 'Starting camera...';
      _errorMessage = null;
      _scannerState = ScannerState.searching;
      _activeQualityIssue = null;
      _showCapturePulse = false;
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
        _statusMessage = 'Hold still';
        _activeQualityIssue = null;
      });

      // Start live image stream instead of polling
      await controller.startImageStream(_onCameraFrame);
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _EnrollPhase.error;
        _scannerState = ScannerState.error;
        _errorMessage = 'Camera setup failed. Please try again.';
        _activeQualityIssue = null;
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
          _statusMessage = 'Center your face in the oval';
          _activeQualityIssue = null;
        });
        return;
      }

      if (faces.length > 1) {
        _gate.reset();
        setState(() {
          _scannerState = ScannerState.error;
          _statusMessage = BiopayStrings.qualityMultipleFaces;
          _activeQualityIssue = FaceQualityIssue.multipleFaces;
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
          _activeQualityIssue = quality.issues.first;
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
          _statusMessage = 'Hold still';
          _activeQualityIssue = null;
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
      } on Object catch (_) {}

      final landmarks = FaceAlignmentService.extractLandmarks(landmarkFace);
      if (landmarks == null) {
        _gate.reset();
        setState(() {
          _scannerState = ScannerState.searching;
          _statusMessage = 'Keep your face fully visible';
          _activeQualityIssue = null;
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
      _triggerCapturePulse();
      if (!mounted) return;

      if (_session.isComplete) {
        _hasSubmitted = true;
        setState(() {
          _scannerState = ScannerState.captured;
          _statusMessage = 'Finalizing...';
          _activeQualityIssue = null;
        });
        await _submitEnrollment();
        return;
      }

      setState(() {
        _scannerState = ScannerState.locked;
        _statusMessage =
            '${_session.sampleCount} of ${_session.requiredSamples}';
        _activeQualityIssue = null;
      });

      // Restart stream for next sample
      if (_cameraController != null && !_hasSubmitted) {
        await _cameraController!.startImageStream(_onCameraFrame);
      }
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _EnrollPhase.error;
        _scannerState = ScannerState.error;
        _errorMessage = 'Face capture failed. Please try again.';
        _activeQualityIssue = null;
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
          ? 'Updating face data...'
          : 'Creating profile...';
      _errorMessage = null;
      _activeQualityIssue = null;
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
          _errorMessage =
              result.error ?? 'Enrollment failed. Please try again.';
          _activeQualityIssue = null;
        });
        return;
      }

      setState(() {
        _result = result;
        _phase = _EnrollPhase.success;
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _EnrollPhase.error;
        _errorMessage = 'Enrollment failed. Please try again.';
        _activeQualityIssue = null;
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
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cs.surface,
                    ext.surfaceContainerLowest,
                    Colors.black.withValues(alpha: 0.06),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(0, 0.06),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(_phase),
                      child: switch (_phase) {
                        _EnrollPhase.loading => _buildLoadingView(),
                        _EnrollPhase.ready => _buildReadyView(),
                        _EnrollPhase.capturing => _buildCaptureView(),
                        _EnrollPhase.submitting => _buildSubmittingView(),
                        _EnrollPhase.success => _buildSuccessView(),
                        _EnrollPhase.error => _buildErrorView(),
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          TappableIconButton(
            icon: LucideIcons.chevronLeft,
            onTap: widget.onBack,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              widget.isReEnrollment ? 'Update My Face' : 'Register My Face',
              style: AppTypography.titleLg.copyWith(letterSpacing: -0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _buildStepSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 18),
                Text(
                  _statusMessage,
                  style: AppTypography.titleMd,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadyView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      children: [
        _buildStepSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isReEnrollment
                    ? BiopayStrings.reenrollTitle
                    : BiopayStrings.registerTitle,
                style: AppTypography.headlineLg,
              ),
              const SizedBox(height: 6),
              Text(
                widget.isReEnrollment
                    ? BiopayStrings.reenrollSubtitle
                    : BiopayStrings.registerSubtitle,
                style: AppTypography.bodyMd.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              if (widget.isReEnrollment)
                _buildReEnrollmentForm()
              else
                _buildRegistrationForm(),
            ],
          ),
        ),
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
            'CONTINUE',
            style: AppTypography.labelMd.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
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
            'START',
            style: AppTypography.labelMd.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaptureView() {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return _buildLoadingView();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: FaceEnrollmentCapture(
                controller: controller,
                state: _scannerState,
                statusMessage: _statusMessage,
                sampleCount: _session.sampleCount,
                totalSamples: _session.requiredSamples,
                stabilityProgress: _gate.progress,
                showCapturePulse: _showCapturePulse,
                ringPulse: _ringPulseController,
                qualityIssue: _activeQualityIssue,
                qualityMessage: _activeQualityIssue != null
                    ? _statusMessage
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubmittingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: _buildStepSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  _statusMessage,
                  style: AppTypography.headlineMd,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    final result = _result;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      children: [
        _buildStepSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: _SuccessCelebration()),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  widget.isReEnrollment ? 'Face updated' : 'You\'re all set',
                  style: AppTypography.headlineLg,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  widget.isReEnrollment
                      ? 'Your face data has been refreshed.'
                      : 'Your BioPay profile is ready.',
                  style: AppTypography.bodyMd.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
                  const SizedBox(height: 14),
                  _buildManagementCodeCard(result.managementCode!),
                ],
              ],
              const SizedBox(height: 24),
              MobiButton(
                width: double.infinity,
                onPressed: widget.onBack,
                child: Text(
                  'DONE',
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      children: [
        _buildStepSurface(
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
                'Something went wrong',
                style: AppTypography.headlineMd.copyWith(letterSpacing: -1),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Please try again.',
                style: AppTypography.bodyMd.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              MobiButton(
                width: double.infinity,
                onPressed: _retryFromError,
                child: Text(
                  _session.isComplete ? 'RETRY' : 'TRY AGAIN',
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
      ],
    );
  }

  Widget _buildStepSurface({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(24),
  }) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: ext.surfaceContainerLowest.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: ext.clayCardShadow,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.05),
            ext.surfaceContainerLowest.withValues(alpha: 0.96),
            cs.surface.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: child,
    );
  }

  Widget _buildManagementCodeCard(String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3C2B08), Color(0xFF6C4D12), Color(0xFF2E2206)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFD67A).withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFC857).withValues(alpha: 0.16),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  BiopayStrings.managementCodeTitle,
                  style: AppTypography.titleMd.copyWith(
                    color: const Color(0xFFFFE4A4),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _copyManagementCode(code),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFFE4A4),
                ),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: Text(
                  'COPY',
                  style: AppTypography.labelMd.copyWith(letterSpacing: 0.6),
                ),
              ),
            ],
          ),
          Text(
            BiopayStrings.managementCodeBody,
            style: AppTypography.bodySm.copyWith(
              color: Colors.white.withValues(alpha: 0.86),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            code,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
          ),
        ],
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

class _SuccessCelebration extends StatelessWidget {
  const _SuccessCelebration();

  static const _particles =
      <({double left, double top, double size, Color color})>[
        (left: 12, top: 28, size: 12, color: AppColors.warning),
        (left: 46, top: 12, size: 8, color: AppColors.bioPayGreen),
        (left: 128, top: 18, size: 10, color: AppColors.secondaryFixed),
        (left: 168, top: 34, size: 12, color: AppColors.warning),
        (left: 24, top: 112, size: 10, color: AppColors.bioPayGreen),
        (left: 148, top: 108, size: 8, color: AppColors.secondaryFixed),
      ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final particle in _particles)
            Positioned(
              left: particle.left,
              top: particle.top,
              child: Animate(
                effects: const [
                  FadeEffect(duration: Duration(milliseconds: 180)),
                  MoveEffect(
                    begin: Offset(0, 12),
                    end: Offset(0, -14),
                    duration: Duration(milliseconds: 1400),
                    curve: Curves.easeOutCubic,
                  ),
                  ScaleEffect(
                    begin: Offset(0.2, 0.2),
                    end: Offset(1, 1),
                    duration: Duration(milliseconds: 520),
                    curve: Curves.easeOutBack,
                  ),
                ],
                child: Container(
                  width: particle.size,
                  height: particle.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: particle.color.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ),
          Animate(
            effects: const [
              FadeEffect(duration: Duration(milliseconds: 260)),
              ScaleEffect(
                begin: Offset(0.82, 0.82),
                end: Offset(1, 1),
                duration: Duration(milliseconds: 460),
                curve: Curves.easeOutBack,
              ),
            ],
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.bioPayGreen.withValues(alpha: 0.96),
                    AppColors.primary.withValues(alpha: 0.94),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.bioPayGreen.withValues(alpha: 0.26),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 52,
              ),
            ),
          ),
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
