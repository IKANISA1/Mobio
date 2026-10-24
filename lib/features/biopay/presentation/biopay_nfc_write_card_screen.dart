import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/biopay/data/biopay_nfc_card_payload.dart';
import 'package:mobi_app/features/biopay/data/biopay_nfc_service.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_flow_shared.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_nfc_foreground_listener.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_style.dart';
import 'package:mobi_app/features/biopay/presentation/payment_composer_screen.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_design_system/theme/app_colors.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';

class BioPayNfcWriteCardScreen extends ConsumerStatefulWidget {
  const BioPayNfcWriteCardScreen({
    super.key,
    required this.onBack,
    this.nfcService = const BioPayNfcService(),
  }) : _captureOverride = null,
       _isCurrentOverride = null;
  @visibleForTesting
  const BioPayNfcWriteCardScreen.test({
    super.key,
    required this.onBack,
    required AccountSnapshot Function() captureAccount,
    required bool Function(AccountSnapshot) isCurrent,
    this.nfcService = const BioPayNfcService(),
  }) : _captureOverride = captureAccount,
       _isCurrentOverride = isCurrent;

  final VoidCallback onBack;
  final BioPayNfcService nfcService;
  final AccountSnapshot Function()? _captureOverride;
  final bool Function(AccountSnapshot)? _isCurrentOverride;

  @override
  ConsumerState<BioPayNfcWriteCardScreen> createState() =>
      _BioPayNfcWriteCardScreenState();
}

class _BioPayNfcWriteCardScreenState
    extends ConsumerState<BioPayNfcWriteCardScreen>
    with WidgetsBindingObserver {
  BioPayNfcService get _nfcService => widget.nfcService;
  late final BioPayNfcForegroundSuspendedNotifier _foreground;
  AccountSnapshot? _viewAccount;
  int _revision = 0;
  int? _suspension;
  bool _accountLost = false;
  bool _foregroundActive = true;

  bool _current(AccountSnapshot? account, int revision) =>
      mounted &&
      _foregroundActive &&
      !_accountLost &&
      revision == _revision &&
      (account == null
          ? SupabaseConfig.isLocalUiPreview && widget._captureOverride == null
          : widget._isCurrentOverride?.call(account) ??
                AccountContext.isCurrent(account));

  void _accountChanged() {
    final account = _viewAccount;
    final current = account == null
        ? SupabaseConfig.isLocalUiPreview && widget._captureOverride == null
        : widget._isCurrentOverride?.call(account) ??
              AccountContext.isCurrent(account);
    if (_accountLost || current) return;
    _accountLost = true;
    _revision++;
    _receiverController.clear();
    setState(() {
      _step = _NfcWriteStep.idle;
      _writtenPayload = null;
      _tagLabel = null;
      _cardLocked = false;
      _canLockCard = false;
      _error = 'Account changed. Sign in again.';
    });
    unawaited(_cancelAndRelease(_suspension));
  }

  int _suspendForeground() {
    final lease = _foreground.acquireSuspension();
    _suspension = lease;
    return lease;
  }

  void _releaseForeground(int? lease) {
    if (lease == null) return;
    if (_suspension == lease) _suspension = null;
    _foreground.releaseSuspension(lease);
  }

  Future<void> _cancelAndRelease(int? lease) async {
    if (lease == null || !_foreground.ownsSuspension(lease)) return;
    try {
      await _nfcService.cancelActiveSession();
    } finally {
      _releaseForeground(lease);
    }
  }

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
    WidgetsBinding.instance.addObserver(this);
    _foreground = ref.read(bioPayNfcForegroundSuspendedProvider.notifier);
    try {
      _viewAccount =
          widget._captureOverride?.call() ??
          (SupabaseConfig.isLocalUiPreview ? null : AccountContext.capture());
    } on Object {
      _accountLost = true;
      _error = 'Sign in again.';
    }
    AccountContext.changes.addListener(_accountChanged);
    Future<void>.microtask(() {
      if (_current(_viewAccount, _revision)) _suspendForeground();
    });
  }

  @override
  void dispose() {
    _revision++;
    AccountContext.changes.removeListener(_accountChanged);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_cancelAndRelease(_suspension));
    _receiverController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() => _foregroundActive = true);
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _foregroundActive = false;
      _revision++;
      if (mounted) setState(() => _step = _NfcWriteStep.idle);
      unawaited(_cancelAndRelease(_suspension));
    }
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
    final account = _viewAccount;
    final revision = _revision;
    if (_busy || !_current(account, revision)) return;
    final payload = _previewPayload();
    if (payload == null) {
      setState(() => _error = 'Enter a valid MoMo number or MoMo Pay code.');
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentAccountView(
        isCurrent: () => _current(account, revision),
        child: _NfcWriteConfirmationSheet(payload: payload),
      ),
    );
    if (confirmed != true || !_current(account, revision)) return;

    await _writeCard(payload, account);
  }

  Future<void> _writeCard(
    BioPayNfcCardPayload payload,
    AccountSnapshot? account,
  ) async {
    final revision = ++_revision;
    final lease = _suspendForeground();
    setState(() {
      _step = _NfcWriteStep.waiting;
      _writtenPayload = null;
      _tagLabel = null;
      _cardLocked = false;
      _canLockCard = false;
      _error = null;
    });
    try {
      await _nfcService.cancelActiveSession();
      if (!_current(account, revision) || !_foreground.ownsSuspension(lease)) {
        return;
      }
      final result = await _nfcService.writeCard(
        payload,
        onStep: (step) {
          if (!_current(account, revision) ||
              !_foreground.ownsSuspension(lease)) {
            throw const StaleAccountWork();
          }
          _setOperationStep(step);
        },
      );
      if (!_current(account, revision) || !_foreground.ownsSuspension(lease)) {
        return;
      }
      setState(() {
        _step = _NfcWriteStep.idle;
        _writtenPayload = payload;
        _tagLabel = result.diagnostics.tagLabel;
        _canLockCard = result.diagnostics.ndefCanMakeReadOnly == true;
      });
    } on Object catch (error) {
      if (!_current(account, revision) || !_foreground.ownsSuspension(lease)) {
        return;
      }
      await _nfcService.finishWithError('BioPay NFC write failed');
      _logNfcError(error);
      if (!_current(account, revision)) return;
      setState(() {
        _step = _NfcWriteStep.idle;
        _error = _nfcWriteErrorLabel(error);
      });
    } finally {
      _releaseForeground(lease);
    }
  }

  Future<void> _confirmAndLockCard() async {
    final account = _viewAccount;
    final revision = _revision;
    final payload = _writtenPayload;
    if (payload == null ||
        _busy ||
        _cardLocked ||
        !_current(account, revision)) {
      return;
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentAccountView(
        isCurrent: () => _current(account, revision),
        child: const _NfcLockConfirmationSheet(),
      ),
    );
    if (confirmed != true ||
        !_current(account, revision) ||
        !identical(payload, _writtenPayload)) {
      return;
    }
    final lease = _suspendForeground();
    setState(() {
      _step = _NfcWriteStep.waiting;
      _error = null;
    });
    try {
      await _nfcService.cancelActiveSession();
      if (!_current(account, revision) || !_foreground.ownsSuspension(lease)) {
        return;
      }
      final result = await _nfcService.lockVerifiedCard(
        payload,
        onStep: (step) {
          if (!_current(account, revision) ||
              !_foreground.ownsSuspension(lease)) {
            throw const StaleAccountWork();
          }
          _setOperationStep(step);
        },
      );
      if (!_current(account, revision) || !_foreground.ownsSuspension(lease)) {
        return;
      }
      setState(() {
        _step = _NfcWriteStep.idle;
        _cardLocked = true;
        _canLockCard = false;
        _tagLabel = result.diagnostics.tagLabel;
      });
    } on Object catch (error) {
      if (!_current(account, revision) || !_foreground.ownsSuspension(lease)) {
        return;
      }
      await _nfcService.finishWithError('BioPay NFC lock failed');
      _logNfcError(error);
      if (!_current(account, revision)) return;
      setState(() {
        _step = _NfcWriteStep.idle;
        _error = _nfcWriteErrorLabel(error);
      });
    } finally {
      _releaseForeground(lease);
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
    if (error is MutationOutcomeUnknownException) return error.message;
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
    final canWrite =
        !_busy && hasValidReceiver && _current(_viewAccount, _revision);
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
          if (!_accountLost && _writtenPayload == null) ...[
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
          ] else if (!_accountLost) ...[
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
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 80),
              child: Semantics(
                label: selected == BioPayNfcReceiverType.momoNumber
                    ? 'MoMo number'
                    : 'MoMo Pay code',
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: onTextChanged,
                  style: AppTypography.displayMd.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                  decoration: InputDecoration(
                    hintText: selected == BioPayNfcReceiverType.momoNumber
                        ? 'MoMo number'
                        : 'MoMo Pay code',
                    hintStyle: AppTypography.titleLg.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
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
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: enabled ? 1 : 0.48,
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : Colors.transparent,
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
                        fontWeight: FontWeight.w600,
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
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
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
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                  color: Theme.of(context).colorScheme.outlineVariant,
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
        ? AppColors.success
        : active
        ? bioPayNfcPurple
        : Theme.of(context).colorScheme.onSurfaceVariant;

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
              color: completed ? AppColors.onSuccess : color,
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
            color: active || completed
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
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
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(26),
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
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _NfcDetailRow(label: 'USSD', value: payload.ussdCode),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'The card will be verified after writing. You can lock it permanently after a successful write.',
                  style: AppTypography.bodySm.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(26),
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
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Locking makes the NFC card read-only and usually cannot be undone. Hold the same verified card to continue.',
                  style: AppTypography.bodyMd.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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

class _NfcDetailRow extends StatelessWidget {
  const _NfcDetailRow({required this.label, required this.value});

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
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.labelLg.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
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
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BioPayIconBox(
              icon: LucideIcons.check,
              color: Colors.white,
              background: AppColors.success,
              dimension: 58,
              iconSize: 28,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              locked ? 'Card written and locked' : 'Card written and verified',
              textAlign: TextAlign.center,
              style: AppTypography.headlineSm.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
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
              child: const Text('Write Another'),
            ),
          ],
        ),
      ),
    );
  }
}
