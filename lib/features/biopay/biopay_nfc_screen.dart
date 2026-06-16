import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/core/utils/money_formatting.dart';
import 'package:mobi_app/features/biopay/biopay_device_nfc_service.dart';
import 'package:mobi_app/features/biopay/biopay_flow_shared.dart';
import 'package:mobi_app/features/biopay/biopay_nfc_foreground_listener.dart';
import 'package:mobi_app/features/biopay/models/biopay_ussd_payment.dart';

class BioPayNfcScreen extends ConsumerStatefulWidget {
  const BioPayNfcScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<BioPayNfcScreen> createState() => _BioPayNfcScreenState();
}

class _BioPayNfcScreenState extends ConsumerState<BioPayNfcScreen> {
  static const _deviceNfcService = BioPayDeviceNfcService();

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
    _hydrateDefaultReceiver();
  }

  @override
  void dispose() {
    if (_request != null) {
      ref
          .read(bioPayNfcForegroundSuspendedProvider.notifier)
          .setSuspended(true);
    }
    _receiverNumberController.dispose();
    _receiverCodeController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _hydrateDefaultReceiver() async {
    if (SupabaseConfig.isLocalUiPreview) {
      _receiverNumberController.text = '0788123456';
      _receiverCodeController.text = '23456';
      if (mounted) setState(() {});
      return;
    }

    if (!SupabaseConfig.isConfigured) return;

    final profile = await ref.read(profileServiceProvider).getMyProfile();
    final momoNumber = profile?.momoNumber?.trim() ?? '';
    final momoPayCode = profile?.momoPayCode?.trim() ?? '';
    final whatsapp = profile?.whatsapp?.trim() ?? '';
    final phone = profile?.phone?.trim() ?? '';
    final receiver = momoNumber.isNotEmpty
        ? momoNumber
        : whatsapp.isNotEmpty
        ? whatsapp
        : phone;
    if (!mounted) return;

    if (receiver.isNotEmpty && _receiverNumberController.text.trim().isEmpty) {
      _receiverNumberController.text = momoReceiverDisplay(receiver);
    }

    if (momoPayCode.isNotEmpty && _receiverCodeController.text.trim().isEmpty) {
      _receiverCodeController.text = momoPayCodeDisplay(momoPayCode);
    }

    setState(() {});
  }

  void _resetRequest() {
    if (_request != null) {
      unawaited(_deviceNfcService.stop());
      ref
          .read(bioPayNfcForegroundSuspendedProvider.notifier)
          .setSuspended(false);
    }
    setState(() {
      _request = null;
      _error = null;
    });
  }

  void _onReceiverChanged(String value) {
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
    return !_busy && _request == null && _hasValidReceiver && _hasValidAmount;
  }

  Future<void> _activateDeviceNfc() async {
    ref.read(bioPayNfcForegroundSuspendedProvider.notifier).setSuspended(true);
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
      final request = SupabaseConfig.isConfigured
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
      final status = kIsWeb && SupabaseConfig.isLocalUiPreview
          ? BioPayDeviceNfcStatus(
              supported: true,
              enabled: true,
              token: request.token,
              expiresAt: request.expiresAt,
            )
          : await _deviceNfcService.startPaymentRequest(request);
      if (!status.supported) {
        throw StateError(status.reason ?? 'Device NFC is not supported.');
      }
      if (!status.canAdvertise) {
        throw StateError(status.reason ?? 'Device NFC is not active.');
      }
      if (!mounted) return;
      setState(() {
        _request = request;
      });
    } on Object catch (error, stackTrace) {
      unawaited(_deviceNfcService.stop());
      ref
          .read(bioPayNfcForegroundSuspendedProvider.notifier)
          .setSuspended(false);
      AppLogger.warning(
        'Device NFC activation failed: $error',
        context: 'BioPayDeviceNfc',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(
        () => _error = _deviceNfcErrorLabel(
          error,
          fallback: 'Device NFC activation failed. Check NFC and try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
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
    return BioPayFlowScreen(
      title: 'Device NFC',
      primaryLabel: _request == null ? 'Activate Device NFC' : '',
      isPrimaryLoading: _busy,
      onBack: widget.onBack,
      onPrimary: _canActivateDeviceNfc ? _activateDeviceNfc : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_request == null) ...[
            BioPayReceiverField(
              controller: _activeReceiverController,
              enabled: _request == null,
              usesCode: _receiverUsesCode,
              onModeChanged: (usesCode) => setState(() {
                _receiverUsesCode = usesCode;
                _request = null;
                _error = null;
              }),
              onChanged: _onReceiverChanged,
            ),
            const SizedBox(height: AppSpacing.md),
            BioPayReceiveAmountField(
              controller: _amountController,
              enabled: _request == null,
              onChanged: (_) => _resetRequest(),
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
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          widget.request.amountLabel,
          textAlign: TextAlign.center,
          style: AppTypography.titleMd.copyWith(
            color: Colors.white.withValues(alpha: 0.78),
            fontWeight: FontWeight.w800,
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
