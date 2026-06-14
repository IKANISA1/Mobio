import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/features/biopay/biopay_flow_shared.dart';
import 'package:mobi_app/features/biopay/biopay_qr_export.dart';
import 'package:mobi_app/features/biopay/models/biopay_ussd_payment.dart';

class BioPayQrScreen extends ConsumerStatefulWidget {
  const BioPayQrScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<BioPayQrScreen> createState() => _BioPayQrScreenState();
}

class _BioPayQrScreenState extends ConsumerState<BioPayQrScreen> {
  final TextEditingController _receiverNumberController =
      TextEditingController();
  final TextEditingController _receiverCodeController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final GlobalKey _qrBoundaryKey = GlobalKey();
  BioPayUssdPaymentRequest? _request;
  bool _creating = false;
  bool _saving = false;
  bool _sharing = false;
  bool _receiverUsesCode = false;
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
    _receiverNumberController.dispose();
    _receiverCodeController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _hydrateDefaultReceiver() async {
    if (SupabaseConfig.isLocalUiPreview) {
      _receiverNumberController.text = '0788767816';
      _receiverCodeController.text = '123456';
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
      _error = null;
      _saving = false;
      _sharing = false;
    });
  }

  String _qrFileName() {
    final suffix = DateTime.now().millisecondsSinceEpoch;
    return 'mobio-biopay-qr-$suffix.png';
  }

  Future<Uint8List> _captureQrPng() async {
    final renderObject = _qrBoundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('qr_not_ready');
    }

    final image = await renderObject.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) throw StateError('qr_export_failed');
    return byteData.buffer.asUint8List();
  }

  void _showQrActionMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveQrCode() async {
    if (_request == null || _saving) return;
    setState(() => _saving = true);
    try {
      final saved = await saveBioPayQrPng(
        await _captureQrPng(),
        fileName: _qrFileName(),
      );
      _showQrActionMessage(
        saved
            ? 'QR code saved.'
            : 'Saving QR images is not available on this device yet.',
      );
    } on Object {
      _showQrActionMessage('Unable to save this QR code.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _shareQrCode() async {
    if (_request == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      final shared = await shareBioPayQrPng(
        await _captureQrPng(),
        fileName: _qrFileName(),
      );
      _showQrActionMessage(
        shared
            ? 'QR code ready to share.'
            : 'Sharing QR images is not available on this device yet.',
      );
    } on Object {
      _showQrActionMessage('Unable to share this QR code.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
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

  Future<void> _createRequest() async {
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final service = ref.read(biopayUssdServiceProvider);
      final receiver = momoReceiverForRequest(
        _activeReceiverController.text,
        usesCode: _receiverUsesCode,
      );
      if (receiver.isEmpty) {
        throw const FormatException('receiver_required');
      }
      final amountMinor = optionalAmountMinorFromController(_amountController);
      final request = SupabaseConfig.isConfigured
          ? await service.createPaymentRequest(
              channel: BioPayRequestChannel.qr,
              amountMinor: amountMinor,
              payeeLabel: 'MoMo receiver',
              payeePhone: receiver,
            )
          : service.createPreviewRequest(
              channel: BioPayRequestChannel.qr,
              amountMinor: amountMinor,
              payeeLabel: 'MoMo receiver',
              payeePhone: receiver,
            );
      if (!mounted) return;
      setState(() {
        _request = request;
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Enter a MoMo number or MoMo Pay code.';
      });
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BioPayFlowScreen(
      title: 'QR',
      primaryLabel: _request == null ? 'Generate QR Code' : '',
      isPrimaryLoading: _creating,
      onBack: widget.onBack,
      onPrimary: _createRequest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: AppSpacing.md),
          if (_request != null) ...[
            BioPayQrPreview(request: _request!, boundaryKey: _qrBoundaryKey),
            const SizedBox(height: AppSpacing.md),
            BioPayQrActions(
              isSaving: _saving,
              isSharing: _sharing,
              onSave: _saveQrCode,
              onShare: _shareQrCode,
            ),
            const SizedBox(height: AppSpacing.md),
            BioPayDetailRow(
              label: 'Receiver',
              value: _activeReceiverController.text,
            ),
            BioPayDetailRow(label: 'Amount', value: _request!.amountLabel),
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
