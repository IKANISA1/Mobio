import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/auth/account_context.dart';
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
  BioPayEnrollmentStatus? _confirmedStatus;
  AccountSnapshot? _confirmedAccount;
  List<PaymentMethod> _methods = [];
  String? _methodId;
  Object? _error;
  bool _busy = false, _consent = false, _foreground = true;
  int _generation = 0;
  AccountSnapshot? _viewAccount;
  Timer? _poll;
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
    unawaited(_load());
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
    _poll?.cancel();
    unawaited(_capture.stop().catchError((Object _) {}));
    setState(() {
      _busy = false;
      _consent = false;
      _status = const BioPayEnrollmentStatus(status: 'unavailable');
      _confirmedStatus = null;
      _confirmedAccount = null;
      _methods = [];
      _methodId = null;
      _error = const FaceServiceException('AUTH_EXPIRED');
    });
  }

  @override
  void dispose() {
    _generation++;
    _poll?.cancel();
    AccountContext.changes.removeListener(_onAccountChanged);
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
    AccountSnapshot account;
    try {
      account = face.captureAccount();
    } on Object {
      setState(() => _error = const FaceServiceException('AUTH_EXPIRED'));
      return;
    }
    bool current() =>
        mounted &&
        _foreground &&
        generation == _generation &&
        face.isCurrent(account);
    setState(() => _busy = true);
    try {
      final status = await face.enrollmentStatus();
      if (!current()) return;
      if (!status.isUnavailable) {
        _confirmedStatus = status;
        _confirmedAccount = account;
      }
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
      if (!current()) {
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
      if (current()) {
        setState(() {
          _status = const BioPayEnrollmentStatus();
          _methods = [];
          _methodId = null;
          _error = error;
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
          if (!face.isCurrent(account)) {
            _status = const BioPayEnrollmentStatus();
            _methods = [];
            _methodId = null;
            _error = const FaceServiceException('AUTH_EXPIRED');
          }
        });
      }
    }
  }

  Future<void> _action(
    Future<void> Function() action, {
    String? enrollmentAction,
  }) async {
    if (_busy) return;
    final generation = ++_generation;
    final face = ref.read(biopayFaceServiceProvider);
    AccountSnapshot account;
    try {
      account = face.captureAccount();
    } on Object {
      return;
    }
    bool current() =>
        mounted &&
        _foreground &&
        generation == _generation &&
        face.isCurrent(account);
    var succeeded = false;
    setState(() => _busy = true);
    try {
      await action();
      succeeded = true;
      if (current()) {
        // The management acknowledgement confirms a new state even when the
        // subsequent status refresh fails. Never revive an older active cache
        // after confirmed removal, or offer pause after confirmed pause.
        final prior =
            _confirmedAccount != null && face.isCurrent(_confirmedAccount!)
            ? _confirmedStatus
            : null;
        if (enrollmentAction != null && prior != null) {
          _confirmedAccount = account;
          _confirmedStatus = BioPayEnrollmentStatus(
            status: switch (enrollmentAction) {
              'remove' => 'deleted',
              'pause' => 'paused',
              'resume' => 'active',
              _ => prior.status,
            },
            receivingMethodId: enrollmentAction == 'remove'
                ? null
                : prior.receivingMethodId,
            hasFace: enrollmentAction != 'remove' && prior.hasFace,
            pending: enrollmentAction == 'resume' && prior.pending,
          );
        }
        setState(() => _error = null);
      }
    } on Object catch (error) {
      if (current()) {
        setState(() {
          _error = error;
          _methodId = _status.receivingMethodId;
          if (error is FaceServiceException &&
              error.code == 'OUTCOME_UNKNOWN') {
            _status = const BioPayEnrollmentStatus();
          }
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
        if (current() && succeeded) await _load();
      }
    }
  }

  Future<void> _captureFace() async {
    if (_busy ||
        !_foreground ||
        _status.isUnavailable ||
        !_consent ||
        _methodId == null) {
      return;
    }
    final service = ref.read(biopayFaceServiceProvider);
    AccountSnapshot account;
    try {
      account = service.captureAccount();
    } on Object {
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
        service.isCurrent(account);
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
        if (result == 'active') {
          // This acknowledgement confirms enrollment for the captured account.
          // Keep recovery available if the next status read is unavailable;
          // the fresh status still determines current readiness.
          _confirmedStatus = _status;
          _confirmedAccount = account;
        }
        _consent = false;
      });
    } on Object catch (error) {
      if (current()) {
        setState(() {
          _error = error;
          if (error is FaceServiceException &&
              error.code == 'OUTCOME_UNKNOWN') {
            _status = const BioPayEnrollmentStatus();
          }
        });
      }
    } finally {
      bytes?.fillRange(0, bytes.length, 0);
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
        if (current() && submitted) await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = paymentCopy(context);
    final renderedAccount = _viewAccount;
    final renderedGeneration = _generation;
    final face = ref.read(biopayFaceServiceProvider);
    bool renderedCurrent() =>
        mounted &&
        _foreground &&
        renderedGeneration == _generation &&
        renderedAccount != null &&
        face.isCurrent(renderedAccount);
    final confirmed =
        _confirmedAccount != null && face.isCurrent(_confirmedAccount!)
        ? _confirmedStatus
        : null;
    // Cached confirmation permits recovery actions, never current-ready or
    // absent claims while the fresh status is unavailable.
    final recoveryStatus = _status.isUnavailable ? confirmed : _status;
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
              child: Text(
                _busy ? l.faceWorking : faceStatusCopy(context, _status),
              ),
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
                    if (!renderedCurrent()) return;
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
                    if (!renderedCurrent()) return;
                    final account = renderedAccount;
                    final service = ref.read(biopayFaceServiceProvider);
                    final generation = ++_generation;
                    bool current() =>
                        mounted &&
                        generation == _generation &&
                        account != null &&
                        service.isCurrent(account);
                    _poll?.cancel();
                    setState(() => _busy = true);
                    try {
                      await _capture.stop();
                      if (!context.mounted || !current()) return;
                      await context.push('/profile/payment-methods');
                      if (!current()) return;
                      setState(() => _busy = false);
                      await _load();
                    } on Object catch (error) {
                      if (current()) setState(() => _error = error);
                    } finally {
                      if (current()) setState(() => _busy = false);
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
                    : (value) {
                        if (renderedCurrent()) {
                          setState(() => _consent = value ?? false);
                        }
                      },
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
                  : () {
                      if (renderedCurrent()) unawaited(_captureFace());
                    },
              isLoading: _busy,
              child: Text(
                _capture.isReady
                    ? l.faceCapture
                    : recoveryStatus?.hasFace == true
                    ? l.faceUpdate
                    : l.faceStartCamera,
              ),
            ),
          ],
          if (recoveryStatus?.hasFace == true) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      if (!renderedCurrent()) return;
                      unawaited(
                        _action(
                          () => face.setEnrollmentAction(
                            recoveryStatus?.status == 'paused'
                                ? 'resume'
                                : 'pause',
                          ),
                          enrollmentAction: recoveryStatus?.status == 'paused'
                              ? 'resume'
                              : 'pause',
                        ),
                      );
                    },
              child: Text(
                recoveryStatus?.status == 'paused' ? l.faceResume : l.facePause,
              ),
            ),
          ],
          if (recoveryStatus?.hasFace == true || _status.pending)
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      if (renderedCurrent()) {
                        unawaited(
                          _action(
                            () => face.setEnrollmentAction('remove'),
                            enrollmentAction: 'remove',
                          ),
                        );
                      }
                    },
              child: Text(l.faceRemove),
            ),
          if (_status.pending || _error != null)
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      if (renderedCurrent()) unawaited(_load());
                    },
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
