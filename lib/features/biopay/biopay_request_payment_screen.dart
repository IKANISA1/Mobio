import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/features/biopay/biopay_flow_shared.dart';
import 'package:mobi_app/features/biopay/biopay_style.dart';
import 'package:mobi_app/features/biopay/models/biopay_ussd_payment.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class BioPayRequestPaymentScreen extends ConsumerStatefulWidget {
  const BioPayRequestPaymentScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<BioPayRequestPaymentScreen> createState() =>
      _BioPayRequestPaymentScreenState();
}

class _BioPayRequestPaymentScreenState
    extends ConsumerState<BioPayRequestPaymentScreen> {
  final TextEditingController _receiverNumberController =
      TextEditingController();
  final TextEditingController _receiverCodeController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  BioPayUssdPaymentRequest? _request;
  bool _creating = false;
  bool _sharing = false;
  bool _copying = false;
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
    setState(() {
      _request = null;
      _error = null;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

  bool get _canCreateRequest {
    return !_creating &&
        _request == null &&
        _hasValidReceiver &&
        _hasValidAmount;
  }

  String? get _validationHint {
    if (_request != null) return null;
    if (!_hasValidReceiver && !_hasValidAmount) {
      return _receiverUsesCode
          ? 'Enter a 5 or 6 digit MoMo Pay code and amount.'
          : 'Enter a valid MoMo number and amount.';
    }
    if (!_hasValidReceiver) {
      return _receiverUsesCode
          ? 'Enter a 5 or 6 digit MoMo Pay code.'
          : 'Enter a valid MoMo number.';
    }
    if (!_hasValidAmount) return 'Enter an amount greater than RWF 0.';
    return null;
  }

  String get _receiverLabel {
    final value = _activeReceiverController.text.trim();
    if (value.isEmpty) return '';
    return _receiverUsesCode ? 'MoMo Pay code $value' : 'MoMo number $value';
  }

  Future<void> _createRequest() async {
    setState(() {
      _creating = true;
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
      setState(() => _request = request);
    } on Object {
      if (!mounted) return;
      setState(() {
        _error = 'Enter a valid MoMo number or MoMo Pay code and amount.';
      });
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _shareOnWhatsApp() async {
    final request = _request;
    if (request == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      final service = ref.read(biopayUssdServiceProvider);
      final opened = await launchUrl(
        service.paymentRequestWhatsAppUri(
          request,
          receiverLabel: _receiverLabel,
        ),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        await SharePlus.instance.share(
          ShareParams(
            text: service.paymentRequestShareText(
              request,
              receiverLabel: _receiverLabel,
            ),
          ),
        );
      }
      _showMessage('MoMo USSD link ready to share.');
    } on Object {
      _showMessage('Unable to share this payment request.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _copyLink() async {
    final request = _request;
    if (request == null || _copying) return;
    setState(() => _copying = true);
    try {
      final link = ref
          .read(biopayUssdServiceProvider)
          .paymentRequestDialerUri(request)
          .toString();
      await Clipboard.setData(ClipboardData(text: link));
      _showMessage('MoMo USSD link copied.');
    } on Object {
      _showMessage('Unable to copy this MoMo USSD link.');
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    final validationHint = _validationHint;
    return BioPayFlowScreen(
      title: 'Request Payment',
      primaryLabel: request == null ? 'Generate USSD link' : '',
      isPrimaryLoading: _creating,
      onBack: widget.onBack,
      onPrimary: _canCreateRequest ? _createRequest : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BioPayReceiverField(
            controller: _activeReceiverController,
            enabled: request == null,
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
            enabled: request == null,
            onChanged: (_) => _resetRequest(),
          ),
          if (validationHint != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              validationHint,
              textAlign: TextAlign.center,
              style: AppTypography.labelMd.copyWith(
                color: Colors.white.withValues(alpha: 0.58),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (request != null) ...[
            const SizedBox(height: AppSpacing.md),
            _PaymentLinkPanel(
              request: request,
              receiverLabel: _receiverLabel,
              link: ref
                  .read(biopayUssdServiceProvider)
                  .paymentRequestDialerUri(request)
                  .toString(),
              isSharing: _sharing,
              isCopying: _copying,
              onShare: _shareOnWhatsApp,
              onCopy: _copyLink,
            ),
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

class _PaymentLinkPanel extends StatelessWidget {
  const _PaymentLinkPanel({
    required this.request,
    required this.receiverLabel,
    required this.link,
    required this.isSharing,
    required this.isCopying,
    required this.onShare,
    required this.onCopy,
  });

  final BioPayUssdPaymentRequest request;
  final String receiverLabel;
  final String link;
  final bool isSharing;
  final bool isCopying;
  final VoidCallback onShare;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bioPayDarkPanel.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const BioPayIconBox(
                  icon: LucideIcons.link,
                  color: bioPayBlue,
                  background: Colors.white,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MoMo USSD link ready',
                        style: AppTypography.titleMd.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            BioPayDetailRow(label: 'Receiver', value: receiverLabel),
            BioPayDetailRow(label: 'Amount', value: request.amountLabel),
            BioPayDetailRow(label: 'Reference', value: request.reference),
            const SizedBox(height: AppSpacing.md),
            SelectableText(
              link,
              style: AppTypography.bodySm.copyWith(
                color: Colors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: MobiButton(
                    onPressed: isSharing ? null : onShare,
                    isLoading: isSharing,
                    child: const Text('Share on WhatsApp'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: MobiButton(
                    onPressed: isCopying ? null : onCopy,
                    isLoading: isCopying,
                    child: const Text('Copy USSD link'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
