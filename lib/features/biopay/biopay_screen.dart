import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/utils/money_formatting.dart';
import 'package:mobi_app/core/utils/phone_number_normalizer.dart';
import 'package:mobi_app/features/admin/widgets/admin_ui.dart';
import 'package:mobi_app/features/biopay/models/biopay_admin.dart';
import 'package:mobi_app/features/biopay/models/biopay_ussd_payment.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_app/shared/widgets/mobi_surface_panel.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ndef/ndef.dart' as ndef;
import 'package:qr_flutter/qr_flutter.dart';

const _bioPayBlue = Color(0xFF006DFF);
const _bioPayNfcPurple = Color(0xFF6D4CFF);
const _bioPayQrOrange = Color(0xFFFF9800);
const _bioPayScanTeal = Color(0xFF14B8A6);
const _bioPayInk = Color(0xFF101828);
const _bioPayMuted = Color(0xFF667085);
const _bioPayCanvas = Color(0xFFFBFCFF);
const _bioPayPanel = Color(0xFFF5F7FA);
const _bioPayChrome = Color(0xFF050815);
const _bioPayDarkPanel = Color(0xFF171B3E);
const _bioPayDarkPanelAlt = Color(0xFF202654);

ThemeData _bioPayLightTheme(BuildContext context) {
  final base = Theme.of(context);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: _bioPayBlue,
        brightness: Brightness.light,
      ).copyWith(
        primary: _bioPayBlue,
        onPrimary: Colors.white,
        surface: _bioPayCanvas,
        onSurface: _bioPayInk,
        onSurfaceVariant: _bioPayMuted,
        surfaceContainerHighest: _bioPayPanel,
        outlineVariant: const Color(0xFFE4E7EC),
      );

  return base.copyWith(
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: _bioPayCanvas,
  );
}

class BioPayScreen extends StatelessWidget {
  const BioPayScreen({
    super.key,
    required this.onQr,
    required this.onScan,
    required this.onFace,
    required this.onNfc,
  });

  final VoidCallback onQr;
  final VoidCallback onScan;
  final VoidCallback onFace;
  final VoidCallback onNfc;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _bioPayLightTheme(context),
      child: Scaffold(
        backgroundColor: _bioPayCanvas,
        body: _BioPayLightCanvas(
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.xl,
                AppSpacing.screenPadding,
                132,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: _BioPayIconBox(
                      icon: LucideIcons.scanFace,
                      color: Colors.white,
                      background: _bioPayChrome,
                    ),
                  ),
                  const SizedBox(height: 66),
                  Text(
                    'Pay & Get Paid\nInstant & Secure',
                    style: AppTypography.displayLg.copyWith(
                      color: Colors.white,
                      fontSize: 40,
                      height: 1.02,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  MobiSurfacePanel(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    borderRadius: AppRadii.xxl,
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.1,
                      children: [
                        _BioPayHomeTile(
                          icon: LucideIcons.scanFace,
                          label: 'Face Scan',
                          color: _bioPayBlue,
                          onTap: onFace,
                        ),
                        _BioPayHomeTile(
                          icon: LucideIcons.nfc,
                          label: 'NFC Tap',
                          color: _bioPayNfcPurple,
                          onTap: onNfc,
                        ),
                        _BioPayHomeTile(
                          icon: LucideIcons.qrCode,
                          label: 'Get QR',
                          color: _bioPayQrOrange,
                          onTap: onQr,
                        ),
                        _BioPayHomeTile(
                          icon: LucideIcons.scanLine,
                          label: 'Scan QR',
                          color: _bioPayScanTeal,
                          onTap: onScan,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BioPayLightCanvas extends StatelessWidget {
  const _BioPayLightCanvas({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SoftGradient(child: child);
  }
}

class _BioPayHomeTile extends StatelessWidget {
  const _BioPayHomeTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        shadowColor: Colors.black.withValues(alpha: 0.22),
        elevation: 5,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: _bioPayDarkPanel.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  _bioPayDarkPanelAlt.withValues(alpha: 0.68),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _BioPayActionGlyph(icon: icon, accent: color),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelLg.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BioPayActionGlyph extends StatelessWidget {
  const _BioPayActionGlyph({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _bioPayInk,
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.20),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              right: 8,
              top: 8,
              child: SizedBox.square(
                dimension: 7,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Icon(icon, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }
}

class _BioPayIconBox extends StatelessWidget {
  const _BioPayIconBox({
    required this.icon,
    required this.color,
    required this.background,
    this.dimension = 48,
    this.iconSize = 24,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double dimension;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: dimension,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: iconSize),
      ),
    );
  }
}

enum _BioPayAdminSection { overview, payees, status, confirmations }

class BioPayAdminConsoleScreen extends ConsumerStatefulWidget {
  const BioPayAdminConsoleScreen({super.key});

  @override
  ConsumerState<BioPayAdminConsoleScreen> createState() =>
      _BioPayAdminConsoleScreenState();
}

class _BioPayAdminConsoleScreenState
    extends ConsumerState<BioPayAdminConsoleScreen> {
  final TextEditingController _searchController = TextEditingController();
  BioPayAdminSnapshot? _snapshot;
  BioPayAdminPayee? _selectedPayee;
  _BioPayAdminSection _section = _BioPayAdminSection.overview;
  bool _loading = false;
  String? _confirmingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await ref
          .read(biopayAdminServiceProvider)
          .loadSnapshot(search: _searchController.text);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        if (_selectedPayee != null) {
          _selectedPayee = snapshot.payees.cast<BioPayAdminPayee?>().firstWhere(
            (payee) => payee?.userId == _selectedPayee?.userId,
            orElse: () => null,
          );
        }
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _error = 'BioPay operations unavailable.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmExternal(BioPayUssdPaymentRequest request) async {
    setState(() {
      _confirmingId = request.id;
      _error = null;
    });
    try {
      final updated = await ref
          .read(biopayAdminServiceProvider)
          .confirmRequestExternally(
            request: request,
            confirmationSource: 'admin_external_reference',
          );
      if (!mounted) return;
      final snapshot = _snapshot;
      if (snapshot == null) return;
      setState(() {
        _snapshot = BioPayAdminSnapshot(
          summary: snapshot.summary,
          payees: snapshot.payees,
          systemStatus: snapshot.systemStatus,
          requests: [
            for (final item in snapshot.requests)
              item.id == updated.id ? updated : item,
          ],
        );
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _error = 'External confirmation unavailable.');
    } finally {
      if (mounted) setState(() => _confirmingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    return AdminWorkspaceFrame(
      currentTab: AdminWorkspaceTab.biopayOps,
      title: 'BioPay Ops',
      subtitle: 'AWS face identity and external USSD handoff.',
      actions: [
        AdminActionChip(
          label: 'Payees',
          icon: LucideIcons.users,
          tone: MobiStatusBadgeTone.info,
          onTap: () => setState(() => _section = _BioPayAdminSection.payees),
        ),
        AdminActionChip(
          label: 'Status',
          icon: LucideIcons.serverCog,
          tone: MobiStatusBadgeTone.positive,
          onTap: () => setState(() => _section = _BioPayAdminSection.status),
        ),
        AdminActionChip(
          label: 'Refresh',
          icon: LucideIcons.refreshCw,
          isBusy: _loading,
          onTap: _loading ? null : _load,
        ),
      ],
      child: RefreshIndicator.adaptive(
        onRefresh: _load,
        child: SingleChildScrollView(
          padding: AdminLayoutTokens.pagePadding,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                _AdminBioPayError(message: _error!, onRetry: _load),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (snapshot == null)
                const _AdminBioPayLoading()
              else ...[
                _BioPayAdminMetrics(summary: snapshot.summary),
                const SizedBox(height: AppSpacing.lg),
                _BioPayAdminSectionPicker(
                  selected: _section,
                  onSelected: (section) => setState(() => _section = section),
                ),
                const SizedBox(height: AppSpacing.lg),
                switch (_section) {
                  _BioPayAdminSection.overview => _BioPayAdminOverview(
                    snapshot: snapshot,
                    onOpenPayees: () =>
                        setState(() => _section = _BioPayAdminSection.payees),
                    onOpenStatus: () =>
                        setState(() => _section = _BioPayAdminSection.status),
                    onOpenConfirmations: () => setState(
                      () => _section = _BioPayAdminSection.confirmations,
                    ),
                  ),
                  _BioPayAdminSection.payees => _BioPayAdminPayees(
                    payees: snapshot.payees,
                    selectedPayee: _selectedPayee,
                    searchController: _searchController,
                    onSearchChanged: (_) => _load(),
                    onSelectPayee: (payee) =>
                        setState(() => _selectedPayee = payee),
                  ),
                  _BioPayAdminSection.status => _BioPayAdminStatusPanel(
                    status: snapshot.systemStatus,
                  ),
                  _BioPayAdminSection.confirmations =>
                    _BioPayAdminConfirmationsPanel(
                      requests: snapshot.requests,
                      confirmingId: _confirmingId,
                      onConfirm: _confirmExternal,
                    ),
                },
              ],
            ],
          ),
        ),
      ),
    );
  }
}

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
  BioPayUssdPaymentRequest? _request;
  bool _creating = false;
  bool _receiverUsesCode = false;
  String? _error;
  String? _shareMessage;

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
      _receiverNumberController.text = _momoReceiverDisplay(receiver);
    }

    if (momoPayCode.isNotEmpty && _receiverCodeController.text.trim().isEmpty) {
      _receiverCodeController.text = _momoPayCodeDisplay(momoPayCode);
    }

    setState(() {});
  }

  void _resetRequest() {
    setState(() {
      _request = null;
      _shareMessage = null;
      _error = null;
    });
  }

  void _onReceiverChanged(String value) {
    if (!_receiverUsesCode) {
      final display = _momoReceiverDisplay(value);
      if (display != value) {
        _receiverNumberController.value = TextEditingValue(
          text: display,
          selection: TextSelection.collapsed(offset: display.length),
        );
      }
    }
    _resetRequest();
  }

  Future<void> _shareQrCode() async {
    final request = _request;
    if (request == null) return;
    await Clipboard.setData(ClipboardData(text: buildBioPayQrPayload(request)));
    if (!mounted) return;
    setState(() => _shareMessage = 'QR code copied for sharing.');
  }

  Future<void> _createRequest() async {
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final service = ref.read(biopayUssdServiceProvider);
      final receiver = _momoReceiverForRequest(
        _activeReceiverController.text,
        usesCode: _receiverUsesCode,
      );
      if (receiver.isEmpty) {
        throw const FormatException('receiver_required');
      }
      final amountMinor = _optionalAmountMinorFromController(_amountController);
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
        _shareMessage = null;
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
    return _BioPayFlowScreen(
      title: 'QR',
      icon: LucideIcons.qrCode,
      primaryLabel: 'Generate QR Code',
      isPrimaryLoading: _creating,
      onBack: widget.onBack,
      onPrimary: _createRequest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BioPayReceiverField(
            controller: _activeReceiverController,
            enabled: _request == null,
            usesCode: _receiverUsesCode,
            onModeChanged: (usesCode) => setState(() {
              _receiverUsesCode = usesCode;
              _request = null;
              _shareMessage = null;
              _error = null;
            }),
            onChanged: _onReceiverChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          _BioPayReceiveAmountField(
            controller: _amountController,
            enabled: _request == null,
            onChanged: (_) => _resetRequest(),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_request != null) ...[
            _QrPreview(request: _request!, onShare: _shareQrCode),
            const SizedBox(height: AppSpacing.md),
            _DetailRow(
              label: 'Receiver',
              value: _activeReceiverController.text,
            ),
            _DetailRow(label: 'Amount', value: _request!.amountLabel),
          ],
          if (_shareMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            _DetailRow(label: 'Share', value: _shareMessage!),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            _InlineError(message: _error!),
          ],
        ],
      ),
    );
  }
}

class BioPayScanScreen extends ConsumerStatefulWidget {
  const BioPayScanScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<BioPayScanScreen> createState() => _BioPayScanScreenState();
}

class _BioPayScanScreenState extends ConsumerState<BioPayScanScreen> {
  BioPayUssdPaymentRequest? _request;
  bool _resolving = false;
  bool _externalActionBusy = false;
  bool _handledScan = false;
  String? _error;

  Future<void> _resolve(String token) async {
    final resolvedToken = bioPayTokenFromPayload(token);
    if (_resolving || resolvedToken.isEmpty) return;
    setState(() {
      _resolving = true;
      _error = null;
    });
    try {
      final service = ref.read(biopayUssdServiceProvider);
      final request = SupabaseConfig.isConfigured
          ? await service.resolveRequest(resolvedToken)
          : service.resolvePreviewToken(resolvedToken);
      if (!mounted) return;
      setState(() => _request = request);
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _error = 'QR request unavailable.');
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _runExternalPaymentStep() async {
    final request = _request;
    if (request == null) return;
    setState(() {
      _externalActionBusy = true;
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
      if (mounted) setState(() => _externalActionBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BioPayFlowScreen(
      title: 'Scan',
      icon: LucideIcons.scanLine,
      primaryLabel: _request == null ? '' : _externalActionLabel(_request!),
      isPrimaryLoading: _resolving || _externalActionBusy,
      onBack: widget.onBack,
      onPrimary: _request == null
          ? null
          : _canRunExternalAction(_request)
          ? _runExternalPaymentStep
          : null,
      child: _request == null
          ? _QrScannerSurface(
              onDetect: (value) {
                if (_handledScan) return;
                _handledScan = true;
                _resolve(value);
              },
              error: _error,
            )
          : _ResolvedPaymentPreview(request: _request!),
    );
  }
}

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
      _receiverNumberController.text = _momoReceiverDisplay(receiver);
    }

    if (momoPayCode.isNotEmpty && _receiverCodeController.text.trim().isEmpty) {
      _receiverCodeController.text = _momoPayCodeDisplay(momoPayCode);
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
      final display = _momoReceiverDisplay(value);
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
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receiver = _momoReceiverForRequest(
        _activeReceiverController.text,
        usesCode: _receiverUsesCode,
      );
      if (receiver.isEmpty) {
        throw const FormatException('receiver_required');
      }
      await _ensureNfcAvailable();
      final service = ref.read(biopayUssdServiceProvider);
      final amountMinor = _optionalAmountMinorFromController(_amountController);
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
    return _BioPayFlowScreen(
      title: 'NFC',
      icon: LucideIcons.nfc,
      primaryLabel: _request == null ? 'Activate NFC' : 'NFC Active',
      isPrimaryLoading: _busy,
      onBack: widget.onBack,
      onPrimary: _request == null ? _prepareTapTag : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_request == null) ...[
            _BioPayReceiverField(
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
            _BioPayReceiveAmountField(
              controller: _amountController,
              enabled: _request == null,
              onChanged: (_) => _resetRequest(),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          if (_request == null)
            const _NfcReadyHint()
          else
            _ResolvedPaymentPreview(request: _request!),
          if (_tagLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            _DetailRow(label: 'NFC', value: _tagLabel!),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            _InlineError(message: _error!),
          ],
        ],
      ),
    );
  }
}

class BioPayFaceEnrollScreen extends ConsumerStatefulWidget {
  const BioPayFaceEnrollScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<BioPayFaceEnrollScreen> createState() =>
      _BioPayFaceEnrollScreenState();
}

class _BioPayFaceEnrollScreenState
    extends ConsumerState<BioPayFaceEnrollScreen> {
  static const _enrollmentChallenges = <_FaceEnrollmentChallenge>[
    _FaceEnrollmentChallenge(
      id: 'straight_1',
      title: 'Center',
      body: 'Place your face in the oval.',
      action: 'Capture center',
    ),
    _FaceEnrollmentChallenge(
      id: 'turn_pose',
      title: 'Turn',
      body: 'Turn your head slightly, then hold.',
      action: 'Capture turn',
    ),
    _FaceEnrollmentChallenge(
      id: 'straight_2',
      title: 'Hold',
      body: 'Face forward again.',
      action: 'Finish enrollment',
    ),
  ];

  CameraController? _camera;
  final List<List<int>> _capturedFrames = [];
  String? _sessionId;
  String? _error;
  int _captureStepIndex = 0;
  bool _busy = false;
  bool _enrolled = false;

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
      _captureStepIndex = 0;
      _capturedFrames.clear();
      _enrolled = false;
    });
    try {
      final faceService = ref.read(biopayFaceServiceProvider);
      final result = await faceService.createLivenessSession();
      await _ensureCamera();
      if (!mounted) return;
      setState(() {
        _sessionId = result.sessionId;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyCameraMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _captureEnroll() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await camera.takePicture();
      final imageBytes = await file.readAsBytes();
      _capturedFrames.add(imageBytes);
      if (_captureStepIndex < _enrollmentChallenges.length - 1) {
        if (!mounted) return;
        setState(() => _captureStepIndex += 1);
        return;
      }
      final result = await ref
          .read(biopayFaceServiceProvider)
          .enrollFace(
            faceProfileId:
                'mobio-face-${DateTime.now().microsecondsSinceEpoch}',
            imageBytes: _capturedFrames.last,
            challengeIds: _enrollmentChallenges
                .map((challenge) => challenge.id)
                .toList(growable: false),
            sampleCount: _capturedFrames.length,
            livenessSessionId: _sessionId,
          );
      if (!mounted) return;
      setState(() {
        _enrolled = result.status == 'enrolled';
        if (!_enrolled) {
          _capturedFrames.clear();
          _captureStepIndex = 0;
        }
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Face enrollment was not accepted.';
        _capturedFrames.clear();
        _captureStepIndex = 0;
      });
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
    CameraDescription? front;
    for (final camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        front = camera;
        break;
      }
    }
    final controller = CameraController(
      front ?? cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize().timeout(const Duration(seconds: 8));
    _camera = controller;
  }

  String _friendlyCameraMessage(Object error) {
    if (error is CameraException) {
      final code = error.code.toLowerCase();
      if (code.contains('access') || code.contains('permission')) {
        return 'Camera permission is required to enroll your face.';
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
    return 'Face provider or camera unavailable.';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final readyForCapture = _camera?.value.isInitialized == true;
    final currentChallenge = _enrollmentChallenges[_captureStepIndex];
    final capturedCount = _enrolled
        ? _enrollmentChallenges.length
        : _capturedFrames.length;
    final primaryLabel = readyForCapture
        ? currentChallenge.action
        : 'Start Enrollment';

    return _BioPayFlowScreen(
      title: 'Face enroll',
      icon: LucideIcons.scanFace,
      primaryLabel: primaryLabel,
      isPrimaryLoading: _busy,
      onBack: widget.onBack,
      onPrimary: _enrolled ? null : (readyForCapture ? _captureEnroll : _start),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FaceEnrollmentStatusPanel(
            title: _enrolled ? 'Saved' : currentChallenge.title,
            body: _enrolled
                ? 'AWS face identity ready.'
                : currentChallenge.body,
            capturedCount: capturedCount,
            totalSteps: _enrollmentChallenges.length,
            sessionReady: _sessionId != null,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (readyForCapture)
            _CameraFrame(
              controller: _camera!,
              capturedCount: capturedCount,
              totalSteps: _enrollmentChallenges.length,
              currentStepId: currentChallenge.id,
              showFaceGuide: true,
            )
          else
            _FaceEnrollmentStandby(
              iconColor: cs.primary,
              label: 'AWS liveness session',
            ),
          const SizedBox(height: AppSpacing.lg),
          _PoseCueStrip(
            capturedCount: capturedCount,
            totalSteps: _enrollmentChallenges.length,
            currentStepId: currentChallenge.id,
            hasError: _error != null,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            _InlineError(message: _error!),
          ],
        ],
      ),
    );
  }
}

class _FaceEnrollmentChallenge {
  const _FaceEnrollmentChallenge({
    required this.id,
    required this.title,
    required this.body,
    required this.action,
  });

  final String id;
  final String title;
  final String body;
  final String action;
}

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
        });
        return;
      }
      final ussdService = ref.read(biopayUssdServiceProvider);
      final amountMinor = _amountMinorFromController(_amountController);
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
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyFaceScanMessage(error));
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
    CameraDescription? front;
    for (final camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        front = camera;
        break;
      }
    }
    final controller = CameraController(
      front ?? cameras.first,
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
        : _externalActionLabel(_request!);

    return _BioPayFlowScreen(
      title: 'Face scan',
      icon: LucideIcons.scanFace,
      primaryLabel: primaryLabel,
      isPrimaryLoading: _busy,
      onBack: widget.onBack,
      onPrimary: _request == null
          ? _scanFace
          : _canRunExternalAction(_request)
          ? _runExternalPaymentStep
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_request != null)
            _ResolvedPaymentPreview(request: _request!)
          else ...[
            _BioPayReceiveAmountField(controller: _amountController),
            const SizedBox(height: AppSpacing.md),
            if (readyForPreview)
              _CameraFrame(
                controller: _camera!,
                totalSteps: 1,
                currentStepId: 'straight_1',
                showFaceGuide: true,
              )
            else
              _FaceEnrollmentStandby(
                iconColor: Theme.of(context).colorScheme.primary,
                height: 376,
                guideSize: const Size(190, 258),
              ),
          ],
          if (_matchLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            _DetailRow(label: 'Match', value: _matchLabel!),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            _InlineError(message: _error!),
          ],
        ],
      ),
    );
  }
}

class _PaymentRequestItem extends StatelessWidget {
  const _PaymentRequestItem({
    required this.request,
    required this.isConfirming,
    required this.onConfirm,
  });

  final BioPayUssdPaymentRequest request;
  final bool isConfirming;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_channelIcon(request.channel), color: cs.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  request.reference,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMd.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                request.amountLabel,
                style: AppTypography.labelLg.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _DetailRow(
            label: 'Status',
            value: _requestStatusLabel(request.status),
          ),
          _DetailRow(
            label: 'Confirmation',
            value: request.confirmationSource ?? 'External',
          ),
          if (onConfirm != null) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: isConfirming ? null : onConfirm,
                icon: isConfirming
                    ? SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.primary,
                        ),
                      )
                    : const Icon(LucideIcons.checkCircle),
                label: const Text('Confirm external'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BioPayAdminMetrics extends StatelessWidget {
  const _BioPayAdminMetrics({required this.summary});

  final BioPayAdminSummary summary;

  @override
  Widget build(BuildContext context) {
    final columns = MediaQuery.sizeOf(context).width >= 980 ? 4 : 2;

    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      childAspectRatio: columns == 4 ? 1.3 : 0.85,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        AdminMetricCard(
          label: 'Payees',
          value: '${summary.totalPayees}',
          hint: '${summary.enrolledPayees} enrolled',
          icon: LucideIcons.users,
          tone: MobiStatusBadgeTone.info,
        ),
        AdminMetricCard(
          label: 'Requests',
          value: '${summary.totalRequests}',
          hint: 'USSD handoffs only',
          icon: LucideIcons.phoneCall,
          tone: MobiStatusBadgeTone.brand,
        ),
        AdminMetricCard(
          label: 'Pending',
          value: '${summary.pendingConfirmations}',
          hint: 'Needs external evidence',
          icon: LucideIcons.clock,
          tone: MobiStatusBadgeTone.warning,
        ),
        AdminMetricCard(
          label: 'Match rate',
          value: summary.matchRateLabel,
          hint: '${summary.confirmedRequests} confirmed',
          icon: LucideIcons.scanFace,
          tone: MobiStatusBadgeTone.positive,
        ),
      ],
    );
  }
}

class _BioPayAdminSectionPicker extends StatelessWidget {
  const _BioPayAdminSectionPicker({
    required this.selected,
    required this.onSelected,
  });

  final _BioPayAdminSection selected;
  final ValueChanged<_BioPayAdminSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _sectionChip(
          'Overview',
          LucideIcons.layoutDashboard,
          _BioPayAdminSection.overview,
        ),
        _sectionChip('Payees', LucideIcons.users, _BioPayAdminSection.payees),
        _sectionChip(
          'Status',
          LucideIcons.serverCog,
          _BioPayAdminSection.status,
        ),
        _sectionChip(
          'Confirmations',
          LucideIcons.badgeCheck,
          _BioPayAdminSection.confirmations,
        ),
      ],
    );
  }

  Widget _sectionChip(
    String label,
    IconData icon,
    _BioPayAdminSection section,
  ) {
    return AdminFilterChip(
      label: label,
      icon: icon,
      isSelected: selected == section,
      onTap: () => onSelected(section),
    );
  }
}

class _BioPayAdminOverview extends StatelessWidget {
  const _BioPayAdminOverview({
    required this.snapshot,
    required this.onOpenPayees,
    required this.onOpenStatus,
    required this.onOpenConfirmations,
  });

  final BioPayAdminSnapshot snapshot;
  final VoidCallback onOpenPayees;
  final VoidCallback onOpenStatus;
  final VoidCallback onOpenConfirmations;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        final children = [
          _BioPayAdminPayeeSummary(
            payees: snapshot.payees.take(4).toList(),
            onOpenPayees: onOpenPayees,
          ),
          _BioPayAdminStatusPanel(
            status: snapshot.systemStatus,
            compact: true,
            onOpenStatus: onOpenStatus,
          ),
          _BioPayAdminConfirmationsPanel(
            requests: snapshot.requests.take(4).toList(),
            confirmingId: null,
            onConfirm: (_) {},
            compact: true,
            onOpenConfirmations: onOpenConfirmations,
          ),
        ];
        if (!wide) {
          return Column(
            children: [
              for (final child in children) ...[
                child,
                const SizedBox(height: AppSpacing.lg),
              ],
            ],
          );
        }
        return GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: AppSpacing.lg,
          mainAxisSpacing: AppSpacing.lg,
          childAspectRatio: 0.78,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      },
    );
  }
}

class _BioPayAdminPayeeSummary extends StatelessWidget {
  const _BioPayAdminPayeeSummary({
    required this.payees,
    required this.onOpenPayees,
  });

  final List<BioPayAdminPayee> payees;
  final VoidCallback onOpenPayees;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminSectionHeader(
            title: 'Payee Directory',
            subtitle: 'AWS-enrolled BioPay recipients.',
            trailing: AdminActionChip(
              label: 'Open',
              icon: LucideIcons.arrowRight,
              onTap: onOpenPayees,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (payees.isEmpty)
            const AdminEmptyState(
              title: 'No payees',
              message: 'No active BioPay enrollments are available.',
              icon: LucideIcons.users,
            )
          else
            for (final payee in payees) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      payee.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMd.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  MobiStatusBadge(
                    label: payee.enrollmentLabel,
                    tone: payee.isEnrolled
                        ? MobiStatusBadgeTone.positive
                        : MobiStatusBadgeTone.warning,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                payee.handle,
                style: AppTypography.labelMd.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Divider(height: AppSpacing.xl),
            ],
        ],
      ),
    );
  }
}

class _BioPayAdminPayees extends StatelessWidget {
  const _BioPayAdminPayees({
    required this.payees,
    required this.selectedPayee,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSelectPayee,
  });

  final List<BioPayAdminPayee> payees;
  final BioPayAdminPayee? selectedPayee;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<BioPayAdminPayee> onSelectPayee;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        final list = AdminPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminSectionHeader(
                title: 'Payees',
                subtitle: 'Search enrolled AWS BioPay profiles.',
                trailing: MobiStatusBadge(label: '${payees.length} shown'),
              ),
              const SizedBox(height: AppSpacing.lg),
              AdminSearchField(
                controller: searchController,
                hintText: 'Search payee, handle, or provider id',
                onChanged: onSearchChanged,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (payees.isEmpty)
                const AdminEmptyState(
                  title: 'No matching payees',
                  message: 'Try a different name, handle, or AWS subject.',
                  icon: LucideIcons.search,
                )
              else
                for (final payee in payees) ...[
                  _BioPayAdminPayeeTile(
                    payee: payee,
                    selected: selectedPayee?.userId == payee.userId,
                    onTap: () => onSelectPayee(payee),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
            ],
          ),
        );
        final detail = _BioPayAdminPayeeDetail(payee: selectedPayee);
        if (!wide) {
          return Column(
            children: [
              list,
              const SizedBox(height: AppSpacing.lg),
              detail,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: list),
            const SizedBox(width: AppSpacing.lg),
            Expanded(flex: 5, child: detail),
          ],
        );
      },
    );
  }
}

class _BioPayAdminPayeeTile extends StatelessWidget {
  const _BioPayAdminPayeeTile({
    required this.payee,
    required this.selected,
    required this.onTap,
  });

  final BioPayAdminPayee payee;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? cs.primary.withValues(alpha: 0.12)
          : cs.surfaceContainerHighest.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(LucideIcons.scanFace, color: cs.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payee.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMd.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${payee.handle} · ${payee.requestCount} requests',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMd.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              MobiStatusBadge(
                label: payee.enrollmentLabel,
                tone: payee.isEnrolled
                    ? MobiStatusBadgeTone.positive
                    : MobiStatusBadgeTone.warning,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BioPayAdminPayeeDetail extends StatelessWidget {
  const _BioPayAdminPayeeDetail({required this.payee});

  final BioPayAdminPayee? payee;

  @override
  Widget build(BuildContext context) {
    final selected = payee;
    if (selected == null) {
      return const AdminEmptyState(
        title: 'Select a payee',
        message: 'Open an enrolled BioPay profile to review AWS status.',
        icon: LucideIcons.search,
      );
    }

    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminSectionHeader(
            title: selected.displayName,
            subtitle: selected.handle,
            trailing: MobiStatusBadge(
              label: selected.status,
              tone: selected.status == 'active'
                  ? MobiStatusBadgeTone.positive
                  : MobiStatusBadgeTone.warning,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _AdminDetailRow(label: 'Provider', value: selected.provider),
          _AdminDetailRow(
            label: 'AWS face id',
            value: selected.providerSubjectId.isEmpty
                ? 'Not enrolled'
                : selected.providerSubjectId,
          ),
          _AdminDetailRow(
            label: 'Collection',
            value: selected.providerCollectionId.isEmpty
                ? 'Not assigned'
                : selected.providerCollectionId,
          ),
          _AdminDetailRow(label: 'Liveness', value: selected.livenessStatus),
          _AdminDetailRow(label: 'Requests', value: '${selected.requestCount}'),
          _AdminDetailRow(
            label: 'Confirmed',
            value: '${selected.confirmedCount}',
          ),
          _AdminDetailRow(
            label: 'Last request',
            value: _dateLabel(selected.lastRequestAt),
          ),
        ],
      ),
    );
  }
}

class _BioPayAdminStatusPanel extends StatelessWidget {
  const _BioPayAdminStatusPanel({
    required this.status,
    this.compact = false,
    this.onOpenStatus,
  });

  final BioPayAdminSystemStatus status;
  final bool compact;
  final VoidCallback? onOpenStatus;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminSectionHeader(
            title: 'System Status',
            subtitle: 'Provider and USSD handoff readiness.',
            trailing: onOpenStatus == null
                ? MobiStatusBadge(
                    label: status.overallStatus,
                    tone: status.overallStatus == 'operational'
                        ? MobiStatusBadgeTone.positive
                        : MobiStatusBadgeTone.warning,
                  )
                : AdminActionChip(
                    label: 'Open',
                    icon: LucideIcons.arrowRight,
                    onTap: onOpenStatus,
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _AdminDetailRow(label: 'Face provider', value: status.faceProvider),
          _AdminDetailRow(
            label: 'AWS ready',
            value: status.faceProviderReady ? 'Ready' : 'Not ready',
          ),
          _AdminDetailRow(
            label: 'Collection',
            value: status.collectionId.isEmpty
                ? 'Configured in AWS'
                : status.collectionId,
          ),
          _AdminDetailRow(label: 'Database', value: status.databaseStatus),
          const _AdminDetailRow(label: 'Payment', value: 'External USSD only'),
          if (!compact) ...[
            _AdminDetailRow(
              label: 'Pending confirmations',
              value: '${status.pendingConfirmations}',
            ),
            _AdminDetailRow(
              label: 'Last audit',
              value: _dateLabel(status.lastAuditAt),
            ),
          ],
        ],
      ),
    );
  }
}

class _BioPayAdminConfirmationsPanel extends StatelessWidget {
  const _BioPayAdminConfirmationsPanel({
    required this.requests,
    required this.confirmingId,
    required this.onConfirm,
    this.compact = false,
    this.onOpenConfirmations,
  });

  final List<BioPayUssdPaymentRequest> requests;
  final String? confirmingId;
  final ValueChanged<BioPayUssdPaymentRequest> onConfirm;
  final bool compact;
  final VoidCallback? onOpenConfirmations;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminSectionHeader(
            title: 'Confirmations',
            subtitle: 'Request state and external confirmation queue.',
            trailing: onOpenConfirmations == null
                ? null
                : AdminActionChip(
                    label: 'Open',
                    icon: LucideIcons.arrowRight,
                    onTap: onOpenConfirmations,
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (requests.isEmpty)
            const AdminEmptyState(
              title: 'No confirmations',
              message: 'No BioPay USSD requests are available.',
              icon: LucideIcons.badgeCheck,
            )
          else
            for (final request in requests) ...[
              _PaymentRequestItem(
                request: request,
                isConfirming: confirmingId == request.id,
                onConfirm:
                    !compact &&
                        request.status == BioPayRequestStatus.userMarkedPaid
                    ? () => onConfirm(request)
                    : null,
              ),
              const Divider(height: AppSpacing.xl),
            ],
        ],
      ),
    );
  }
}

class _AdminBioPayLoading extends StatelessWidget {
  const _AdminBioPayLoading();

  @override
  Widget build(BuildContext context) {
    return const AdminPanel(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
    );
  }
}

class _AdminBioPayError extends StatelessWidget {
  const _AdminBioPayError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      child: Row(
        children: [
          const Icon(LucideIcons.alertTriangle),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(message)),
          AdminActionChip(
            label: 'Retry',
            icon: LucideIcons.refreshCw,
            onTap: onRetry,
          ),
        ],
      ),
    );
  }
}

class _AdminDetailRow extends StatelessWidget {
  const _AdminDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.labelMd.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: AppTypography.labelLg.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraFrame extends StatelessWidget {
  const _CameraFrame({
    required this.controller,
    this.capturedCount = 0,
    this.totalSteps = 0,
    this.currentStepId = 'straight_1',
    this.showFaceGuide = false,
  });

  final CameraController controller;
  final int capturedCount;
  final int totalSteps;
  final String currentStepId;
  final bool showFaceGuide;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: DecoratedBox(
          decoration: BoxDecoration(color: cs.surfaceContainerHighest),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _FittedCameraPreview(controller: controller),
              if (showFaceGuide) ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.34),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.28),
                      ],
                    ),
                  ),
                ),
                _BioPayFaceOvalGuide(
                  capturedCount: capturedCount,
                  totalSteps: totalSteps,
                  currentStepId: currentStepId,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FittedCameraPreview extends StatelessWidget {
  const _FittedCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final cameraAspectRatio = controller.value.aspectRatio;
    if (cameraAspectRatio <= 0) return CameraPreview(controller);

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = _cameraPreviewCoverScale(
          viewport: Size(constraints.maxWidth, constraints.maxHeight),
          cameraAspectRatio: cameraAspectRatio,
          orientation: MediaQuery.orientationOf(context),
        );
        return ClipRect(
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: Center(child: CameraPreview(controller)),
          ),
        );
      },
    );
  }
}

double _cameraPreviewCoverScale({
  required Size viewport,
  required double cameraAspectRatio,
  required Orientation orientation,
}) {
  if (viewport.width <= 0 || viewport.height <= 0 || cameraAspectRatio <= 0) {
    return 1;
  }
  final viewportAspectRatio = viewport.width / viewport.height;
  final previewAspectRatio = orientation == Orientation.portrait
      ? 1 / cameraAspectRatio
      : cameraAspectRatio;
  final scale = previewAspectRatio > viewportAspectRatio
      ? previewAspectRatio / viewportAspectRatio
      : viewportAspectRatio / previewAspectRatio;
  return math.max(1, scale);
}

class _BioPayFaceOvalGuide extends StatelessWidget {
  const _BioPayFaceOvalGuide({
    required this.capturedCount,
    required this.totalSteps,
    required this.currentStepId,
  });

  final int capturedCount;
  final int totalSteps;
  final String currentStepId;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _BioPayFaceGuidePainter(
          capturedCount: capturedCount,
          totalSteps: totalSteps,
          currentStepId: currentStepId,
        ),
      ),
    );
  }
}

class _BioPayFaceGuidePainter extends CustomPainter {
  const _BioPayFaceGuidePainter({
    required this.capturedCount,
    required this.totalSteps,
    required this.currentStepId,
  });

  final int capturedCount;
  final int totalSteps;
  final String currentStepId;

  @override
  void paint(Canvas canvas, Size size) {
    final guideWidth = math.min(size.width * 0.72, 280.0);
    final guideHeight = math.min(size.height * 0.58, guideWidth * 1.28);
    final guideRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.46),
      width: guideWidth,
      height: guideHeight,
    );
    final ringRect = guideRect.inflate(8);
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.88);
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.10);
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF22C55E);

    canvas
      ..drawOval(ringRect, glowPaint)
      ..drawOval(guideRect, basePaint);

    final segments = math.max(1, totalSteps);
    final sweep = (math.pi * 2 / segments) - 0.18;
    for (var i = 0; i < segments; i += 1) {
      if (i >= capturedCount) continue;
      canvas.drawArc(
        ringRect,
        -math.pi / 2 + (math.pi * 2 / segments * i),
        sweep,
        false,
        progressPaint,
      );
    }

    final cuePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.28);
    final cueOffset = currentStepId == 'turn_pose' ? guideWidth * 0.10 : 0.0;
    final center = guideRect.center.translate(cueOffset, -guideHeight * 0.04);
    canvas
      ..drawCircle(center, 3.5, cuePaint)
      ..drawLine(center.translate(0, 12), center.translate(0, 36), cuePaint);
  }

  @override
  bool shouldRepaint(covariant _BioPayFaceGuidePainter oldDelegate) {
    return oldDelegate.capturedCount != capturedCount ||
        oldDelegate.totalSteps != totalSteps ||
        oldDelegate.currentStepId != currentStepId;
  }
}

class _PoseCueStrip extends StatelessWidget {
  const _PoseCueStrip({
    required this.capturedCount,
    required this.totalSteps,
    required this.currentStepId,
    this.hasError = false,
  });

  final int capturedCount;
  final int totalSteps;
  final String currentStepId;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    const stepIds = ['straight_1', 'turn_pose', 'straight_2'];
    final cs = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.center,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: hasError
                ? cs.error.withValues(alpha: 0.54)
                : cs.outlineVariant.withValues(alpha: 0.52),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < totalSteps; i += 1) ...[
                _PoseCueDot(
                  id: stepIds[i],
                  completed: i < capturedCount,
                  active: stepIds[i] == currentStepId,
                  hasError: hasError,
                ),
                if (i != totalSteps - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PoseCueDot extends StatelessWidget {
  const _PoseCueDot({
    required this.id,
    required this.completed,
    required this.active,
    required this.hasError,
  });

  final String id;
  final bool completed;
  final bool active;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = completed
        ? const Color(0xFF22C55E)
        : active && hasError
        ? cs.error
        : active
        ? cs.onSurface
        : cs.onSurfaceVariant.withValues(alpha: 0.50);
    final icon = completed
        ? LucideIcons.check
        : id == 'turn_pose'
        ? LucideIcons.rotateCw
        : LucideIcons.scanFace;

    return SizedBox.square(
      dimension: active ? 38 : 34,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: completed ? 1 : 0.12),
          border: Border.all(color: color, width: active ? 1.8 : 1.2),
        ),
        child: Icon(
          icon,
          color: completed ? Colors.white : color,
          size: active ? 19 : 17,
        ),
      ),
    );
  }
}

class _FaceEnrollmentStandby extends StatelessWidget {
  const _FaceEnrollmentStandby({
    required this.iconColor,
    this.label,
    this.height = 260,
    this.guideSize = const Size(156, 212),
  });

  final Color iconColor;
  final String? label;
  final double height;
  final Size guideSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: guideSize.width,
                height: guideSize.height,
                child: CustomPaint(
                  painter: _BioPayStandbyOvalPainter(color: iconColor),
                ),
              ),
              if (label != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  label!,
                  style: AppTypography.labelLg.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BioPayStandbyOvalPainter extends CustomPainter {
  const _BioPayStandbyOvalPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final ovalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: 0.30);
    final accentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas
      ..drawOval(rect, ovalPaint)
      ..drawLine(
        Offset(size.width * 0.14, size.height * 0.62),
        Offset(size.width * 0.86, size.height * 0.62),
        accentPaint,
      );
  }

  @override
  bool shouldRepaint(covariant _BioPayStandbyOvalPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _FaceEnrollmentStatusPanel extends StatelessWidget {
  const _FaceEnrollmentStatusPanel({
    required this.title,
    required this.body,
    required this.capturedCount,
    required this.totalSteps,
    required this.sessionReady,
  });

  final String title;
  final String body;
  final int capturedCount;
  final int totalSteps;
  final bool sessionReady;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _bioPayDarkPanel.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: _bioPayBlue.withValues(alpha: 0.07),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              sessionReady ? LucideIcons.scanFace : LucideIcons.camera,
              color: sessionReady
                  ? _bioPayBlue
                  : Colors.white.withValues(alpha: 0.58),
              size: 24,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelLg.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${capturedCount.clamp(0, totalSteps)}/$totalSteps',
                        style: AppTypography.labelLg.copyWith(
                          color: _bioPayBlue,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySm.copyWith(
                      color: Colors.white.withValues(alpha: 0.70),
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BioPayFlowScreen extends StatelessWidget {
  const _BioPayFlowScreen({
    required this.title,
    required this.icon,
    required this.primaryLabel,
    required this.onBack,
    required this.child,
    this.onPrimary,
    this.isPrimaryLoading = false,
  });

  final String title;
  final IconData icon;
  final String primaryLabel;
  final VoidCallback onBack;
  final Widget child;
  final VoidCallback? onPrimary;
  final bool isPrimaryLoading;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _bioPayLightTheme(context),
      child: Scaffold(
        backgroundColor: _bioPayCanvas,
        body: _BioPayLightCanvas(
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 132),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _BioPayBackAvatar(onTap: onBack),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleMd.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _BioPayIconBox(
                        icon: icon,
                        color: Colors.white,
                        background: _bioPayChrome,
                      ),
                    ],
                  ),
                  const SizedBox(height: 42),
                  child,
                  if (primaryLabel.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    MobiButton(
                      onPressed: onPrimary,
                      isLoading: isPrimaryLoading,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: 19,
                      ),
                      child: Text(primaryLabel),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BioPayBackAvatar extends StatelessWidget {
  const _BioPayBackAvatar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: Tooltip(
        message: 'Back',
        child: SizedBox.square(
          dimension: 42,
          child: Material(
            color: _bioPayChrome,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
            ),
            elevation: 8,
            shadowColor: _bioPayBlue.withValues(alpha: 0.10),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: const Icon(
                LucideIcons.chevronLeft,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _canRunExternalAction(BioPayUssdPaymentRequest? request) {
  return request?.status == BioPayRequestStatus.readyToDial ||
      request?.status == BioPayRequestStatus.dialerOpened;
}

int _amountMinorFromController(TextEditingController controller) {
  final digits = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
  final amountMajor = int.tryParse(digits);
  if (amountMajor == null || amountMajor <= 0) {
    throw const FormatException('amount_required');
  }
  return amountMajor * 100;
}

int _optionalAmountMinorFromController(TextEditingController controller) {
  final digits = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  final amountMajor = int.tryParse(digits);
  if (amountMajor == null || amountMajor < 0) {
    throw const FormatException('amount_invalid');
  }
  return amountMajor * 100;
}

String _momoReceiverDisplay(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('250') && digits.length == 12) {
    return '0${digits.substring(3)}';
  }
  if (digits.startsWith('0')) return digits;
  if (digits.length == 9) return '0$digits';
  return digits;
}

String _momoPayCodeDisplay(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}

String _momoReceiverForRequest(String value, {required bool usesCode}) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (usesCode) return digits;

  final normalized = PhoneNumberNormalizer.normalizeForCountry(
    phone: digits,
    countryCode: '+250',
  );
  if (!PhoneNumberNormalizer.isValidCanonical(normalized)) return '';
  return _momoReceiverDisplay(normalized);
}

String buildBioPayQrPayload(BioPayUssdPaymentRequest request) {
  return jsonEncode({
    'type': 'mobio_biopay_request',
    'token': request.token,
    'payee_label': request.payeeLabel,
    'amount_minor': request.amountMinor,
    'currency': request.currency,
    'reference': request.reference,
  });
}

String bioPayTokenFromPayload(String? rawValue) {
  final raw = rawValue?.trim();
  if (raw == null || raw.isEmpty) return '';

  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      for (final key in const ['token', 'biopay_token', 'payment_token']) {
        final value = decoded[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return '';
    }
  } on FormatException {
    // Older QR/NFC payloads may be a bare token.
  }

  final uri = Uri.tryParse(raw);
  final token = uri?.queryParameters['token']?.trim();
  if (token != null && token.isNotEmpty) return token;

  return raw;
}

String _externalActionLabel(BioPayUssdPaymentRequest request) {
  return switch (request.status) {
    BioPayRequestStatus.readyToDial => 'Dial USSD',
    BioPayRequestStatus.dialerOpened => 'I finished USSD',
    BioPayRequestStatus.userMarkedPaid => 'Waiting confirmation',
    BioPayRequestStatus.confirmed => 'Confirmed',
    BioPayRequestStatus.expired => 'Expired',
    BioPayRequestStatus.cancelled => 'Cancelled',
    BioPayRequestStatus.failed => 'Failed',
    BioPayRequestStatus.draft => 'Prepare request',
  };
}

String _requestStatusLabel(BioPayRequestStatus status) {
  return switch (status) {
    BioPayRequestStatus.readyToDial => 'Ready to dial',
    BioPayRequestStatus.dialerOpened => 'Dialer opened',
    BioPayRequestStatus.userMarkedPaid => 'User marked paid',
    BioPayRequestStatus.confirmed => 'Externally confirmed',
    BioPayRequestStatus.expired => 'Expired',
    BioPayRequestStatus.cancelled => 'Cancelled',
    BioPayRequestStatus.failed => 'Failed',
    BioPayRequestStatus.draft => 'Draft',
  };
}

String _dateLabel(DateTime? value) {
  if (value == null) return 'Not recorded';
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

IconData _channelIcon(BioPayRequestChannel channel) {
  return switch (channel) {
    BioPayRequestChannel.qr => LucideIcons.qrCode,
    BioPayRequestChannel.nfc => LucideIcons.nfc,
    BioPayRequestChannel.face => LucideIcons.scanFace,
  };
}

class _BioPayReceiverField extends StatelessWidget {
  const _BioPayReceiverField({
    required this.controller,
    required this.usesCode,
    this.enabled = true,
    this.onModeChanged,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool usesCode;
  final bool enabled;
  final ValueChanged<bool>? onModeChanged;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 300,
            height: 64,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _bioPayDarkPanel.withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(AppRadii.xxl),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: _bioPayBlue.withValues(alpha: 0.07),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                _QrReceiverModeButton(
                  label: 'Number',
                  selected: !usesCode,
                  enabled: enabled,
                  onTap: () => onModeChanged?.call(false),
                ),
                _QrReceiverModeButton(
                  label: 'Code',
                  selected: usesCode,
                  enabled: enabled,
                  onTap: () => onModeChanged?.call(true),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 88,
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: onChanged,
            style: AppTypography.displayMd.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
            decoration: InputDecoration(
              hintText: usesCode ? 'MoMo Pay code' : 'MoMo number',
              hintStyle: AppTypography.titleLg.copyWith(
                color: Colors.white.withValues(alpha: 0.36),
                fontWeight: FontWeight.w800,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              filled: true,
              fillColor: _bioPayDarkPanel.withValues(alpha: 0.74),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: _bioPayBlue, width: 1.4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QrReceiverModeButton extends StatelessWidget {
  const _QrReceiverModeButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : null,
            gradient: selected
                ? const LinearGradient(colors: [_bioPayInk, Color(0xFF1D2939)])
                : null,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: AppTypography.titleMd.copyWith(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.68),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _BioPayReceiveAmountField extends StatefulWidget {
  const _BioPayReceiveAmountField({
    required this.controller,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  State<_BioPayReceiveAmountField> createState() =>
      _BioPayReceiveAmountFieldState();
}

class _BioPayReceiveAmountFieldState extends State<_BioPayReceiveAmountField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleInputStateChanged);
    _focusNode.addListener(_handleInputStateChanged);
  }

  @override
  void didUpdateWidget(covariant _BioPayReceiveAmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleInputStateChanged);
      widget.controller.addListener(_handleInputStateChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleInputStateChanged);
    _focusNode
      ..removeListener(_handleInputStateChanged)
      ..dispose();
    super.dispose();
  }

  void _handleInputStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final showPlaceholder =
        widget.controller.text.isEmpty && !_focusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: Colors.white.withValues(alpha: 0.12), height: 32),
        Text(
          'AMOUNT',
          style: AppTypography.labelLg.copyWith(
            color: Colors.white.withValues(alpha: 0.68),
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.done,
                inputFormatters: const [GroupedWholeNumberTextInputFormatter()],
                onChanged: widget.onChanged,
                style: AppTypography.displayMd.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
                decoration: InputDecoration(
                  prefixText: widget.controller.text.isEmpty ? null : 'RWF ',
                  prefixStyle: AppTypography.displayMd.copyWith(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.lg,
                  ),
                  filled: true,
                  fillColor: _bioPayDarkPanel.withValues(alpha: 0.74),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: _bioPayBlue,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              if (showPlaceholder)
                IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'RWF ',
                        style: AppTypography.displayMd.copyWith(
                          color: Colors.white.withValues(alpha: 0.70),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      Text(
                        '0.00',
                        style: AppTypography.displayMd.copyWith(
                          color: Colors.white.withValues(alpha: 0.38),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResolvedPaymentPreview extends StatelessWidget {
  const _ResolvedPaymentPreview({required this.request});

  final BioPayUssdPaymentRequest request;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailRow(label: 'Payee', value: request.payeeLabel),
        _DetailRow(label: 'Amount', value: request.amountLabel),
        _DetailRow(label: 'Reference', value: request.reference),
        _DetailRow(label: 'Status', value: _requestStatusLabel(request.status)),
        const _DetailRow(label: 'Confirmation', value: 'External'),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Icon(LucideIcons.phoneCall, size: 18, color: cs.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Tap Dial USSD to open the phone dialer',
                style: AppTypography.bodyMd.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QrPreview extends StatelessWidget {
  const _QrPreview({required this.request, required this.onShare});

  final BioPayUssdPaymentRequest request;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              boxShadow: [
                BoxShadow(
                  color: _bioPayBlue.withValues(alpha: 0.10),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Center(
              child: QrImageView(
                data: buildBioPayQrPayload(request),
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: _bioPayInk,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: _bioPayInk,
                ),
                padding: const EdgeInsets.all(AppSpacing.xl),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        MobiButton(
          onPressed: onShare,
          width: double.infinity,
          variant: MobiButtonVariant.ghost,
          child: const Text('Share QR Code'),
        ),
      ],
    );
  }
}

class _NfcReadyHint extends StatelessWidget {
  const _NfcReadyHint();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: _bioPayDarkPanel.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: _bioPayNfcPurple.withValues(alpha: 0.10),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xl,
            ),
            child: Column(
              children: [
                _BioPayIconBox(
                  icon: LucideIcons.nfc,
                  color: cs.primary,
                  background: cs.primary.withValues(alpha: 0.10),
                  dimension: 58,
                  iconSize: 28,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Receive with NFC',
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineSm.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QrScannerSurface extends StatefulWidget {
  const _QrScannerSurface({required this.onDetect, this.error});

  final ValueChanged<String> onDetect;
  final String? error;

  @override
  State<_QrScannerSurface> createState() => _QrScannerSurfaceState();
}

class _QrScannerSurfaceState extends State<_QrScannerSurface> {
  late final MobileScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
      cameraResolution: const Size(1920, 1080),
      autoZoom: true,
      initialZoom: 0.18,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  fit: BoxFit.cover,
                  tapToFocus: true,
                  onDetect: (capture) {
                    final value = capture.barcodes.firstOrNull?.rawValue;
                    if (value != null) widget.onDetect(value);
                  },
                  errorBuilder: (context, error) => DecoratedBox(
                    decoration: const BoxDecoration(color: Colors.black),
                    child: Center(
                      child: Icon(
                        LucideIcons.scanLine,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.54),
                      ),
                    ),
                  ),
                ),
                const _QrScannerCornerGuide(),
                Positioned(
                  right: 14,
                  top: 14,
                  child: IconButton.filledTonal(
                    tooltip: 'Torch',
                    onPressed: _controller.toggleTorch,
                    icon: const Icon(LucideIcons.flashlight),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: AppSpacing.md),
          _InlineError(message: widget.error!),
        ],
      ],
    );
  }
}

class _QrScannerCornerGuide extends StatelessWidget {
  const _QrScannerCornerGuide();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _QrScannerCornerPainter()),
    );
  }
}

class _QrScannerCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height) * 0.58;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: side,
      height: side,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFCC00);
    const length = 34.0;

    canvas
      ..drawLine(rect.topLeft, rect.topLeft.translate(length, 0), paint)
      ..drawLine(rect.topLeft, rect.topLeft.translate(0, length), paint)
      ..drawLine(rect.topRight, rect.topRight.translate(-length, 0), paint)
      ..drawLine(rect.topRight, rect.topRight.translate(0, length), paint)
      ..drawLine(rect.bottomLeft, rect.bottomLeft.translate(length, 0), paint)
      ..drawLine(rect.bottomLeft, rect.bottomLeft.translate(0, -length), paint)
      ..drawLine(
        rect.bottomRight,
        rect.bottomRight.translate(-length, 0),
        paint,
      )
      ..drawLine(
        rect.bottomRight,
        rect.bottomRight.translate(0, -length),
        paint,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(LucideIcons.alertTriangle, color: cs.error, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: AppTypography.bodyMd.copyWith(
              color: cs.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMd.copyWith(
                color: Colors.white.withValues(alpha: 0.68),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: AppTypography.titleMd.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
