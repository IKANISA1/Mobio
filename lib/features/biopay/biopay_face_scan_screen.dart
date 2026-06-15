import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/utils/money_formatting.dart';
import 'package:mobi_app/features/biopay/biopay_flow_shared.dart';
import 'package:mobi_app/features/biopay/models/biopay_ussd_payment.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';

class BioPayFaceScanScreen extends ConsumerStatefulWidget {
  const BioPayFaceScanScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<BioPayFaceScanScreen> createState() =>
      _BioPayFaceScanScreenState();
}

class _BioPayFaceScanScreenState extends ConsumerState<BioPayFaceScanScreen> {
  final TextEditingController _amountController = TextEditingController(
    text: formatWholeAmount(1500),
  );
  CameraController? _camera;
  BioPayUssdPaymentRequest? _request;
  String? _matchLabel;
  String? _error;
  bool _showEnrollFallback = false;
  bool _busy = false;

  @override
  void dispose() {
    _amountController.dispose();
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _scanFace() async {
    setState(() {
      _busy = true;
      _error = null;
      _showEnrollFallback = false;
    });
    try {
      if (_camera?.value.isInitialized != true) {
        await _ensureCamera();
        if (!mounted) return;
        setState(() {
          _matchLabel = null;
        });
        return;
      }
      final camera = _camera!;
      final file = await camera.takePicture();
      final faceResult = await ref
          .read(biopayFaceServiceProvider)
          .matchFace(imageBytes: await file.readAsBytes());
      if (faceResult.status != 'matched' || faceResult.providerFaceId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _request = null;
          _matchLabel =
              '${faceResult.status} ${(faceResult.confidence * 100).round()}%';
          _error = 'No enrolled BioPay face matched.';
          _showEnrollFallback = true;
        });
        return;
      }
      final ussdService = ref.read(biopayUssdServiceProvider);
      final amountMinor = amountMinorFromController(_amountController);
      final request = SupabaseConfig.isConfigured
          ? await ussdService.createFaceMatchPaymentRequest(
              providerFaceId: faceResult.providerFaceId,
              amountMinor: amountMinor,
            )
          : ussdService.createPreviewRequest(
              channel: BioPayRequestChannel.face,
              amountMinor: amountMinor,
            );
      if (!mounted) return;
      setState(() {
        _request = request;
        _matchLabel =
            '${faceResult.status} ${(faceResult.confidence * 100).round()}%';
        _showEnrollFallback = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyFaceScanMessage(error);
        _showEnrollFallback = false;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runExternalPaymentStep() async {
    final request = _request;
    if (request == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(biopayUssdServiceProvider);
      final updated = switch (request.status) {
        BioPayRequestStatus.readyToDial => await service.openUssdDialer(
          request,
        ),
        BioPayRequestStatus.dialerOpened => await service.markUserPaid(request),
        _ => request,
      };
      if (!mounted) return;
      if (updated == null) {
        setState(() => _error = 'USSD dialer unavailable.');
        return;
      }
      setState(() => _request = updated);
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _error = 'External payment status unavailable.');
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
    CameraDescription? back;
    for (final camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.back) {
        back = camera;
        break;
      }
    }
    final controller = CameraController(
      back ?? cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize().timeout(const Duration(seconds: 8));
    _camera = controller;
  }

  String _friendlyFaceScanMessage(Object error) {
    if (error is CameraException) {
      final code = error.code.toLowerCase();
      if (code.contains('access') || code.contains('permission')) {
        return 'Camera permission is required to scan your face.';
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
    return 'Face scan unavailable.';
  }

  @override
  Widget build(BuildContext context) {
    final readyForPreview = _camera?.value.isInitialized == true;
    final primaryLabel = _request == null
        ? readyForPreview
              ? 'Match face'
              : 'Start Face Scan'
        : externalActionLabel(_request!);

    return BioPayFlowScreen(
      title: 'Face scan',
      primaryLabel: _request == null ? '' : primaryLabel,
      isPrimaryLoading: _busy,
      onBack: widget.onBack,
      headerSpacing: 18,
      onPrimary: _request == null
          ? null
          : canRunExternalAction(_request)
          ? _runExternalPaymentStep
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_request != null)
            BioPayResolvedPaymentPreview(request: _request!)
          else ...[
            BioPayReceiveAmountField(
              controller: _amountController,
              showLabel: false,
            ),
            const SizedBox(height: AppSpacing.sm),
            MobiButton(
              onPressed: _busy ? null : _scanFace,
              isLoading: _busy,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 17,
              ),
              child: Text(primaryLabel),
            ),
            const SizedBox(height: AppSpacing.md),
            if (readyForPreview)
              BioPayCameraFrame(
                controller: _camera!,
                totalSteps: 1,
                currentStepId: 'straight_1',
                showFaceGuide: true,
              )
            else
              BioPayFaceEnrollmentStandby(
                iconColor: Theme.of(context).colorScheme.primary,
                height: 376,
                guideSize: const Size(190, 258),
              ),
          ],
          if (_matchLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            BioPayDetailRow(label: 'Match', value: _matchLabel!),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            BioPayInlineError(message: _error!),
          ],
          if (_showEnrollFallback) ...[
            const SizedBox(height: AppSpacing.md),
            MobiButton(
              variant: MobiButtonVariant.ghost,
              onPressed: () => context.push('/biopay/enroll'),
              child: const Text('Enroll BioPay face'),
            ),
          ],
        ],
      ),
    );
  }
}
