import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/features/biopay/biopay_flow_shared.dart';
import 'package:mobi_app/features/biopay/biopay_nfc_card_payload.dart';
import 'package:mobi_app/features/biopay/biopay_nfc_foreground_listener.dart';
import 'package:mobi_app/features/biopay/biopay_style.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:ndef/ndef.dart' as ndef;

class BioPayNfcWriteCardScreen extends ConsumerStatefulWidget {
  const BioPayNfcWriteCardScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<BioPayNfcWriteCardScreen> createState() =>
      _BioPayNfcWriteCardScreenState();
}

class _BioPayNfcWriteCardScreenState
    extends ConsumerState<BioPayNfcWriteCardScreen> {
  final TextEditingController _receiverController = TextEditingController();
  BioPayNfcReceiverType _receiverType = BioPayNfcReceiverType.momoNumber;
  _NfcWriteStep _step = _NfcWriteStep.idle;
  BioPayNfcCardPayload? _writtenPayload;
  String? _tagLabel;
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

    await _writeAndLock(payload);
  }

  Future<void> _writeAndLock(BioPayNfcCardPayload payload) async {
    ref.read(bioPayNfcForegroundSuspendedProvider.notifier).setSuspended(true);
    setState(() {
      _step = _NfcWriteStep.waiting;
      _writtenPayload = null;
      _tagLabel = null;
      _error = null;
    });

    try {
      await _ensureNfcAvailable();
      final tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 25),
        iosAlertMessage: 'Hold near the blank NFC card',
      );
      if (!mounted) return;
      setState(() => _step = _NfcWriteStep.writing);

      if (tag.ndefWritable == false) {
        throw StateError('This NFC card is not writable.');
      }

      final records = buildBioPayNfcCardRecords(payload);
      final encodedSize = ndef.encodeNdefMessage(records).length;
      final capacity = tag.ndefCapacity;
      if (capacity != null && capacity > 0 && encodedSize > capacity) {
        throw StateError('This NFC card is too small.');
      }

      await FlutterNfcKit.writeNDEFRecords(records);
      if (!mounted) return;
      setState(() => _step = _NfcWriteStep.verifying);

      final writtenPayload = await readBioPayNfcCardPayloadFromActiveTag();
      if (writtenPayload == null ||
          writtenPayload.ussdCode != payload.ussdCode) {
        throw StateError('NFC card verification failed.');
      }

      if (!mounted) return;
      setState(() => _step = _NfcWriteStep.locking);
      await FlutterNfcKit.makeNdefReadOnly();
      await FlutterNfcKit.finish(iosAlertMessage: 'BioPay card written');
      if (!mounted) return;
      setState(() {
        _step = _NfcWriteStep.idle;
        _writtenPayload = payload;
        _tagLabel = tag.id.isEmpty ? tag.standard : 'Tag ${tag.id}';
      });
    } on Object catch (error) {
      await _finishNfcWithError();
      if (!mounted) return;
      setState(() {
        _step = _NfcWriteStep.idle;
        _error = _nfcWriteErrorLabel(error);
      });
    } finally {
      if (!mounted) {
        ref
            .read(bioPayNfcForegroundSuspendedProvider.notifier)
            .setSuspended(false);
      }
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
      await FlutterNfcKit.finish(iosErrorMessage: 'BioPay NFC write failed');
    } on Object {
      // Session may not have started.
    }
  }

  String _nfcWriteErrorLabel(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('disabled')) return 'NFC is disabled.';
    if (message.contains('not supported')) return 'NFC is not supported.';
    if (message.contains('not writable')) return 'NFC card is not writable.';
    if (message.contains('too small')) return 'NFC card is too small.';
    if (message.contains('verification')) {
      return 'NFC card verification failed.';
    }
    return 'NFC card write failed.';
  }

  void _writeAnother() {
    if (_busy) return;
    setState(() {
      _receiverController.clear();
      _writtenPayload = null;
      _tagLabel = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final payload = _previewPayload();

    return BioPayFlowScreen(
      title: 'Write NFC',
      primaryLabel: _writtenPayload == null ? 'Write & Lock NFC' : 'Done',
      isPrimaryLoading: _busy,
      onBack: widget.onBack,
      onPrimary: _writtenPayload == null ? _confirmAndWrite : widget.onBack,
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
                      icon: LucideIcons.lock,
                      color: Colors.white,
                      background: bioPayNfcPurple,
                      dimension: 44,
                      iconSize: 21,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Write & Lock',
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
    required this.onWriteAnother,
  });

  final BioPayNfcCardPayload payload;
  final String? tagLabel;
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
              'Card written and locked',
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
            if (tagLabel != null)
              BioPayDetailRow(label: 'NFC', value: tagLabel!),
            const SizedBox(height: AppSpacing.lg),
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
