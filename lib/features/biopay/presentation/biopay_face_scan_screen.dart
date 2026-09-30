import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/auth/account_context.dart';
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
  AccountSnapshot? _viewAccount;
  bool _foreground = true, _busy = false, _opened = false;
  Object? _error;
  PreparedFaceUssdShortcut? _shortcut;
  AccountSnapshot? _shortcutAccount;
  @override
  void initState() {
    super.initState();
    _capture = ref.read(faceCaptureFactoryProvider)();
    WidgetsBinding.instance.addObserver(this);
    try {
      _viewAccount = ref.read(biopayFaceServiceProvider).captureAccount();
    } on Object {
      _viewAccount = null;
    }
    AccountContext.changes.addListener(_onAccountChanged);
  }

  void _onAccountChanged() {
    if (!mounted) return;
    final service = ref.read(biopayFaceServiceProvider);
    final previous = _viewAccount;
    if (previous != null && service.isCurrent(previous)) return;
    try {
      _viewAccount = service.captureAccount();
    } on Object {
      _viewAccount = null;
    }
    _generation++;
    _gate.cancel();
    unawaited(_capture.stop().catchError((Object _) {}));
    setState(() {
      _shortcut = null;
      _shortcutAccount = null;
      _busy = false;
      _opened = false;
      _error = const FaceServiceException('AUTH_EXPIRED');
    });
  }

  @override
  void dispose() {
    _generation++;
    _gate.cancel();
    AccountContext.changes.removeListener(_onAccountChanged);
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
    AccountSnapshot account;
    try {
      account = service.captureAccount();
    } on Object {
      setState(() => _error = const FaceServiceException('AUTH_EXPIRED'));
      return;
    }
    bool current() =>
        mounted &&
        _foreground &&
        generation == _generation &&
        service.isCurrent(account);
    final ticket = _gate.begin(account.identity);
    if (ticket == null) {
      setState(() => _error = const FaceServiceException('AUTH_EXPIRED'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _shortcut = null;
      _shortcutAccount = null;
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
      if (!current() || !_gate.accepts(ticket, account.identity)) return;
      final shortcut = await service.resolveShortcut(
        imageBytes: bytes,
        idempotencyKey: newBioPayUuid(),
      );
      await _capture.stop();
      if (!current() || !_gate.accepts(ticket, account.identity)) return;
      setState(() {
        _shortcut = shortcut;
        _shortcutAccount = account;
      });
      final native = ref.read(paymentDiscoveryServiceProvider);
      if (native.deviceFamily != 'android') return;
      if (!current() ||
          !_gate.claim(ticket, account.identity, shortcut, DateTime.now())) {
        return;
      }
      final launched = await native.openReviewedInstruction({
        'mode': 'dial',
        'instruction': shortcut.ussdCode,
      });
      if (!current()) return;
      if (launched) {
        unawaited(
          service.recordHandoff(shortcut.requestId).catchError((Object _) {}),
        );
      }
      if (current() && _shortcut?.requestId == shortcut.requestId) {
        setState(() {
          _opened = launched;
          if (!launched) _error = const FaceServiceException('DIAL_FAILED');
        });
      }
    } on Object catch (error) {
      if (current()) setState(() => _error = error);
    } finally {
      bytes?.fillRange(0, bytes.length, 0);
      _gate.finish(ticket);
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
          if (!service.isCurrent(account)) {
            _shortcut = null;
            _shortcutAccount = null;
            _error = const FaceServiceException('AUTH_EXPIRED');
          }
        });
      }
    }
  }

  Future<void> _openAlternative(String route) async {
    if (_busy) return;
    final account = _viewAccount;
    final service = ref.read(biopayFaceServiceProvider);
    final generation = ++_generation;
    bool current() =>
        mounted &&
        generation == _generation &&
        account != null &&
        service.isCurrent(account);
    _gate.cancel();
    setState(() => _busy = true);
    try {
      await _capture.stop();
      if (!mounted || !current()) return;
      await context.push(route);
    } on Object catch (error) {
      if (current()) setState(() => _error = error);
    } finally {
      if (current()) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = paymentCopy(context);
    final renderedAccount = _viewAccount;
    final renderedGeneration = _generation;
    final service = ref.read(biopayFaceServiceProvider);
    bool renderedCurrent() =>
        mounted &&
        _foreground &&
        renderedGeneration == _generation &&
        renderedAccount != null &&
        service.isCurrent(renderedAccount);
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
              onPressed: _busy
                  ? null
                  : () {
                      if (renderedCurrent()) unawaited(_scan());
                    },
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
                  if (!renderedCurrent() || !identical(shortcut, _shortcut)) {
                    return;
                  }
                  final account = _shortcutAccount;
                  if (account == null || !service.isCurrent(account)) return;
                  if (!shortcut.isCurrent(DateTime.now())) {
                    setState(() {
                      _shortcut = null;
                      _error = const FaceServiceException('TIMEOUT');
                    });
                    return;
                  }
                  await RequestDeadline.mutation(
                    Clipboard.setData(ClipboardData(text: shortcut.ussdCode)),
                    operation: 'copy_face_ussd_shortcut',
                    timeout: const Duration(seconds: 5),
                  );
                  if (context.mounted &&
                      renderedCurrent() &&
                      service.isCurrent(account)) {
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
              onPressed: _busy
                  ? null
                  : () {
                      if (renderedCurrent()) {
                        unawaited(_openAlternative('/biopay/send'));
                      }
                    },
              child: Text(l.faceManual),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      if (renderedCurrent()) {
                        unawaited(_openAlternative('/biopay/scan'));
                      }
                    },
              child: Text(l.faceQr),
            ),
          ],
        ],
      ),
    );
  }
}
