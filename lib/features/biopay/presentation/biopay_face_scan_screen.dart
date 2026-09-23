import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/data/biopay_face_service.dart';
import 'package:mobi_app/features/biopay/data/face_capture.dart';
import 'package:mobi_app/features/biopay/data/payment_discovery_service.dart';
import 'package:mobi_app/features/biopay/domain/face_shortcut.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_flow_shared.dart';
import 'package:mobi_app/features/biopay/presentation/face_copy.dart';
import 'package:mobi_app/features/biopay/presentation/payment_widgets.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';

class BioPayFaceScanScreen extends ConsumerStatefulWidget {
  const BioPayFaceScanScreen({super.key, required this.onBack});
  final VoidCallback onBack;
  @override
  ConsumerState<BioPayFaceScanScreen> createState() =>
      _BioPayFaceScanScreenState();
}

class _BioPayFaceScanScreenState extends ConsumerState<BioPayFaceScanScreen>
    with WidgetsBindingObserver {
  late final FaceCapture _capture;
  final _gate = FaceHandoffGate();
  int _generation = 0;
  bool _foreground = true, _busy = false, _opened = false;
  Object? _error;
  PreparedFaceUssdShortcut? _shortcut;
  @override
  void initState() {
    super.initState();
    _capture = ref.read(faceCaptureFactoryProvider)();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _generation++;
    _gate.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_capture.stop().catchError((Object _) {}));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _gate.foreground(_foreground);
    if (!_foreground) {
      _generation++;
      unawaited(_capture.stop().catchError((Object _) {}));
      if (mounted) setState(() => _busy = false);
    }
    // Resume never starts a camera, repeats a lookup or reopens a dialer.
  }

  Future<void> _scan() async {
    if (_busy || !_foreground) return;
    final generation = ++_generation;
    final service = ref.read(biopayFaceServiceProvider);
    final ticket = _gate.begin(service.ownerId);
    if (ticket == null) {
      setState(() => _error = const FaceServiceException('AUTH_EXPIRED'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _shortcut = null;
      _opened = false;
    });
    Uint8List? bytes;
    try {
      if (!_capture.isReady) {
        await _capture.start(front: false);
        return;
      }
      bytes = await _capture.capture();
      await _capture.stop();
      if (!_gate.accepts(ticket, service.ownerId)) return;
      final shortcut = await service.resolveShortcut(
        imageBytes: bytes,
        idempotencyKey: newBioPayUuid(),
      );
      await _capture.stop();
      if (!mounted || !_gate.accepts(ticket, service.ownerId)) return;
      setState(() => _shortcut = shortcut);
      final native = ref.read(paymentDiscoveryServiceProvider);
      if (native.deviceFamily != 'android') return;
      if (!_gate.claim(ticket, service.ownerId, shortcut, DateTime.now())) {
        return;
      }
      final launched = await native.openReviewedInstruction({
        'mode': 'dial',
        'instruction': shortcut.ussdCode,
      });
      if (launched) {
        unawaited(
          service.recordHandoff(shortcut.requestId).catchError((Object _) {}),
        );
      }
      if (mounted &&
          _shortcut?.requestId == shortcut.requestId &&
          service.ownerId == ticket.account) {
        setState(() {
          _opened = launched;
          if (!launched) _error = const FaceServiceException('DIAL_FAILED');
        });
      }
    } on Object catch (error) {
      if (mounted && generation == _generation) setState(() => _error = error);
    } finally {
      bytes?.fillRange(0, bytes.length, 0);
      _gate.finish(ticket);
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _openAlternative(String route) async {
    if (_busy) return;
    _generation++;
    _gate.cancel();
    setState(() => _busy = true);
    try {
      await _capture.stop();
      if (mounted) await context.push(route);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = paymentCopy(context);
    final camera = _capture.controller;
    final shortcut = _shortcut;
    final hasCamera = camera?.value.isInitialized == true;
    return BioPayFlowScreen(
      title: l.faceScanTitle,
      primaryLabel: '',
      headerSpacing: 20,
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.faceScanInstruction),
          const SizedBox(height: 16),
          if (shortcut == null) ...[
            if (hasCamera)
              BioPayCameraFrame(
                controller: camera!,
                showFaceGuide: true,
                height: 280,
              )
            else
              BioPayFaceEnrollmentStandby(
                iconColor: Theme.of(context).colorScheme.primary,
                height: 280,
                guideSize: const Size(138, 188),
              ),
            const SizedBox(height: 20),
            MobiButton(
              onPressed: _busy ? null : _scan,
              isLoading: _busy,
              child: Text(
                _busy
                    ? l.faceWorking
                    : _capture.isReady
                    ? l.faceScanAction
                    : l.faceStartCamera,
              ),
            ),
          ] else ...[
            Semantics(
              liveRegion: true,
              child: Text(
                _opened
                    ? l.faceOpened
                    : _busy
                    ? l.faceOpening
                    : l.faceManualPlatform,
              ),
            ),
            if (!_opened && !_busy) ...[
              const SizedBox(height: 16),
              SelectableText(shortcut.ussdCode),
              MobiButton(
                variant: MobiButtonVariant.ghost,
                onPressed: () async {
                  if (!shortcut.isCurrent(DateTime.now())) {
                    setState(() {
                      _shortcut = null;
                      _error = const FaceServiceException('TIMEOUT');
                    });
                    return;
                  }
                  await Clipboard.setData(
                    ClipboardData(text: shortcut.ussdCode),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(l.faceCopied)));
                  }
                },
                child: Text(l.faceCopyCode),
              ),
            ],
            const SizedBox(height: 16),
            MobiButton(onPressed: widget.onBack, child: Text(l.faceDone)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: BioPayInlineError(
                message:
                    _error is FaceServiceException &&
                        (_error as FaceServiceException).code == 'DIAL_FAILED'
                    ? l.faceDialFailed
                    : faceErrorCopy(context, _error!),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => _openAlternative('/biopay/send'),
              child: Text(l.faceManual),
            ),
            TextButton(
              onPressed: _busy ? null : () => _openAlternative('/biopay/scan'),
              child: Text(l.faceQr),
            ),
          ],
        ],
      ),
    );
  }
}
