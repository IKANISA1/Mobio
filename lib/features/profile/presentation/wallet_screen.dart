import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/auth/account_action_token.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/utils/mobio_member_id.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_app/features/profile/data/wallet_operation_journal.dart';
import 'package:mobi_app/features/profile/domain/wallet.dart';
import 'package:mobi_app/features/profile/domain/wallet_operation.dart';
import 'package:mobi_app/shared/widgets/mobi_tonal_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_sheet.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_error_state.dart';
import 'package:mobi_app/shared/widgets/mobi_page_header.dart';
import 'package:mobi_app/shared/widgets/mobi_visual_theme.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_design_system/theme/app_colors.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';
import 'package:mobi_design_system/theme/mobi_visual_family.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key, required this.onBack})
    : _captureOverride = null,
      _isCurrentOverride = null;
  @visibleForTesting
  const WalletScreen.test({
    super.key,
    required this.onBack,
    required AccountSnapshot Function() captureAccount,
    required bool Function(AccountSnapshot) isCurrent,
  }) : _captureOverride = captureAccount,
       _isCurrentOverride = isCurrent;
  final AccountSnapshot Function()? _captureOverride;
  final bool Function(AccountSnapshot)? _isCurrentOverride;

  final VoidCallback onBack;

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  static const int _minimumRedemptionTokens = 5000;
  AccountSnapshot? _viewAccount;
  AccountSnapshot? _captureAccount() {
    try {
      return widget._captureOverride?.call() ?? AccountContext.capture();
    } on Object {
      return null;
    }
  }

  bool _currentAccount(AccountSnapshot? account) =>
      mounted &&
      (account == null
          ? widget._captureOverride == null &&
                SupabaseConfig.canRunWithoutBackend
          : widget._isCurrentOverride?.call(account) ??
                AccountContext.isCurrent(account));
  _WalletAction _actionFor(AccountSnapshot? account) => _WalletAction(
    account,
    AccountActionToken.capture(captureAccount: _captureAccount),
    () => _currentAccount(account),
  );
  _WalletAction _captureAction() => _actionFor(_captureAccount());

  WalletOperationRecord? _activeOperation;
  int _loadRevision = 0;
  StreamSubscription<AuthState>? _authChanges;
  WalletSummary? _summary;
  List<TokenLedgerEntry> _ledger = const [];
  bool _isLoading = true;
  bool _isBusy = false;
  String? _error;

  final _format = NumberFormat.decimalPattern();

  void _accountChanged() {
    if (!mounted) return;
    _loadRevision++;
    _viewAccount = _captureAccount();
    setState(() {
      _summary = null;
      _ledger = const [];
      _activeOperation = null;
      _isBusy = false;
      _isLoading = false;
      _error = _viewAccount == null && !SupabaseConfig.canRunWithoutBackend
          ? 'Sign in again to view your Wallet.'
          : null;
    });
    if (_viewAccount != null || SupabaseConfig.canRunWithoutBackend) {
      unawaited(_load());
    }
  }

  @override
  void initState() {
    super.initState();
    _viewAccount = _captureAccount();
    AccountContext.changes.addListener(_accountChanged);
    if (SupabaseConfig.isConfigured) {
      _authChanges = Supabase.instance.client.auth.onAuthStateChange.listen((
        _,
      ) {
        _accountChanged();
      });
    }
    _load();
  }

  @override
  void dispose() {
    AccountContext.changes.removeListener(_accountChanged);
    _loadRevision++;
    unawaited(_authChanges?.cancel());
    super.dispose();
  }

  Future<void> _load({_WalletAction? action}) async {
    final origin = action ?? _captureAction();
    if (!origin.isCurrent) return;
    final account = origin.account;
    final revision = ++_loadRevision;
    _viewAccount = account;
    bool current() => origin.isCurrent && revision == _loadRevision;
    setState(() {
      _isLoading = true;
      _error = null;
      _summary = null;
      _ledger = const [];
      _activeOperation = null;
    });
    try {
      if (account == null) throw StateError('Verified wallet account required');
      if (!current()) return;
      final wallet = ref.read(walletServiceProvider);
      final summary = await wallet.getSummary();
      if (!current()) return;
      final ledger = await wallet.listLedger();
      if (!current()) return;
      final operation = await wallet.activeOperation();
      if (!current()) return;
      setState(() {
        _summary = summary;
        _ledger = ledger;
        _activeOperation = operation;
        _isLoading = false;
      });
    } on Object {
      if (!current()) return;
      if (SupabaseConfig.canRunWithoutBackend &&
          widget._captureOverride == null) {
        setState(() {
          _summary = _previewWalletSummary;
          _ledger = _previewLedgerEntries();
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _error = 'Wallet is unavailable right now.';
        _isLoading = false;
      });
    }
  }

  Future<void> _shareInvite(_WalletAction origin) async {
    if (!origin.isCurrent ||
        (origin.account == null && !SupabaseConfig.isLocalUiPreview)) {
      return;
    }
    final revision = _loadRevision;
    bool current() => origin.isCurrent && revision == _loadRevision;
    try {
      final referral = _summary?.shareUrl?.trim().isNotEmpty == true
          ? ReferralCode(
              id: 'current',
              code: _summary?.referralCode ?? '',
              shareUrl: _summary!.shareUrl!,
              rewardTokens: 100,
            )
          : await ref.read(referralServiceProvider).getOrCreateCode();
      if (!current()) return;
      await RequestDeadline.mutation(
        SharePlus.instance.share(
          ShareParams(text: _inviteShareMessage(referral)),
        ),
        operation: 'share_referral_invite',
        timeout: const Duration(seconds: 60),
      );
      if (!current()) return;
      if (!origin.isCurrent) return;
      await _load(action: origin);
    } on Object catch (_) {
      if (!current()) return;
      _showSnackBar('Unable to prepare invite link.');
    }
  }

  Future<void> _copyInvite(_WalletAction origin) async {
    if (!origin.isCurrent ||
        (origin.account == null && !SupabaseConfig.isLocalUiPreview)) {
      return;
    }
    final revision = _loadRevision;
    bool current() => origin.isCurrent && revision == _loadRevision;
    try {
      final referral = _summary?.shareUrl?.trim().isNotEmpty == true
          ? ReferralCode(
              id: 'current',
              code: _summary?.referralCode ?? '',
              shareUrl: _summary!.shareUrl!,
              rewardTokens: 100,
            )
          : await ref.read(referralServiceProvider).getOrCreateCode();
      if (!current()) return;
      await RequestDeadline.mutation(
        Clipboard.setData(ClipboardData(text: referral.shareUrl)),
        operation: 'copy_referral_invite',
      );
      if (!current()) return;
      _showSnackBar('Invite link copied.');
      if (!origin.isCurrent) return;
      await _load(action: origin);
    } on Object catch (_) {
      if (!current()) return;
      _showSnackBar('Unable to copy invite link.');
    }
  }

  Future<void> _redeemInviteCode(_WalletAction origin) async {
    if (!origin.isCurrent || origin.account == null || _isBusy) return;
    final codeController = TextEditingController();

    await MobiBottomSheet.show<void>(
      context: context,
      builder: (context) {
        String? sheetError;
        return _WalletFormLifetime(
          controllers: [codeController],
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final code = codeController.text.trim().toUpperCase();
              final canApply = code.length >= 4;

              return _WalletAccountView(
                origin: origin,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter invite code',
                        style: AppTypography.titleLg.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Add a Mobio invite code to get 100 TOKENS. The person who invited you also gets 100 TOKENS.',
                        style: AppTypography.bodySm.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: codeController,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp('[a-zA-Z0-9]'),
                          ),
                          LengthLimitingTextInputFormatter(16),
                        ],
                        onChanged: (_) {
                          if (origin.isCurrent && context.mounted) {
                            setSheetState(() => sheetError = null);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Invite code',
                          hintText: 'MOBIOCODE',
                        ),
                      ),
                      if (sheetError != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          sheetError!,
                          style: AppTypography.bodySm.copyWith(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: MobiButton(
                              variant: MobiButtonVariant.ghost,
                              onPressed: () {
                                if (origin.isCurrent && context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: MobiButton(
                              onPressed: canApply
                                  ? () async {
                                      if (!origin.isCurrent ||
                                          !context.mounted) {
                                        return;
                                      }
                                      try {
                                        await ref
                                            .read(referralServiceProvider)
                                            .completeSignup(
                                              code: code,
                                              metadata: const {
                                                'source': 'manual_wallet_code',
                                              },
                                            );
                                        if (!origin.isCurrent ||
                                            !context.mounted) {
                                          return;
                                        }
                                        Navigator.of(context).pop();
                                        _showSnackBar(
                                          'Invite code applied. 100 TOKENS added when eligible.',
                                        );
                                        if (!origin.isCurrent) return;
                                        await _load(action: origin);
                                      } on Object {
                                        if (!origin.isCurrent ||
                                            !context.mounted) {
                                          return;
                                        }
                                        setSheetState(() {
                                          sheetError =
                                              'Unable to apply this invite code.';
                                        });
                                      }
                                    }
                                  : null,
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showTransferSheet(_WalletAction origin) async {
    if (!origin.isCurrent || origin.account == null || _isBusy) return;
    final memberController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    await MobiBottomSheet.show<void>(
      context: context,
      builder: (context) {
        String? sheetError;
        String? memberIdError;
        return _WalletFormLifetime(
          controllers: [memberController, amountController, noteController],
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final memberId = normalizeMobioMemberId(memberController.text);
              final amount = int.tryParse(amountController.text);
              final canSend = memberId != null && amount != null && amount > 0;

              return _WalletAccountView(
                origin: origin,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              LucideIcons.send,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Transfer TOKENS',
                                  style: AppTypography.titleLg.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  'Send from your Mobio wallet to a 6-digit member ID.',
                                  style: AppTypography.bodySm.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: memberController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(mobioMemberIdLength),
                        ],
                        maxLength: mobioMemberIdLength,
                        onChanged: (value) {
                          if (!origin.isCurrent || !context.mounted) return;
                          setSheetState(() {
                            memberIdError = value.isEmpty
                                ? null
                                : mobioMemberIdInputError(value);
                            if (sheetError?.contains('Mobio ID') == true ||
                                sheetError?.contains('member ID') == true) {
                              sheetError = null;
                            }
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Receiver 6-digit ID',
                          counterText: '',
                          helperText: memberIdError == null
                              ? 'Use the exact 6-digit Mobio member ID.'
                              : null,
                          errorText: memberIdError,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) {
                          if (!origin.isCurrent || !context.mounted) return;
                          setSheetState(() {
                            if (sheetError == 'Enter a valid TOKEN amount.') {
                              sheetError = null;
                            }
                          });
                        },
                        decoration: const InputDecoration(labelText: 'TOKENS'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: noteController,
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Note'),
                      ),
                      if (sheetError != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          sheetError!,
                          style: AppTypography.bodySm.copyWith(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: MobiButton(
                              variant: MobiButtonVariant.ghost,
                              onPressed: () {
                                if (origin.isCurrent && context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: MobiButton(
                              onPressed: canSend
                                  ? () {
                                      if (!origin.isCurrent ||
                                          !context.mounted) {
                                        return;
                                      }
                                      final memberId = normalizeMobioMemberId(
                                        memberController.text,
                                      );
                                      final amount = int.tryParse(
                                        amountController.text,
                                      );
                                      Navigator.of(context).pop();
                                      _confirmAndTransferTokens(
                                        origin: origin,
                                        receiverMemberId: memberId!,
                                        amountTokens: amount!,
                                        note: noteController.text.trim(),
                                      );
                                    }
                                  : null,
                              child: const Text('Send'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showRedeemSheet(_WalletAction origin) async {
    if (!origin.isCurrent || origin.account == null || _isBusy) return;
    final balance = _summary?.balanceTokens ?? 0;
    final amountController = TextEditingController(
      text: balance > 0 ? balance.toString() : '',
    );

    await MobiBottomSheet.show<void>(
      context: context,
      builder: (context) {
        String? sheetError;
        return _WalletFormLifetime(
          controllers: [amountController],
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final amount = int.tryParse(amountController.text);

              return _WalletAccountView(
                origin: origin,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              LucideIcons.banknote,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Redeem TOKENS',
                                  style: AppTypography.titleLg.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  'Transfer TOKENS to the admin wallet for manual MoMo cash payout.',
                                  style: AppTypography.bodySm.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: amountController,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) {
                          if (origin.isCurrent && context.mounted) {
                            setSheetState(() => sheetError = null);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'TOKENS to redeem',
                          helperText:
                              'Minimum ${_format.format(_minimumRedemptionTokens)} TOKENS. Default is your full balance.',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Available ${_format.format(balance)} TOKENS',
                        style: AppTypography.labelMd.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (sheetError != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          sheetError!,
                          style: AppTypography.bodySm.copyWith(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: MobiButton(
                              variant: MobiButtonVariant.ghost,
                              onPressed: () {
                                if (origin.isCurrent && context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: MobiButton(
                              onPressed: amount == null
                                  ? null
                                  : () {
                                      if (!origin.isCurrent ||
                                          !context.mounted) {
                                        return;
                                      }
                                      if (amount < _minimumRedemptionTokens) {
                                        setSheetState(() {
                                          sheetError =
                                              'Redeem at least ${_format.format(_minimumRedemptionTokens)} TOKENS.';
                                        });
                                        return;
                                      }
                                      if (amount > balance) {
                                        setSheetState(() {
                                          sheetError =
                                              'Your wallet does not have enough TOKENS.';
                                        });
                                        return;
                                      }
                                      Navigator.of(context).pop();
                                      _confirmAndRedeemTokens(
                                        origin: origin,
                                        amountTokens: amount,
                                      );
                                    },
                              child: const Text('Send'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _confirmAndRedeemTokens({
    required int amountTokens,
    required _WalletAction origin,
  }) async {
    if (_isBusy || !origin.isCurrent || origin.account == null) return;
    setState(() => _isBusy = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _WalletAccountView(
        origin: origin,
        child: AlertDialog(
          title: const Text('Confirm redemption'),
          content: Text(
            'Redeem ${_format.format(amountTokens)} TOKENS for MoMo cash. The TOKENS will move to the admin wallet and the payout will be sent manually to your registered MoMo number.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (origin.isCurrent && context.mounted) {
                  Navigator.of(context).pop(false);
                }
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (origin.isCurrent && context.mounted) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Redeem'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted || !origin.isCurrent) {
      if (mounted && origin.isCurrent) setState(() => _isBusy = false);
      return;
    }

    setState(() => _isBusy = true);
    try {
      final receipt = await ref
          .read(walletServiceProvider)
          .redemptionOperation(
            amountTokens: amountTokens,
            idempotencyKey: WalletOperationJournal.newOperationId(),
          );
      if (!origin.isCurrent) return;
      await _load(action: origin);
      if (!mounted || !origin.isCurrent) return;
      if (await _showRedemptionReceipt(receipt.value, origin)) {
        if (!origin.isCurrent) return;
        await ref
            .read(walletServiceProvider)
            .closeOperation(receipt.operation, cancel: false);
        if (!origin.isCurrent) return;
        await _load(action: origin);
      }
    } on Object catch (error) {
      if (origin.isCurrent) _showSnackBar(_redemptionError(error));
    } finally {
      if (mounted && origin.isCurrent) setState(() => _isBusy = false);
    }
  }

  Future<bool> _showRedemptionReceipt(
    WalletRedemptionReceipt receipt,
    _WalletAction origin,
  ) async {
    if (!origin.isCurrent) return false;
    final acknowledged = await showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder: (context) => _WalletAccountView(
        origin: origin,
        child: AlertDialog(
          title: const Text('Redemption sent'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_format.format(receipt.amountTokens)} TOKENS'),
              const SizedBox(height: AppSpacing.sm),
              Text('${_format.format(receipt.amountRwf)} RWF'),
              const SizedBox(height: AppSpacing.sm),
              Text('Admin wallet ${receipt.adminMemberId}'),
              if (receipt.momoNumber?.trim().isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('MoMo ${receipt.momoNumber}'),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text('Request ${_shortId(receipt.redemptionId)}'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                if (origin.isCurrent && context.mounted) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
    return acknowledged == true && origin.isCurrent;
  }

  Future<void> _confirmAndTransferTokens({
    required String receiverMemberId,
    required int amountTokens,
    String? note,
    required _WalletAction origin,
  }) async {
    if (_isBusy || !origin.isCurrent || origin.account == null) return;
    setState(() => _isBusy = true);
    final normalizedNote = note?.trim() ?? '';
    late final WalletTransferRecipient recipient;
    try {
      recipient = await ref
          .read(walletServiceProvider)
          .lookupTransferRecipient(receiverMemberId: receiverMemberId);
    } on Object catch (error) {
      if (origin.isCurrent) {
        _showSnackBar(_transferError(error, duringLookup: true));
      }
      if (mounted && origin.isCurrent) setState(() => _isBusy = false);
      return;
    }

    if (!mounted || !origin.isCurrent) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _WalletAccountView(
        origin: origin,
        child: AlertDialog(
          title: const Text('Confirm transfer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Send ${_format.format(amountTokens)} TOKENS to'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                recipient.displayName,
                style: AppTypography.titleMd.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text('Member ID ${recipient.memberId}'),
              if (normalizedNote.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('Note: $normalizedNote'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (origin.isCurrent && context.mounted) {
                  Navigator.of(context).pop(false);
                }
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (origin.isCurrent && context.mounted) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted || !origin.isCurrent) {
      if (mounted && origin.isCurrent) setState(() => _isBusy = false);
      return;
    }

    setState(() => _isBusy = true);
    try {
      final receipt = await ref
          .read(walletServiceProvider)
          .transferOperation(
            receiverMemberId: receiverMemberId,
            amountTokens: amountTokens,
            idempotencyKey: WalletOperationJournal.newOperationId(),
            note: normalizedNote,
          );
      if (!origin.isCurrent) return;
      await _load(action: origin);
      if (!mounted || !origin.isCurrent) return;
      if (await _showTransferReceipt(
        receipt: receipt.value,
        recipient: recipient,
        amountTokens: amountTokens,
        origin: origin,
      )) {
        if (!origin.isCurrent) return;
        await ref
            .read(walletServiceProvider)
            .closeOperation(receipt.operation, cancel: false);
        if (!origin.isCurrent) return;
        await _load(action: origin);
      }
    } on Object catch (error) {
      if (origin.isCurrent) _showSnackBar(_transferError(error));
    } finally {
      if (mounted && origin.isCurrent) setState(() => _isBusy = false);
    }
  }

  Future<bool> _showTransferReceipt({
    required WalletTransferReceipt receipt,
    required WalletTransferRecipient recipient,
    required int amountTokens,
    required _WalletAction origin,
  }) async {
    if (!origin.isCurrent) return false;
    final acknowledged = await showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder: (context) => _WalletAccountView(
        origin: origin,
        child: AlertDialog(
          title: const Text('Transfer sent'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_format.format(amountTokens)} TOKENS'),
              const SizedBox(height: AppSpacing.sm),
              Text('${recipient.displayName} · ${recipient.memberId}'),
              const SizedBox(height: AppSpacing.sm),
              Text('Receipt ${_shortId(receipt.transferId)}'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                if (origin.isCurrent && context.mounted) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
    return acknowledged == true && origin.isCurrent;
  }

  String _transferError(Object error, {bool duringLookup = false}) {
    final value = error.toString();
    if (value.contains('LEGACY_WALLET_REVIEW_REQUIRED')) {
      return 'An older wallet request needs support review before a new request can be sent. No new request was submitted.';
    }
    if (value.contains('RECEIVER_NOT_FOUND')) {
      return 'No wallet was found for that 6-digit member ID.';
    }
    if (value.contains('RECIPIENT_ID_MISMATCH')) {
      return 'Recipient details changed. No transfer was sent. Refresh and check the member ID before trying again.';
    }
    if (value.contains('SELF_TRANSFER_NOT_ALLOWED')) {
      return 'You cannot transfer TOKENS to your own wallet.';
    }
    if (value.contains('INSUFFICIENT_TOKENS')) {
      return 'Your wallet does not have enough TOKENS for this transfer.';
    }
    if (value.contains('INVALID_TOKEN_AMOUNT')) {
      return 'Enter a TOKEN amount greater than zero.';
    }
    if (value.contains('INVALID_MEMBER_ID')) {
      return 'Enter a valid 6-digit member ID.';
    }
    if (duringLookup) {
      return 'Recipient could not be verified. No transfer was sent. Check the member ID and try again.';
    }
    return 'Transfer outcome is not confirmed. Refresh and review the pending request before retrying.';
  }

  String _redemptionError(Object error) {
    final value = error.toString();
    if (value.contains('LEGACY_WALLET_REVIEW_REQUIRED')) {
      return 'An older wallet request needs support review before a new request can be sent. No new request was submitted.';
    }
    if (value.contains('MINIMUM_REDEMPTION_TOKENS')) {
      return 'Redeem at least ${_format.format(_minimumRedemptionTokens)} TOKENS.';
    }
    if (value.contains('ADMIN_WALLET_NOT_CONFIGURED')) {
      return 'Redemption admin wallet is not configured yet.';
    }
    if (value.contains('REGISTERED_MOMO_REQUIRED')) {
      return 'Add your MoMo number in profile before redeeming TOKENS.';
    }
    if (value.contains('INSUFFICIENT_TOKENS')) {
      return 'Your wallet does not have enough TOKENS for this redemption.';
    }
    return 'Redemption outcome is not confirmed. Refresh and review the pending request before retrying.';
  }

  Future<void> _reviewPendingOperation(_WalletAction origin) async {
    final operation = _activeOperation;
    if (!origin.isCurrent ||
        origin.account == null ||
        operation == null ||
        _isBusy) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _WalletAccountView(
        origin: origin,
        child: AlertDialog(
          title: Text(
            operation.committed
                ? 'Recorded wallet request'
                : 'Unresolved wallet request',
          ),
          content: Text(
            '${operation.kind}: ${_format.format(operation.amountTokens)} TOKENS\n'
            'Request ${operation.operationId}\n'
            '${operation.committed ? "The request was recorded. Redemption does not confirm a MoMo payout." : "Execution is not confirmed by this snapshot. Cancellation locks and rechecks against any in-flight execution."}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (origin.isCurrent && context.mounted) {
                  Navigator.of(context).pop(false);
                }
              },
              child: const Text('Keep open'),
            ),
            FilledButton(
              onPressed: () {
                if (origin.isCurrent && context.mounted) {
                  Navigator.of(context).pop(true);
                }
              },
              child: Text(
                operation.committed
                    ? 'Acknowledge receipt'
                    : 'Cancel unsubmitted request',
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted || !origin.isCurrent) return;
    setState(() => _isBusy = true);
    try {
      await ref
          .read(walletServiceProvider)
          .closeOperation(operation, cancel: !operation.committed);
      if (!origin.isCurrent) return;
      await _load(action: origin);
    } on Object {
      if (mounted && origin.isCurrent) {
        _showSnackBar(
          'Request state changed or is unavailable. Refresh to reconcile.',
        );
      }
    } finally {
      if (mounted && origin.isCurrent) setState(() => _isBusy = false);
    }
  }

  static String _shortId(String value) {
    if (value.length <= 10) return value;
    return value.substring(0, 10);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) =>
      MobiVisualTheme(family: MobiVisualFamily.value, builder: _buildContent);

  Widget _buildContent(BuildContext context) {
    final origin = _actionFor(_viewAccount);
    Future<void> refresh() async {
      if (origin.isCurrent) await _load(action: origin);
    }

    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Scaffold(
      backgroundColor: ext.surfaceContainerLow,
      body: SoftGradient(
        tone: SoftGradientTone.wallet,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              MobiPageHeader(
                onBack: () {
                  if (origin.isCurrent) widget.onBack();
                },
                title: 'Wallet',
                trailing: IconButton(
                  tooltip: 'Refresh',
                  onPressed: refresh,
                  icon: const Icon(LucideIcons.refreshCw),
                ),
              ),
              Expanded(
                child: RefreshIndicator.adaptive(
                  onRefresh: refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 140),
                    children: [
                      if (_isLoading) ...[
                        const LoadingSkeleton(height: 156, borderRadius: 28),
                        const SizedBox(height: AppSpacing.md),
                        const LoadingSkeleton(height: 360, borderRadius: 28),
                      ] else if (_error != null || _summary == null) ...[
                        MobiErrorState(
                          title: 'Wallet unavailable',
                          subtitle:
                              _error ?? 'Sign in again to view your Wallet.',
                          icon: LucideIcons.walletCards,
                          onRetry: refresh,
                          retryLabel: 'Refresh',
                          height: 260,
                        ),
                      ] else ...[
                        if (_activeOperation != null) ...[
                          Material(
                            type: MaterialType.transparency,
                            child: ListTile(
                              title: const Text('Wallet request needs review'),
                              subtitle: const Text(
                                'Reconcile the existing request before starting a different one.',
                              ),
                              trailing: const Icon(Icons.receipt_long),
                              onTap: () {
                                if (origin.isCurrent) {
                                  unawaited(_reviewPendingOperation(origin));
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        _WalletBalanceCard(summary: _summary!, format: _format),
                        const SizedBox(height: AppSpacing.md),
                        _WalletActionRail(
                          isBusy: _isBusy,
                          onTransfer: () {
                            if (origin.isCurrent) {
                              unawaited(_showTransferSheet(origin));
                            }
                          },
                          onRedeem: () {
                            if (origin.isCurrent) {
                              unawaited(_showRedeemSheet(origin));
                            }
                          },
                          onShare: () {
                            if (origin.isCurrent) {
                              unawaited(_shareInvite(origin));
                            }
                          },
                          onCopy: () {
                            if (origin.isCurrent) {
                              unawaited(_copyInvite(origin));
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _InviteCard(
                          summary: _summary!,
                          onShare: () {
                            if (origin.isCurrent) {
                              unawaited(_shareInvite(origin));
                            }
                          },
                          onCopy: () {
                            if (origin.isCurrent) {
                              unawaited(_copyInvite(origin));
                            }
                          },
                          onRedeem: () {
                            if (origin.isCurrent) {
                              unawaited(_redeemInviteCode(origin));
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Activity',
                          style: AppTypography.titleMd.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final entry in _ledger)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _LedgerRow(entry: entry, format: _format),
                          ),
                        if (_ledger.isEmpty)
                          MobiTonalCard(
                            padding: const EdgeInsets.all(18),
                            child: Text(
                              'No wallet activity yet.',
                              style: AppTypography.bodyMd.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _previewWalletSummary = WalletSummary(
  profileId: 'preview-profile',
  balanceTokens: 8200,
  rwfEquivalent: 8200,
  lifetimeEarnedTokens: 10200,
  lifetimeSentTokens: 1400,
  lifetimeReceivedTokens: 900,
  successfulReferrals: 8,
  referralCode: '482913',
  shareUrl: 'https://mobio.ikanisa.com/invite/482913',
);

List<TokenLedgerEntry> _previewLedgerEntries() {
  final now = DateTime(2026, 6, 15, 19, 30);
  return [
    TokenLedgerEntry(
      id: 'preview-earned',
      direction: 'credit',
      amountTokens: 100,
      reason: 'successful invite',
      note: 'Referral reward',
      createdAt: now.subtract(const Duration(hours: 3)),
    ),
    TokenLedgerEntry(
      id: 'preview-sent',
      direction: 'debit',
      amountTokens: 50,
      reason: 'driver plus',
      note: 'Daily access',
      createdAt: now.subtract(const Duration(days: 1, hours: 2)),
    ),
  ];
}

class _WalletBalanceCard extends StatelessWidget {
  const _WalletBalanceCard({required this.summary, required this.format});

  final WalletSummary summary;
  final NumberFormat format;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MobiTonalCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.walletCards, color: cs.primary, size: 28),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${format.format(summary.balanceTokens)} TOKENS',
            style: AppTypography.displayMd.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${format.format(summary.rwfEquivalent)} RWF',
            style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${summary.successfulReferrals} successful invites',
            style: AppTypography.labelLg.copyWith(color: cs.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _WalletMetric(
                  label: 'Earned',
                  value: format.format(summary.lifetimeEarnedTokens),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _WalletMetric(
                  label: 'Sent',
                  value: format.format(summary.lifetimeSentTokens),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _WalletMetric(
                  label: 'Received',
                  value: format.format(summary.lifetimeReceivedTokens),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletMetric extends StatelessWidget {
  const _WalletMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: ext.surfaceContainerHigh.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: ext.cardBorderAlpha),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSm.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelLg.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletActionRail extends StatelessWidget {
  const _WalletActionRail({
    required this.isBusy,
    required this.onTransfer,
    required this.onRedeem,
    required this.onShare,
    required this.onCopy,
  });

  final bool isBusy;
  final VoidCallback onTransfer;
  final VoidCallback onRedeem;
  final VoidCallback onShare;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _WalletActionTile(
            icon: LucideIcons.send,
            label: 'Send',
            onTap: isBusy ? null : onTransfer,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _WalletActionTile(
            icon: LucideIcons.banknote,
            label: 'Redeem',
            onTap: isBusy ? null : onRedeem,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _WalletActionTile(
            icon: LucideIcons.share2,
            label: 'Share',
            onTap: onShare,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _WalletActionTile(
            icon: LucideIcons.copy,
            label: 'Copy',
            onTap: onCopy,
          ),
        ),
      ],
    );
  }
}

class _WalletActionTile extends StatelessWidget {
  const _WalletActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MobiTonalCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: cs.primary, size: 19),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelLg.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.summary,
    required this.onShare,
    required this.onCopy,
    required this.onRedeem,
  });

  final WalletSummary summary;
  final VoidCallback onShare;
  final VoidCallback onCopy;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final code = summary.referralCode?.trim();
    final shareUrl = _walletInviteUrl(summary);
    final qrData = _walletInviteQrData(summary);
    return MobiTonalCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.gift, color: cs.primary, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invite and earn',
                      style: AppTypography.titleMd.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${summary.successfulReferrals} rewarded invites',
                      style: AppTypography.bodySm.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Invite friends to Mobio for quick rides and instant payment. They get 100 TOKENS with your code; you get 100 TOKENS after signup.',
            style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.outline.withValues(alpha: 0.14)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final inviteDetails = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      code?.isNotEmpty == true ? code! : 'Create invite code',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleLg.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (shareUrl?.isNotEmpty == true) ...[
                      const SizedBox(height: 3),
                      Text(
                        shareUrl!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                );

                if (qrData == null) return inviteDetails;
                if (constraints.maxWidth < 280) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      inviteDetails,
                      const SizedBox(height: AppSpacing.sm),
                      _InviteQrCode(data: qrData),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: inviteDetails),
                    const SizedBox(width: AppSpacing.md),
                    _InviteQrCode(data: qrData),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: MobiButton(
                  variant: MobiButtonVariant.success,
                  onPressed: onShare,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: const Text('Share invite'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: MobiButton(
                  variant: MobiButtonVariant.ghost,
                  onPressed: onCopy,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: const Text('Copy link'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          MobiButton(
            variant: MobiButtonVariant.ghost,
            onPressed: onRedeem,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: const Text('Enter invite code'),
          ),
        ],
      ),
    );
  }
}

class _InviteQrCode extends StatelessWidget {
  const _InviteQrCode({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Invite QR code',
      image: true,
      child: Container(
        width: 88,
        height: 88,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.primaryFixed.withValues(alpha: 0.8),
          ),
        ),
        child: QrImageView(
          data: data,
          version: QrVersions.auto,
          gapless: true,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
          backgroundColor: Colors.white,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Colors.black,
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry, required this.format});

  final TokenLedgerEntry entry;
  final NumberFormat format;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCredit = entry.direction == 'credit';
    final date = DateFormat('d MMM, HH:mm').format(entry.createdAt.toLocal());
    return MobiTonalCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (isCredit ? cs.primary : cs.error).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
              color: isCredit ? cs.primary : cs.error,
              size: 19,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _walletLedgerLabel(entry.reason),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMd.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    date,
                    if (entry.note?.trim().isNotEmpty == true)
                      entry.note!.trim(),
                  ].join(' - '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${isCredit ? '+' : '-'}${format.format(entry.amountTokens)}',
            style: AppTypography.labelLg.copyWith(
              color: isCredit ? cs.primary : cs.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _walletLedgerLabel(String raw) {
  final label = raw.trim().replaceAll('_', ' ');
  if (label.isEmpty) return 'Wallet activity';
  return label[0].toUpperCase() + label.substring(1);
}

String? _walletInviteQrData(WalletSummary summary) {
  final inviteUrl = _walletInviteUrl(summary);
  if (inviteUrl != null) return inviteUrl;

  return null;
}

String? _walletInviteUrl(WalletSummary summary) {
  final shareUrl = summary.shareUrl?.trim();
  if (shareUrl?.isNotEmpty == true) return shareUrl;
  final code = summary.referralCode?.trim();
  if (code?.isNotEmpty == true) {
    return 'https://mobio.ikanisa.com/invite/$code';
  }
  return null;
}

String _inviteShareMessage(ReferralCode referral) {
  return 'You are getting Mobio for quick rides and instant payment. '
      'Use invite code ${referral.code} to get 100 TOKENS. '
      'I get 100 TOKENS too after you sign up: ${referral.shareUrl}';
}

class _WalletAction {
  _WalletAction(this.account, this.token, this._accountIsCurrent);
  final AccountSnapshot? account;
  final AccountActionToken token;
  final bool Function() _accountIsCurrent;
  bool get isCurrent => token.isCurrent && _accountIsCurrent();
}

class _WalletAccountView extends StatelessWidget {
  const _WalletAccountView({required this.origin, required this.child});
  final _WalletAction origin;
  final Widget child;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: AccountContext.changes,
    builder: (_, _, _) => origin.isCurrent
        ? child
        : const Material(
            child: Center(
              child: Text(
                'Account changed. Close this view and sign in again.',
              ),
            ),
          ),
  );
}

// A modal pop completes before its exit transition unmounts its fields. Keep
// their controllers alive until that route subtree is actually removed.
class _WalletFormLifetime extends StatefulWidget {
  const _WalletFormLifetime({required this.controllers, required this.child});
  final List<TextEditingController> controllers;
  final Widget child;
  @override
  State<_WalletFormLifetime> createState() => _WalletFormLifetimeState();
}

class _WalletFormLifetimeState extends State<_WalletFormLifetime> {
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
