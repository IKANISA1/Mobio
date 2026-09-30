import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/data/biopay_face_service.dart';
import 'package:mobi_app/features/biopay/data/face_capture.dart';
import 'package:mobi_app/features/biopay/data/payment_discovery_service.dart';
import 'package:mobi_app/features/biopay/domain/payment_discovery.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_flow_shared.dart';
import 'package:mobi_app/features/biopay/presentation/face_copy.dart';
import 'package:mobi_app/features/biopay/presentation/payment_widgets.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';

class BioPayFaceEnrollScreen extends ConsumerStatefulWidget {
  const BioPayFaceEnrollScreen({super.key, required this.onBack});
  final VoidCallback onBack;
  @override
  ConsumerState<BioPayFaceEnrollScreen> createState() =>
      _BioPayFaceEnrollScreenState();
}

class _BioPayFaceEnrollScreenState extends ConsumerState<BioPayFaceEnrollScreen>
    with WidgetsBindingObserver {
  late final FaceCapture _capture;
  BioPayEnrollmentStatus _status = const BioPayEnrollmentStatus();
  List<PaymentMethod> _methods = [];
  String? _methodId;
  Object? _error;
  bool _busy = false, _consent = false, _foreground = true;
  int _generation = 0;
  Timer? _poll;
  @override
  void initState() {
    super.initState();
    _capture = ref.read(faceCaptureFactoryProvider)();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    _generation++;
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_capture.stop().catchError((Object _) {}));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _generation++;
      _poll?.cancel();
      unawaited(_capture.stop().catchError((Object _) {}));
      if (mounted) setState(() => _busy = false);
    }
    // Returning requires an explicit capture/status action; never recapture.
  }

  Future<void> _load() async {
    if (_busy || !_foreground) return;
    final generation = ++_generation;
    final face = ref.read(biopayFaceServiceProvider);
    final owner = face.ownerId;
    setState(() => _busy = true);
    try {
      final status = await face.enrollmentStatus();
      if (face.ownerId != owner) return;
      final methods =
          workspaceMethods(
                await ref
                    .read(paymentDiscoveryServiceProvider)
                    .call('workspace', {}),
              )
              .where(
                (m) =>
                    m.active &&
                    m.canReceive &&
                    m.kind == PaymentMethodKind.mobileWallet,
              )
              .toList();
      if (!mounted || generation != _generation || face.ownerId != owner) {
        return;
      }
      setState(() {
        _status = status;
        _methods = methods;
        _methodId = methods.any((m) => m.id == status.receivingMethodId)
            ? status.receivingMethodId
            : null;
        _error = null;
      });
      _poll?.cancel();
      if (status.pending) {
        _poll = Timer(const Duration(seconds: 3), () => unawaited(_load()));
      }
    } on Object catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _status = const BioPayEnrollmentStatus();
          _methods = [];
          _methodId = null;
          _error = error;
        });
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _action(Future<void> Function() action) async {
    if (_busy) return;
    final generation = ++_generation;
    var succeeded = false;
    setState(() => _busy = true);
    try {
      await action();
      succeeded = true;
      if (mounted && generation == _generation) setState(() => _error = null);
    } on Object catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = error;
          _methodId = _status.receivingMethodId;
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
        if (succeeded) await _load();
      }
    }
  }

  Future<void> _captureFace() async {
    if (_busy ||
        !_foreground ||
        _status.isUnavailable ||
        !_consent ||
        _methodId == null)
      return;
    final service = ref.read(biopayFaceServiceProvider);
    final account = service.ownerId;
    if (account == null) {
      setState(() => _error = const FaceServiceException('AUTH_EXPIRED'));
      return;
    }
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    Uint8List? bytes;
    bool submitted = false;
    bool current() =>
        mounted &&
        _foreground &&
        generation == _generation &&
        service.ownerId == account;
    try {
      if (!_capture.isReady) {
        await _capture.start(front: true);
        return;
      }
      bytes = await _capture.capture();
      await _capture.stop();
      if (!current()) return;
      final result = await service.enrollFace(
        imageBytes: bytes,
        methodId: _methodId!,
        idempotencyKey: newBioPayUuid(),
        consent: _consent,
      );
      if (!current()) return;
      submitted = true;
      setState(() {
        _status = BioPayEnrollmentStatus(
          status: result,
          hasFace: result == 'active',
          pending: result == 'processing',
          receivingMethodId: _methodId,
        );
        _consent = false;
      });
    } on Object catch (error) {
      if (current()) setState(() => _error = error);
    } finally {
      bytes?.fillRange(0, bytes.length, 0);
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
        if (submitted) await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = paymentCopy(context);
    final camera = _capture.controller;
    final ready = camera?.value.isInitialized == true;
    return BioPayFlowScreen(
      title: l.faceRegister,
      primaryLabel: '',
      onBack: widget.onBack,
      headerSpacing: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_status.status != 'not_started') ...[
            Semantics(
              liveRegion: true,
              child: Text(faceStatusCopy(context, _status)),
            ),
            const SizedBox(height: 20),
          ],
          DropdownButtonFormField<String>(
            key: ValueKey(_methodId),
            initialValue: _methodId,
            isExpanded: true,
            icon: const Icon(LucideIcons.chevronDown),
            decoration: InputDecoration(labelText: l.faceReceivingMethod),
            items: _methods
                .map(
                  (m) => DropdownMenuItem(
                    value: m.id,
                    child: Text(
                      '${m.label} · ${m.maskedIdentifier}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (id) {
                    setState(() => _methodId = id);
                    if (id != null && _status.hasFace) {
                      unawaited(
                        _action(
                          () => ref
                              .read(biopayFaceServiceProvider)
                              .changeMethod(id),
                        ),
                      );
                    }
                  },
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    _generation++;
                    _poll?.cancel();
                    setState(() => _busy = true);
                    try {
                      await _capture.stop();
                      if (!context.mounted) return;
                      await context.push('/profile/payment-methods');
                      if (!mounted) return;
                      setState(() => _busy = false);
                      await _load();
                    } on Object catch (error) {
                      if (mounted) setState(() => _error = error);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: Text(l.faceManageMethods),
          ),
          const SizedBox(height: 8),
          if (!_status.pending) ...[
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _consent,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _consent = value ?? false),
                title: Text(l.faceConsent),
              ),
            ),
            const SizedBox(height: 16),
            Text(l.faceRegisterInstruction),
            const SizedBox(height: 12),
            if (ready)
              BioPayCameraFrame(
                controller: camera!,
                height: 260,
                showFaceGuide: true,
              )
            else
              BioPayFaceEnrollmentStandby(
                iconColor: Theme.of(context).colorScheme.primary,
                height: 260,
                guideSize: const Size(138, 188),
              ),
            const SizedBox(height: 20),
            MobiButton(
              onPressed:
                  _busy ||
                      _status.isUnavailable ||
                      !_consent ||
                      _methodId == null
                  ? null
                  : _captureFace,
              isLoading: _busy,
              child: Text(
                _capture.isReady
                    ? l.faceCapture
                    : _status.hasFace
                    ? l.faceUpdate
                    : l.faceStartCamera,
              ),
            ),
          ],
          if (_status.hasFace) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _action(
                      () => ref
                          .read(biopayFaceServiceProvider)
                          .setEnrollmentAction(
                            _status.status == 'paused' ? 'resume' : 'pause',
                          ),
                    ),
              child: Text(
                _status.status == 'paused' ? l.faceResume : l.facePause,
              ),
            ),
          ],
          if (_status.hasFace || _status.pending)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _action(
                      () => ref
                          .read(biopayFaceServiceProvider)
                          .setEnrollmentAction('remove'),
                    ),
              child: Text(l.faceRemove),
            ),
          if (_status.pending || _error != null)
            TextButton(
              onPressed: _busy ? null : _load,
              child: Text(l.faceRefresh),
            ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: BioPayInlineError(
                message: faceErrorCopy(context, _error!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
