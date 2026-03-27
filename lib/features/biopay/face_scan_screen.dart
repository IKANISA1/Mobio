import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/services/app_permission_service.dart';
import 'package:mobi_app/core/services/biopay_service.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/features/biopay/biopay_strings.dart';
import 'package:mobi_app/features/biopay/models/biopay_models.dart';
import 'package:mobi_app/features/biopay/services/embedding_service.dart';
import 'package:mobi_app/features/biopay/services/face_alignment_service.dart';
import 'package:mobi_app/features/biopay/services/face_detection_service.dart';
import 'package:mobi_app/features/biopay/services/stable_frame_gate.dart';
import 'package:mobi_app/features/biopay/services/ussd_launcher_service.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/permission_access_dialog.dart';

class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

enum _ScanPhase { loading, scanning, processing, matched, noMatch, error }

class _FaceScanScreenState extends State<FaceScanScreen> {
  final _permissionService = AppPermissionService.instance;
  final _bioPayService = BioPayService();
  final _faceDetectionService = FaceDetectionService();
  final _embeddingService = EmbeddingService();
  final _gate = StableFrameGate.scan();
  final _ussdLauncher = UssdLauncherService();

  CameraController? _cameraController;
  CameraDescription? _selectedCamera;
  _ScanPhase _phase = _ScanPhase.loading;
  String _statusMessage = 'Preparing camera...';
  String? _errorMessage;
  MatchResult? _matchResult;
  bool _isProcessingFrame = false;
  bool _isCameraDenied = false;

  @override
  void initState() {
    super.initState();
    _prepareScanner(promptForPermission: true);
  }

  @override
  void dispose() {
    final controller = _cameraController;
    _cameraController = null;
    controller?.dispose();
    _embeddingService.dispose();
    _faceDetectionService.dispose();
    super.dispose();
  }

  Future<void> _prepareScanner({required bool promptForPermission}) async {
    setState(() {
      _phase = _ScanPhase.loading;
      _statusMessage = 'Preparing camera...';
      _errorMessage = null;
      _matchResult = null;
      _isCameraDenied = false;
    });

    // Show the permission pre-prompt dialog on first attempt
    if (promptForPermission) {
      final action = await PermissionAccessDialog.show(
        context,
        config: PermissionAccessDialogConfig.biopayCamera(),
      );
      if (!mounted) return;
      if (action != PermissionAccessDialogAction.grantAccess) {
        setState(() {
          _phase = _ScanPhase.error;
          _isCameraDenied = true;
          _errorMessage = 'Camera access is required to scan faces.';
        });
        return;
      }
    }

    final hasAccess = await _permissionService.ensureBiopayCameraAccess();
    if (!mounted) return;
    if (!hasAccess) {
      setState(() {
        _phase = _ScanPhase.error;
        _isCameraDenied = true;
        _errorMessage = 'Camera access is required to scan faces.';
      });
      return;
    }

    await _initializeCameraAndServices();
  }

  Future<void> _initializeCameraAndServices() async {
    try {
      _faceDetectionService.initialize();
      await _embeddingService.initialize();
      await _bioPayService.warmMatchCache();

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
      _gate.reset();
      _isProcessingFrame = false;

      setState(() {
        _phase = _ScanPhase.scanning;
        _statusMessage = BiopayStrings.scanSearching;
      });

      // Start live image stream instead of takePicture polling
      await controller.startImageStream(_onCameraFrame);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _ScanPhase.error;
        _errorMessage = 'Unable to start BioPay scanner: $error';
      });
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (_isProcessingFrame || _phase != _ScanPhase.scanning) return;
    _isProcessingFrame = true;
    _processLiveFrame(image).whenComplete(() {
      _isProcessingFrame = false;
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
          _statusMessage = BiopayStrings.scanSearching;
        });
        return;
      }

      if (faces.length > 1) {
        _gate.reset();
        setState(() {
          _statusMessage = BiopayStrings.qualityMultipleFaces;
        });
        return;
      }

      final face = faces.first;
      final frameWidth = image.width.toDouble();
      final frameHeight = image.height.toDouble();

      // Estimate brightness from the Y (luminance) plane of NV21/YUV.
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

      final isStable = _gate.onFrame(
        isQualityAcceptable: quality.isAcceptable,
        trackingId: face.trackingId,
      );

      if (!quality.isAcceptable) {
        setState(() {
          _statusMessage = _messageForQualityIssue(quality.issues.first);
        });
        return;
      }

      if (!isStable) {
        setState(() {
          _statusMessage = BiopayStrings.scanLocked;
        });
        return;
      }

      // Stop stream before heavy processing
      await _cameraController?.stopImageStream();

      setState(() {
        _phase = _ScanPhase.processing;
        _statusMessage = BiopayStrings.scanMatching;
      });

      final landmarks = FaceAlignmentService.extractLandmarks(face);
      if (landmarks == null) {
        _gate.reset();
        setState(() {
          _phase = _ScanPhase.error;
          _errorMessage =
              'Keep your eyes and nose visible for BioPay matching.';
        });
        return;
      }

      // For alignment, capture a still frame via takePicture for RGBA decode.
      // The CameraImage YUV planes are used for detection + brightness only.
      final controller = _cameraController;
      if (controller == null || !controller.value.isInitialized) return;
      final capture = await controller.takePicture();
      final decodedImage = await _decodeImage(capture.path);
      try {
        await File(capture.path).delete();
      } catch (_) {}

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
      await HapticFeedback.mediumImpact();

      final result = await _bioPayService.matchFace(
        embedding: embedding,
        deviceLabel: 'mobi-face-scan',
      );
      await _releaseCamera();

      if (!mounted) return;
      if (result.isMatch) {
        setState(() {
          _matchResult = result;
          _phase = _ScanPhase.matched;
        });
      } else {
        _gate.reset();
        setState(() {
          _matchResult = null;
          _phase = _ScanPhase.noMatch;
          _statusMessage = BiopayStrings.scanNoMatch;
        });
      }
    } catch (error) {
      await _releaseCamera();
      if (!mounted) return;
      setState(() {
        _phase = _ScanPhase.error;
        _errorMessage = 'BioPay scan failed: $error';
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

  Future<void> _releaseCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      await controller.dispose();
    }
  }

  Future<void> _retryScanning() async {
    await _releaseCamera();
    _gate.reset();
    await _prepareScanner(promptForPermission: false);
  }

  Future<void> _launchUssd(String ussdString) async {
    final launched = await _ussdLauncher.launchUssdPayment(ussdString);
    if (!mounted) return;
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to launch the payment string.')),
      );
    }
  }

  Future<void> _reportMatch() async {
    final result = _matchResult;
    if (result?.biopayId == null) return;

    try {
      await _bioPayService.reportProfile(
        biopayId: result!.biopayId!,
        reason: 'not me',
        notes: 'Reported from Mobio BioPay face scan',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('BioPay report submitted.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to report BioPay match: $error')),
      );
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

  @override
  Widget build(BuildContext context) {
    // Always fullscreen camera layout — phase-specific content overlaid on top
    final bool showCamera = _cameraController != null &&
        _cameraController!.value.isInitialized;
    final bool isActiveScanning =
        _phase == _ScanPhase.scanning || _phase == _ScanPhase.processing;
    final bool isResultPhase =
        _phase == _ScanPhase.matched ||
        _phase == _ScanPhase.noMatch ||
        _phase == _ScanPhase.error;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1) Top header bar — always above the camera
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: widget.onBack,
                      customBorder: const CircleBorder(),
                      splashColor: Colors.white.withValues(alpha: 0.2),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(LucideIcons.x, size: 20, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    isActiveScanning
                        ? 'SCANNING FACE'
                        : isResultPhase
                            ? 'FACE SCAN'
                            : 'INITIALIZING…',
                    style: AppTypography.titleLg.copyWith(
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),

            // 2) Camera + overlays fill the remaining space
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Fullscreen camera preview
                  if (showCamera)
                    Positioned.fill(child: RepaintBoundary(child: CameraPreview(_cameraController!))),

                  // Viewfinder overlay when actively scanning
                  if (isActiveScanning) _buildViewfinderOverlay(),

                  // Bottom status pill for scanning / loading
                  if (_phase == _ScanPhase.scanning || _phase == _ScanPhase.loading)
                    Positioned(
                      bottom: 100,
                      left: 24,
                      right: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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

                  // Loading spinner overlay
                  if (_phase == _ScanPhase.loading)
                    Positioned.fill(
                      child: Center(
                        child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),

                  // Processing overlay
                  if (_phase == _ScanPhase.processing)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.6),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                              const SizedBox(height: 20),
                              Text(
                                BiopayStrings.scanMatching,
                                style: AppTypography.titleMd.copyWith(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Result overlays (matched / noMatch / error) — bottom sheet style
                  if (isResultPhase)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          child: SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                              child: switch (_phase) {
                                _ScanPhase.matched => _buildMatchedContent(),
                                _ScanPhase.noMatch => _buildNoMatchContent(),
                                _ScanPhase.error => _buildErrorContent(),
                                _ => const SizedBox.shrink(),
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Green corner-bracket viewfinder overlay matching the reference design.
  Widget _buildViewfinderOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _FaceViewfinderPainter(
            viewfinderFraction: 0.88,
            overlayColor: Colors.black.withValues(alpha: 0.45),
            borderColor: Theme.of(context).colorScheme.primary,
            borderWidth: 3,
            cornerLength: 36,
            borderRadius: 24,
          ),
        ),
      ),
    );
  }

  /// Content for matched result (used inside the bottom sheet overlay).
  Widget _buildMatchedContent() {
    final result = _matchResult;
    if (result == null) return _buildNoMatchContent();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
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
            'BioPay Match',
            style: AppTypography.headlineLg,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        _infoRow('BioPay ID', result.biopayId ?? '—'),
        if (result.score != null)
          _infoRow('Match score', result.score!.toStringAsFixed(3)),
        _infoRow(
          'Match source',
          result.isCached ? 'Recent device cache' : 'Live BioPay search',
        ),
        if (result.ussdString != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment String',
                  style: AppTypography.labelSm.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  result.ussdString!,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        MobiButton(
          width: double.infinity,
          onPressed: result.ussdString == null
              ? null
              : () => _launchUssd(result.ussdString!),
          child: Text(
            'PAY WITH USSD',
            style: AppTypography.labelMd.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        MobiButton(
          width: double.infinity,
          variant: MobiButtonVariant.ghost,
          onPressed: _reportMatch,
          child: Text(
            'REPORT MATCH',
            style: AppTypography.labelMd.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 12),
        MobiButton(
          width: double.infinity,
          variant: MobiButtonVariant.success,
          onPressed: _retryScanning,
          child: Text(
            'SCAN AGAIN',
            style: AppTypography.labelMd.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  /// Content for no-match result (used inside the bottom sheet overlay).
  Widget _buildNoMatchContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Icon(
            LucideIcons.scanLine,
            color: Theme.of(context).colorScheme.secondary,
            size: 42,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'No BioPay match',
          style: AppTypography.headlineMd.copyWith(
            letterSpacing: -1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          _statusMessage,
          style: AppTypography.bodyMd.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        MobiButton(
          width: double.infinity,
          onPressed: _retryScanning,
          child: Text(
            'TRY AGAIN',
            style: AppTypography.labelMd.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  /// Content for error result (used inside the bottom sheet overlay).
  Widget _buildErrorContent() {
    if (_isCameraDenied) return _buildCameraDeniedContent();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.14),
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
          'BioPay scan failed',
          style: AppTypography.headlineMd.copyWith(
            letterSpacing: -1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          _errorMessage ?? 'Try the BioPay scanner again.',
          style: AppTypography.bodyMd.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        MobiButton(
          width: double.infinity,
          onPressed: _retryScanning,
          child: Text(
            'TRY AGAIN',
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
    );
  }

  /// Camera-specific denied state with "OPEN SETTINGS" deep link.
  Widget _buildCameraDeniedContent() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Icon(
            LucideIcons.cameraOff,
            color: cs.primary,
            size: 42,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Camera access required',
          style: AppTypography.headlineMd.copyWith(
            letterSpacing: -1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'BioPay needs camera access to scan and match faces securely on-device. '
          'Please enable camera access in your device settings.',
          style: AppTypography.bodyMd.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        MobiButton(
          width: double.infinity,
          onPressed: () async {
            await _permissionService.openAppPermissionSettings();
          },
          child: Text(
            'OPEN SETTINGS',
            style: AppTypography.labelMd.copyWith(
              color: cs.onPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        MobiButton(
          width: double.infinity,
          variant: MobiButtonVariant.ghost,
          onPressed: () => _prepareScanner(promptForPermission: true),
          child: Text(
            'TRY AGAIN',
            style: AppTypography.labelMd.copyWith(
              color: cs.onSurface,
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
              color: cs.onSurfaceVariant,
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

/// Custom painter for green corner-bracket viewfinder overlay.
class _FaceViewfinderPainter extends CustomPainter {
  final double viewfinderFraction;
  final Color overlayColor;
  final Color borderColor;
  final double borderWidth;
  final double cornerLength;
  final double borderRadius;

  _FaceViewfinderPainter({
    required this.viewfinderFraction,
    required this.overlayColor,
    required this.borderColor,
    required this.borderWidth,
    required this.cornerLength,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final viewfinderWidth = size.width * viewfinderFraction;
    final viewfinderHeight = size.height * 0.65;
    final left = (size.width - viewfinderWidth) / 2;
    final top = (size.height - viewfinderHeight) / 2;
    final rect = Rect.fromLTWH(left, top, viewfinderWidth, viewfinderHeight);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // Semi-transparent overlay with hole
    final overlayPaint = Paint()..color = overlayColor;
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlayPaint);

    // Corner brackets
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final right = left + viewfinderWidth;
    final bottom = top + viewfinderHeight;
    final r = borderRadius;
    final cl = cornerLength;

    canvas
      // Top-left
      ..drawLine(Offset(left, top + cl), Offset(left, top + r), cornerPaint)
      ..drawArc(Rect.fromLTWH(left, top, r * 2, r * 2), 3.14159, 1.5708, false, cornerPaint)
      ..drawLine(Offset(left + r, top), Offset(left + cl, top), cornerPaint)
      // Top-right
      ..drawLine(Offset(right - cl, top), Offset(right - r, top), cornerPaint)
      ..drawArc(Rect.fromLTWH(right - r * 2, top, r * 2, r * 2), -1.5708, 1.5708, false, cornerPaint)
      ..drawLine(Offset(right, top + r), Offset(right, top + cl), cornerPaint)
      // Bottom-left
      ..drawLine(Offset(left, bottom - cl), Offset(left, bottom - r), cornerPaint)
      ..drawArc(Rect.fromLTWH(left, bottom - r * 2, r * 2, r * 2), 1.5708, 1.5708, false, cornerPaint)
      ..drawLine(Offset(left + r, bottom), Offset(left + cl, bottom), cornerPaint)
      // Bottom-right
      ..drawLine(Offset(right - cl, bottom), Offset(right - r, bottom), cornerPaint)
      ..drawArc(Rect.fromLTWH(right - r * 2, bottom - r * 2, r * 2, r * 2), 0, 1.5708, false, cornerPaint)
      ..drawLine(Offset(right, bottom - r), Offset(right, bottom - cl), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
