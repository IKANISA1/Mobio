import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/biopay/biopay_flow_shared.dart';
import 'package:mobi_app/features/biopay/biopay_nfc_card_payload.dart';
import 'package:mobi_app/features/biopay/biopay_nfc_foreground_listener.dart';
import 'package:mobi_app/features/biopay/biopay_nfc_service.dart';
import 'package:mobi_app/features/biopay/biopay_style.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';

class BioPayNfcWriteCardScreen extends ConsumerStatefulWidget {
  const BioPayNfcWriteCardScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<BioPayNfcWriteCardScreen> createState() =>
      _BioPayNfcWriteCardScreenState();
}

class _BioPayNfcWriteCardScreenState
    extends ConsumerState<BioPayNfcWriteCardScreen> {
  static const _nfcService = BioPayNfcService();

  final TextEditingController _receiverController = TextEditingController();
  BioPayNfcReceiverType _receiverType = BioPayNfcReceiverType.momoNumber;
  _NfcWriteStep _step = _NfcWriteStep.idle;
  BioPayNfcCardPayload? _writtenPayload;
  String? _tagLabel;
  bool _cardLocked = false;
  bool _canLockCard = false;
  String? _error;

  bool get _busy => _step != _NfcWriteStep.idle;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) return;
      ref
          .read(bioPayNfcForegroundSuspendedProvider.notifier)
          .setSuspended(true);
    });
  }

  @override
  void dispose() {
    try {
      ref
          .read(bioPayNfcForegroundSuspendedProvider.notifier)
          .setSuspended(false);
    } on Object {
      // The surrounding ProviderScope may already be disposed in tests.
    }
    _receiverController.dispose();
    super.dispose();
  }

  void _onReceiverTypeChanged(BioPayNfcReceiverType receiverType) {
    if (_busy) return;
    setState(() {
      _receiverType = receiverType;
      _receiverController.clear();
      _writtenPayload = null;
      _tagLabel = null;
      _cardLocked = false;
      _canLockCard = false;
      _error = null;
    });
  }

  BioPayNfcCardPayload? _previewPayload() {
    final receiver = normalizeBioPayNfcReceiver(
      _receiverController.text,
      receiverType: _receiverType,
    );
    if (receiver.isEmpty) return null;
    return BioPayNfcCardPayload(
      receiverType: _receiverType,
      receiver: receiver,
    );
  }

  Future<void> _confirmAndWrite() async {
    final payload = _previewPayload();
    if (payload == null) {
      setState(() => _error = 'Enter a valid MoMo number or MoMo Pay code.');
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _NfcWriteConfirmationSheet(payload: payload),
    );
    if (confirmed != true || !mounted) return;

    await _writeCard(payload);
  }

  Future<void> _writeCard(BioPayNfcCardPayload payload) async {
    ref.read(bioPayNfcForegroundSuspendedProvider.notifier).setSuspended(true);
    await _nfcService.cancelActiveSession();
    setState(() {
      _step = _NfcWriteStep.waiting;
      _writtenPayload = null;
      _tagLabel = null;
      _cardLocked = false;
      _canLockCard = false;
      _error = null;
    });

    try {
      final result = await _nfcService.writeCard(
        payload,
        onStep: _setOperationStep,
      );
      if (!mounted) return;
      setState(() {
        _step = _NfcWriteStep.idle;
        _writtenPayload = payload;
        _tagLabel = result.diagnostics.tagLabel;
        _canLockCard = result.diagnostics.ndefCanMakeReadOnly == true;
      });
    } on Object catch (error) {
      await _nfcService.finishWithError('BioPay NFC write failed');
      _logNfcError(error);
      if (!mounted) return;
      setState(() {
        _step = _NfcWriteStep.idle;
        _error = _nfcWriteErrorLabel(error);
      });
    } finally {
      _resumeForegroundListener();
    }
  }

  Future<void> _confirmAndLockCard() async {
    final payload = _writtenPayload;
    if (payload == null || _busy || _cardLocked) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _NfcLockConfirmationSheet(),
    );
    if (confirmed != true || !mounted) return;

    ref.read(bioPayNfcForegroundSuspendedProvider.notifier).setSuspended(true);
    await _nfcService.cancelActiveSession();
    setState(() {
      _step = _NfcWriteStep.waiting;
      _error = null;
    });

    try {
      final result = await _nfcService.lockVerifiedCard(
        payload,
        onStep: _setOperationStep,
      );
      if (!mounted) return;
      setState(() {
        _step = _NfcWriteStep.idle;
        _cardLocked = true;
        _canLockCard = false;
        _tagLabel = result.diagnostics.tagLabel;
      });
    } on Object catch (error) {
      await _nfcService.finishWithError('BioPay NFC lock failed');
      _logNfcError(error);
      if (!mounted) return;
      setState(() {
        _step = _NfcWriteStep.idle;
        _error = _nfcWriteErrorLabel(error);
      });
    } finally {
      _resumeForegroundListener();
    }
  }

  void _setOperationStep(BioPayNfcOperationStep step) {
    if (!mounted) return;
    setState(() {
      _step = switch (step) {
        BioPayNfcOperationStep.waiting => _NfcWriteStep.waiting,
        BioPayNfcOperationStep.writing => _NfcWriteStep.writing,
        BioPayNfcOperationStep.verifying => _NfcWriteStep.verifying,
        BioPayNfcOperationStep.locking => _NfcWriteStep.locking,
      };
    });
  }

  void _resumeForegroundListener() {
    try {
      ref
          .read(bioPayNfcForegroundSuspendedProvider.notifier)
          .setSuspended(false);
    } on Object {
      // The surrounding ProviderScope may already be disposed in tests.
    }
  }

  void _logNfcError(Object error) {
    if (error is BioPayNfcException) {
      AppLogger.warning(
        'NFC write failed: ${error.message} ${error.diagnostics?.logSummary ?? ''}',
        context: 'BioPayNfc',
        error: error,
      );
      return;
    }
    AppLogger.warning(
      'NFC write failed: $error',
      context: 'BioPayNfc',
      error: error,
    );
  }

  String _nfcWriteErrorLabel(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('disabled')) return 'NFC is disabled.';
    if (message.contains('not supported')) return 'NFC is not supported.';
    if (message.contains('not writable')) return 'NFC card is not writable.';
    if (message.contains('too small')) return 'NFC card is too small.';
    if (message.contains('cannot be locked')) {
      return 'This NFC card cannot be locked by this device.';
    }
    if (message.contains('not the verified')) {
      return 'Hold the same verified NFC card to lock it.';
    }
    if (message.contains('verification')) {
      return 'NFC card verification failed. Keep the card still and try again.';
    }
    return 'NFC card write failed.';
  }

  void _writeAnother() {
    if (_busy) return;
    setState(() {
      _receiverController.clear();
      _writtenPayload = null;
      _tagLabel = null;
      _cardLocked = false;
      _canLockCard = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final payload = _previewPayload();
    final hasValidReceiver = payload != null;
    final canWrite = !_busy && hasValidReceiver;
    final VoidCallback? primaryAction = _writtenPayload == null
        ? canWrite
              ? _confirmAndWrite
              : null
        : widget.onBack;

    return BioPayFlowScreen(
      title: 'Write NFC',
      primaryLabel: _writtenPayload == null ? 'Write NFC' : 'Done',
      isPrimaryLoading: _busy,
      onBack: widget.onBack,
      onPrimary: primaryAction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_writtenPayload == null) ...[
            _NfcReceiverTypePicker(
              controller: _receiverController,
              selected: _receiverType,
              enabled: !_busy,
              onChanged: _onReceiverTypeChanged,
              onTextChanged: (_) => setState(() => _error = null),
            ),
            if (payload != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _NfcUssdPreview(payload: payload),
            ],
          ] else ...[
            _NfcWriteSuccessPanel(
              payload: _writtenPayload!,
              tagLabel: _tagLabel,
              locked: _cardLocked,
              canLock: _canLockCard,
              onLockCard: _confirmAndLockCard,
              onWriteAnother: _writeAnother,
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: AppSpacing.md),
            _NfcWriteProgressPanel(step: _step),
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

enum _NfcWriteStep { idle, waiting, writing, verifying, locking }

class _NfcReceiverTypePicker extends StatelessWidget {
  const _NfcReceiverTypePicker({
    required this.controller,
    required this.selected,
    required this.enabled,
    required this.onChanged,
    required this.onTextChanged,
  });

  final TextEditingController controller;
  final BioPayNfcReceiverType selected;
  final bool enabled;
  final ValueChanged<BioPayNfcReceiverType> onChanged;
  final ValueChanged<String> onTextChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bioPayDarkPanel.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: bioPayNfcPurple.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  _NfcReceiverModeButton(
                    icon: LucideIcons.smartphone,
                    label: 'MoMo Number',
                    selected: selected == BioPayNfcReceiverType.momoNumber,
                    enabled: enabled,
                    onTap: () => onChanged(BioPayNfcReceiverType.momoNumber),
                  ),
                  _NfcReceiverModeButton(
                    icon: LucideIcons.store,
                    label: 'MoMo Pay',
                    selected: selected == BioPayNfcReceiverType.momoPayCode,
                    enabled: enabled,
                    onTap: () => onChanged(BioPayNfcReceiverType.momoPayCode),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            SizedBox(
              height: 80,
              child: TextField(
                controller: controller,
                enabled: enabled,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: onTextChanged,
                style: AppTypography.displayMd.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
                decoration: InputDecoration(
                  hintText: selected == BioPayNfcReceiverType.momoNumber
                      ? 'MoMo number'
                      : 'MoMo Pay code',
                  hintStyle: AppTypography.titleLg.copyWith(
                    color: Colors.white.withValues(alpha: 0.36),
                    fontWeight: FontWeight.w800,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.lg,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NfcReceiverModeButton extends StatelessWidget {
  const _NfcReceiverModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final contentColor = selected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.68);

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: enabled ? 1 : 0.48,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Colors.white : null,
                gradient: selected
                    ? const LinearGradient(
                        colors: [bioPayInk, Color(0xFF1D2939)],
                      )
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: contentColor, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: AppTypography.titleMd.copyWith(
                        color: contentColor,
                        fontWeight: FontWeight.w900,
                      ),
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

class _NfcUssdPreview extends StatelessWidget {
  const _NfcUssdPreview({required this.payload});

  final BioPayNfcCardPayload payload;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bioPayDarkPanel.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: bioPayNfcPurple.withValues(alpha: 0.10),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const BioPayIconBox(
                  icon: LucideIcons.nfc,
                  color: Colors.white,
                  background: bioPayNfcPurple,
                  dimension: 44,
                  iconSize: 22,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Ready to write',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMd.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            BioPayDetailRow(label: 'USSD', value: payload.ussdCode),
          ],
        ),
      ),
    );
  }
}

class _NfcWriteProgressPanel extends StatelessWidget {
  const _NfcWriteProgressPanel({required this.step});

  final _NfcWriteStep step;

  @override
  Widget build(BuildContext context) {
    const steps = [
      _NfcWriteProgressStep(
        step: _NfcWriteStep.waiting,
        label: 'Hold card',
        icon: LucideIcons.radioTower,
      ),
      _NfcWriteProgressStep(
        step: _NfcWriteStep.writing,
        label: 'Writing',
        icon: LucideIcons.pencil,
      ),
      _NfcWriteProgressStep(
        step: _NfcWriteStep.verifying,
        label: 'Verifying',
        icon: LucideIcons.shieldCheck,
      ),
      _NfcWriteProgressStep(
        step: _NfcWriteStep.locking,
        label: 'Locking',
        icon: LucideIcons.lock,
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bioPayDarkPanel.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            for (final item in steps) ...[
              Expanded(
                child: _NfcProgressItem(
                  item: item,
                  active: item.step == step,
                  completed: item.step.index < step.index,
                ),
              ),
              if (item != steps.last)
                Container(
                  width: 10,
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.16),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NfcWriteProgressStep {
  const _NfcWriteProgressStep({
    required this.step,
    required this.label,
    required this.icon,
  });

  final _NfcWriteStep step;
  final String label;
  final IconData icon;
}

class _NfcProgressItem extends StatelessWidget {
  const _NfcProgressItem({
    required this.item,
    required this.active,
    required this.completed,
  });

  final _NfcWriteProgressStep item;
  final bool active;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final color = completed
        ? const Color(0xFF22C55E)
        : active
        ? bioPayNfcPurple
        : Colors.white.withValues(alpha: 0.38);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 34,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: completed ? 1 : 0.16),
              border: Border.all(color: color),
            ),
            child: Icon(
              completed ? LucideIcons.check : item.icon,
              color: completed ? Colors.white : color,
              size: 17,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelSm.copyWith(
            color: Colors.white.withValues(
              alpha: active || completed ? 1 : 0.55,
            ),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _NfcWriteConfirmationSheet extends StatelessWidget {
  const _NfcWriteConfirmationSheet({required this.payload});

  final BioPayNfcCardPayload payload;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bioPayCanvas,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const BioPayIconBox(
                      icon: LucideIcons.pencil,
                      color: Colors.white,
                      background: bioPayNfcPurple,
                      dimension: 44,
                      iconSize: 21,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Write NFC',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleLg.copyWith(
                          color: bioPayInk,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _LightDetailRow(label: 'USSD', value: payload.ussdCode),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'The card will be verified after writing. You can lock it permanently after a successful write.',
                  style: AppTypography.bodySm.copyWith(color: bioPayMuted),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: MobiButton(
                        variant: MobiButtonVariant.ghost,
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: MobiButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Write'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NfcLockConfirmationSheet extends StatelessWidget {
  const _NfcLockConfirmationSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bioPayCanvas,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const BioPayIconBox(
                      icon: LucideIcons.lock,
                      color: Colors.white,
                      background: bioPayNfcPurple,
                      dimension: 44,
                      iconSize: 21,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Lock card',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleLg.copyWith(
                          color: bioPayInk,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Locking makes the NFC card read-only and usually cannot be undone. Hold the same verified card to continue.',
                  style: AppTypography.bodyMd.copyWith(color: bioPayMuted),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: MobiButton(
                        variant: MobiButtonVariant.ghost,
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: MobiButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Lock'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LightDetailRow extends StatelessWidget {
  const _LightDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: AppTypography.labelMd.copyWith(
                color: bioPayMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.labelLg.copyWith(
                color: bioPayInk,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NfcWriteSuccessPanel extends StatelessWidget {
  const _NfcWriteSuccessPanel({
    required this.payload,
    required this.tagLabel,
    required this.locked,
    required this.canLock,
    required this.onLockCard,
    required this.onWriteAnother,
  });

  final BioPayNfcCardPayload payload;
  final String? tagLabel;
  final bool locked;
  final bool canLock;
  final VoidCallback onLockCard;
  final VoidCallback onWriteAnother;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bioPayDarkPanel.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withValues(alpha: 0.10),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BioPayIconBox(
              icon: LucideIcons.check,
              color: Colors.white,
              background: Color(0xFF22C55E),
              dimension: 58,
              iconSize: 28,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              locked ? 'Card written and locked' : 'Card written and verified',
              textAlign: TextAlign.center,
              style: AppTypography.headlineSm.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            BioPayDetailRow(label: 'Type', value: payload.receiverTypeLabel),
            BioPayDetailRow(label: 'Receiver', value: payload.receiver),
            BioPayDetailRow(label: 'USSD', value: payload.ussdCode),
            BioPayDetailRow(
              label: 'Status',
              value: locked ? 'Locked' : 'Writable',
            ),
            if (tagLabel != null)
              BioPayDetailRow(label: 'NFC', value: tagLabel!),
            const SizedBox(height: AppSpacing.lg),
            if (canLock && !locked) ...[
              MobiButton(
                onPressed: onLockCard,
                width: double.infinity,
                child: const Text('Lock Card'),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            MobiButton(
              onPressed: onWriteAnother,
              width: double.infinity,
              variant: MobiButtonVariant.ghost,
              child: const Text(
                'Write Another',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
