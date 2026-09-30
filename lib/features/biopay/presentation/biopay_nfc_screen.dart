import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/core/utils/money_formatting.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/data/biopay_device_nfc_service.dart';
import 'package:mobi_app/features/biopay/domain/biopay_ussd_payment.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_flow_shared.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_nfc_foreground_listener.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';

class BioPayNfcScreen extends ConsumerStatefulWidget {
  const BioPayNfcScreen({
    super.key,
    required this.onBack,
    this.deviceNfcService = const BioPayDeviceNfcService(),
  }) : _captureOverride = null,
       _isCurrentOverride = null;
  @visibleForTesting
  const BioPayNfcScreen.test({
    super.key,
    required this.onBack,
    required AccountSnapshot Function() captureAccount,
    required bool Function(AccountSnapshot) isCurrent,
    this.deviceNfcService = const BioPayDeviceNfcService(),
  }) : _captureOverride = captureAccount,
       _isCurrentOverride = isCurrent;
  final BioPayDeviceNfcService deviceNfcService;
  final AccountSnapshot Function()? _captureOverride;
  final bool Function(AccountSnapshot)? _isCurrentOverride;

  final VoidCallback onBack;

  @override
  ConsumerState<BioPayNfcScreen> createState() => _BioPayNfcScreenState();
}

class _BioPayNfcScreenState extends ConsumerState<BioPayNfcScreen> {
  BioPayDeviceNfcService get _deviceNfcService => widget.deviceNfcService;
  late final BioPayNfcForegroundSuspendedNotifier _foreground;
  AccountSnapshot? _viewAccount;
  int _revision = 0;
  int? _suspension;
  bool _accountLost = false;
  bool _current(AccountSnapshot? account, int revision) =>
      mounted &&
      !_accountLost &&
      revision == _revision &&
      (account == null
          ? SupabaseConfig.isLocalUiPreview && widget._captureOverride == null
          : widget._isCurrentOverride?.call(account) ??
                AccountContext.isCurrent(account));
  void _release(int lease) {
    if (_suspension == lease) _suspension = null;
    _foreground.releaseSuspension(lease);
  }

  Future<void> _stopOwned(int? lease) async {
    if (lease == null || !_foreground.ownsSuspension(lease)) return;
    try {
      await _deviceNfcService.stop(
        canDispatch: () => _foreground.isCurrentSuspensionLease(lease),
      );
    } on Object catch (error, stackTrace) {
      AppLogger.warning(
        'Device NFC cleanup is unconfirmed.',
        context: 'BioPayDeviceNfc',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _release(lease);
    }
  }

  void _accountChanged() {
    if (_accountLost || _current(_viewAccount, _revision)) return;
    _revision++;
    _accountLost = true;
    _receiverNumberController.clear();
    _receiverCodeController.clear();
    _amountController.clear();
    setState(() {
      _request = null;
      _busy = false;
      _error = 'Sign in again to continue.';
    });
    unawaited(_stopOwned(_suspension));
  }

  final TextEditingController _receiverNumberController =
      TextEditingController();
  final TextEditingController _receiverCodeController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(
    text: formatWholeAmount(1500),
  );
  BioPayUssdPaymentRequest? _request;
  bool _receiverUsesCode = false;
  bool _busy = false;
  String? _error;

  TextEditingController get _activeReceiverController =>
      _receiverUsesCode ? _receiverCodeController : _receiverNumberController;

  @override
  void initState() {
    super.initState();
    _foreground = ref.read(bioPayNfcForegroundSuspendedProvider.notifier);
    try {
      _viewAccount =
          widget._captureOverride?.call() ??
          (SupabaseConfig.isLocalUiPreview ? null : AccountContext.capture());
    } on Object {
      _accountLost = true;
      _error = 'Sign in again to continue.';
    }
    AccountContext.changes.addListener(_accountChanged);
    unawaited(_hydrateDefaultReceiver());
  }

  @override
  void dispose() {
    _revision++;
    AccountContext.changes.removeListener(_accountChanged);
    unawaited(_stopOwned(_suspension));
    _receiverNumberController.dispose();
    _receiverCodeController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _hydrateDefaultReceiver() async {
    final account = _viewAccount;
    final revision = _revision;
    if (!_current(account, revision)) return;
    if (SupabaseConfig.isLocalUiPreview && widget._captureOverride == null) {
      _receiverNumberController.text = '0788123456';
      _receiverCodeController.text = '23456';
      if (mounted) setState(() {});
      return;
    }

    if (!SupabaseConfig.isConfigured && widget._captureOverride == null) return;

    final profile = await ref
        .read(profileServiceProvider)
        .getMyProfile()
        .catchError((Object _) => null);
    final momoNumber = profile?.momoNumber?.trim() ?? '';
    final momoPayCode = profile?.momoPayCode?.trim() ?? '';
    final whatsapp = profile?.whatsapp?.trim() ?? '';
    final phone = profile?.phone?.trim() ?? '';
    final receiver = momoNumber.isNotEmpty
        ? momoNumber
        : whatsapp.isNotEmpty
        ? whatsapp
        : phone;
    if (!_current(account, revision)) return;

    if (receiver.isNotEmpty && _receiverNumberController.text.trim().isEmpty) {
      _receiverNumberController.text = momoReceiverDisplay(receiver);
    }

    if (momoPayCode.isNotEmpty && _receiverCodeController.text.trim().isEmpty) {
      _receiverCodeController.text = momoPayCodeDisplay(momoPayCode);
    }

    setState(() {});
  }

  void _resetRequest() {
    if (!_current(_viewAccount, _revision)) return;
    _revision++;
    unawaited(_stopOwned(_suspension));
    setState(() {
      _request = null;
      _error = null;
    });
  }

  void _onReceiverChanged(String value) {
    if (!_current(_viewAccount, _revision)) return;
    if (!_receiverUsesCode) {
      final display = momoReceiverDisplay(value);
      if (display != value) {
        _receiverNumberController.value = TextEditingValue(
          text: display,
          selection: TextSelection.collapsed(offset: display.length),
        );
      }
    }
    _resetRequest();
  }

  bool get _hasValidReceiver {
    return isValidMomoReceiver(
      _activeReceiverController.text,
      usesCode: _receiverUsesCode,
    );
  }

  bool get _hasValidAmount {
    final digits = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amountMajor = int.tryParse(digits);
    return amountMajor != null && amountMajor > 0;
  }

  bool get _canActivateDeviceNfc {
    return _current(_viewAccount, _revision) &&
        !_busy &&
        _request == null &&
        _hasValidReceiver &&
        _hasValidAmount;
  }

  Future<void> _activateDeviceNfc() async {
    final account = _viewAccount;
    if (!_current(account, _revision) || !_canActivateDeviceNfc) return;
    final revision = ++_revision;
    final lease = _suspension = _foreground.acquireSuspension();
    bool current() =>
        _current(account, revision) && _foreground.ownsSuspension(lease);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receiver = momoReceiverForRequest(
        _activeReceiverController.text,
        usesCode: _receiverUsesCode,
      );
      if (receiver.isEmpty) {
        throw const FormatException('receiver_required');
      }
      final amountMinor = amountMinorFromController(_amountController);
      final service = ref.read(biopayUssdServiceProvider);
      final request =
          (SupabaseConfig.isConfigured || widget._captureOverride != null)
          ? await service.createPaymentRequest(
              channel: BioPayRequestChannel.nfc,
              amountMinor: amountMinor,
              payeeLabel: 'MoMo receiver',
              payeePhone: receiver,
            )
          : service.createPreviewRequest(
              channel: BioPayRequestChannel.nfc,
              amountMinor: amountMinor,
              payeeLabel: 'MoMo receiver',
              payeePhone: receiver,
            );
      if (!current()) return;
      final status = kIsWeb && SupabaseConfig.isLocalUiPreview
          ? BioPayDeviceNfcStatus(
              supported: true,
              enabled: true,
              token: request.token,
              expiresAt: request.expiresAt,
            )
          : await _deviceNfcService.startPaymentRequest(
              request,
              canDispatch: current,
            );
      if (!current()) return;
      if (!status.supported) {
        throw StateError(status.reason ?? 'Device NFC is not supported.');
      }
      if (!status.canAdvertise) {
        throw StateError(status.reason ?? 'Device NFC is not active.');
      }
      if (!current()) return;
      setState(() {
        _request = request;
      });
    } on Object catch (error, stackTrace) {
      if (!current()) return;
      await _stopOwned(lease);
      AppLogger.warning(
        'Device NFC activation failed: $error',
        context: 'BioPayDeviceNfc',
        error: error,
        stackTrace: stackTrace,
      );
      if (!_current(account, revision)) return;
      setState(
        () => _error = _deviceNfcErrorLabel(
          error,
          fallback: 'Device NFC activation failed. Check NFC and try again.',
        ),
      );
    } finally {
      if (_current(account, revision)) setState(() => _busy = false);
    }
  }

  String _deviceNfcErrorLabel(
    Object error, {
    String fallback = 'NFC request unavailable.',
  }) {
    final message = error.toString().toLowerCase();
    if (message.contains('amount')) return 'Enter a valid RWF amount.';
    if (message.contains('receiver_required')) {
      return 'Enter a MoMo number or MoMo Pay code.';
    }
    if (message.contains('disabled')) return 'NFC is disabled.';
    if (message.contains('hce') || message.contains('not supported')) {
      return 'Device NFC receive is Android-only on phones with HCE support.';
    }
    if (message.contains('supabase') || message.contains('rpc')) {
      return 'Unable to create the NFC payment request. Check connection and try again.';
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final account = _viewAccount;
    final revision = _revision;
    bool current() => _current(account, revision);
    return BioPayFlowScreen(
      title: 'Device NFC',
      primaryLabel: _request == null ? 'Activate Device NFC' : '',
      isPrimaryLoading: _busy,
      onBack: widget.onBack,
      onPrimary: _canActivateDeviceNfc
          ? () {
              if (current()) unawaited(_activateDeviceNfc());
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_request == null && !_accountLost) ...[
            BioPayReceiverField(
              controller: _activeReceiverController,
              enabled: _request == null && !_busy,
              usesCode: _receiverUsesCode,
              onModeChanged: (usesCode) {
                if (!current()) return;
                setState(() {
                  _receiverUsesCode = usesCode;
                });
                _resetRequest();
              },
              onChanged: (value) {
                if (current()) _onReceiverChanged(value);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            BioPayReceiveAmountField(
              controller: _amountController,
              enabled: _request == null && !_busy,
              onChanged: (_) {
                if (current()) _resetRequest();
              },
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          if (_request != null) _DeviceNfcListeningView(request: _request!),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            BioPayInlineError(message: _error!),
          ],
        ],
      ),
    );
  }
}

class _DeviceNfcListeningView extends StatefulWidget {
  const _DeviceNfcListeningView({required this.request});

  final BioPayUssdPaymentRequest request;

  @override
  State<_DeviceNfcListeningView> createState() =>
      _DeviceNfcListeningViewState();
}

class _DeviceNfcListeningViewState extends State<_DeviceNfcListeningView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: AppSpacing.lg),
        SizedBox.square(
          dimension: 250,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  for (var index = 0; index < 3; index++)
                    _NfcPulseRing(
                      progress: (_controller.value + index / 3) % 1,
                    ),
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [cs.primary, cs.secondary],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.36),
                          blurRadius: 34,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.nfc,
                      color: Colors.white,
                      size: 58,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Listening',
          textAlign: TextAlign.center,
          style: AppTypography.headlineLg.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          widget.request.amountLabel,
          textAlign: TextAlign.center,
          style: AppTypography.titleMd.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _NfcPulseRing extends StatelessWidget {
  const _NfcPulseRing({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scale = 0.48 + progress * 0.62;
    final opacity = (1 - progress).clamp(0.0, 1.0);

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity * 0.52,
        child: Container(
          width: 228,
          height: 228,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: cs.primary.withValues(alpha: 0.9),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}
