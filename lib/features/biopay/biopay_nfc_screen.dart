import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/features/biopay/biopay_flow_shared.dart';
import 'package:mobi_app/features/biopay/biopay_nfc_foreground_listener.dart';
import 'package:mobi_app/features/biopay/models/biopay_ussd_payment.dart';
import 'package:ndef/ndef.dart' as ndef;

class BioPayNfcScreen extends ConsumerStatefulWidget {
  const BioPayNfcScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<BioPayNfcScreen> createState() => _BioPayNfcScreenState();
}

class _BioPayNfcScreenState extends ConsumerState<BioPayNfcScreen> {
  final TextEditingController _receiverNumberController =
      TextEditingController();
  final TextEditingController _receiverCodeController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  BioPayUssdPaymentRequest? _request;
  bool _receiverUsesCode = false;
  bool _busy = false;
  String? _error;
  String? _tagLabel;

  TextEditingController get _activeReceiverController =>
      _receiverUsesCode ? _receiverCodeController : _receiverNumberController;

  @override
  void initState() {
    super.initState();
    _hydrateDefaultReceiver();
  }

  @override
  void dispose() {
    _receiverNumberController.dispose();
    _receiverCodeController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _hydrateDefaultReceiver() async {
    if (SupabaseConfig.isLocalUiPreview) {
      _receiverNumberController.text = '0788123456';
      _receiverCodeController.text = '23456';
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
    setState(() {
      _request = null;
      _tagLabel = null;
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

  Future<void> _prepareTapTag() async {
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
      await _ensureNfcAvailable();
      final service = ref.read(biopayUssdServiceProvider);
      final amountMinor = optionalAmountMinorFromController(_amountController);
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
      final tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 20),
        iosAlertMessage: 'Hold near your NFC tag to receive payment',
      );
      if (tag.ndefWritable == false) {
        throw StateError('This NFC tag is not writable.');
      }
      await FlutterNfcKit.writeNDEFRecords([
        ndef.TextRecord(language: 'en', text: buildBioPayQrPayload(request)),
      ]);
      await FlutterNfcKit.finish(iosAlertMessage: 'BioPay token written');
      if (!mounted) return;
      setState(() {
        _request = request;
        _tagLabel = tag.id.isEmpty ? tag.standard : 'Tag ${tag.id}';
      });
    } on Object catch (error) {
      await _finishNfcWithError();
      if (!mounted) return;
      setState(
        () => _error = _nfcErrorLabel(
          error,
          fallback: 'Enter a valid RWF amount.',
        ),
      );
    } finally {
      ref
          .read(bioPayNfcForegroundSuspendedProvider.notifier)
          .setSuspended(false);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ensureNfcAvailable() async {
    final availability = await FlutterNfcKit.nfcAvailability;
    if (availability == NFCAvailability.available) return;
    if (availability == NFCAvailability.disabled) {
      throw StateError('NFC is disabled on this device.');
    }
    throw StateError('NFC is not supported on this device.');
  }

  Future<void> _finishNfcWithError() async {
    try {
      await FlutterNfcKit.finish(iosErrorMessage: 'BioPay NFC failed');
    } on Object {
      // Session may not have started.
    }
  }

  String _nfcErrorLabel(
    Object error, {
    String fallback = 'NFC request unavailable.',
  }) {
    final message = error.toString();
    if (message.contains('amount')) return fallback;
    if (message.contains('receiver_required')) {
      return 'Enter a MoMo number or MoMo Pay code.';
    }
    if (message.contains('disabled')) return 'NFC is disabled.';
    if (message.contains('not supported')) return 'NFC is not supported.';
    if (message.contains('not writable')) return 'NFC tag is not writable.';
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return BioPayFlowScreen(
      title: 'NFC',
      primaryLabel: _request == null ? 'Activate NFC' : 'NFC Active',
      isPrimaryLoading: _busy,
      onBack: widget.onBack,
      onPrimary: _request == null ? _prepareTapTag : null,
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
                _tagLabel = null;
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
          if (_request != null)
            BioPayResolvedPaymentPreview(request: _request!),
          if (_tagLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            BioPayDetailRow(label: 'NFC', value: _tagLabel!),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            BioPayInlineError(message: _error!),
          ],
        ],
      ),
    );
  }
}
