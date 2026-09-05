import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/utils/mobio_member_id.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_app/features/profile/domain/wallet.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_sheet.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_error_state.dart';
import 'package:mobi_app/shared/widgets/mobi_page_header.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_design_system/theme/app_colors.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  static const int _minimumRedemptionTokens = 5000;

  WalletSummary? _summary;
  List<TokenLedgerEntry> _ledger = const [];
  bool _isLoading = true;
  bool _isBusy = false;
  String? _error;

  final _format = NumberFormat.decimalPattern();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final wallet = ref.read(walletServiceProvider);
      final summary = await wallet.getSummary();
      final ledger = await wallet.listLedger();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _ledger = ledger;
        _isLoading = false;
      });
    } on Object {
      if (!mounted) return;
      if (SupabaseConfig.canRunWithoutBackend) {
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

  Future<void> _shareInvite() async {
    try {
      final referral = _summary?.shareUrl?.trim().isNotEmpty == true
          ? ReferralCode(
              id: 'current',
              code: _summary?.referralCode ?? '',
              shareUrl: _summary!.shareUrl!,
              rewardTokens: 100,
            )
          : await ref.read(referralServiceProvider).getOrCreateCode();
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(text: _inviteShareMessage(referral)),
      );
      await _load();
    } on Object catch (_) {
      _showSnackBar('Unable to prepare invite link.');
    }
  }

  Future<void> _copyInvite() async {
    try {
      final referral = _summary?.shareUrl?.trim().isNotEmpty == true
          ? ReferralCode(
              id: 'current',
              code: _summary?.referralCode ?? '',
              shareUrl: _summary!.shareUrl!,
              rewardTokens: 100,
            )
          : await ref.read(referralServiceProvider).getOrCreateCode();
      await Clipboard.setData(ClipboardData(text: referral.shareUrl));
      _showSnackBar('Invite link copied.');
      await _load();
    } on Object catch (_) {
      _showSnackBar('Unable to copy invite link.');
    }
  }

  Future<void> _redeemInviteCode() async {
    final codeController = TextEditingController();

    await MobiBottomSheet.show<void>(
      context: context,
      builder: (context) {
        String? sheetError;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final code = codeController.text.trim().toUpperCase();
            final canApply = code.length >= 4;

            return Padding(
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
                      FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                      LengthLimitingTextInputFormatter(16),
                    ],
                    onChanged: (_) => setSheetState(() => sheetError = null),
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
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: MobiButton(
                          onPressed: canApply
                              ? () async {
                                  try {
                                    await ref
                                        .read(referralServiceProvider)
                                        .completeSignup(
                                          code: code,
                                          metadata: const {
                                            'source': 'manual_wallet_code',
                                          },
                                        );
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop();
                                    _showSnackBar(
                                      'Invite code applied. 100 TOKENS added when eligible.',
                                    );
                                    await _load();
                                  } on Object {
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
            );
          },
        );
      },
    );

    codeController.dispose();
  }

  Future<void> _showTransferSheet() async {
    final memberController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    await MobiBottomSheet.show<void>(
      context: context,
      builder: (context) {
        String? sheetError;
        String? memberIdError;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final memberId = normalizeMobioMemberId(memberController.text);
            final amount = int.tryParse(amountController.text);
            final canSend = memberId != null && amount != null && amount > 0;

            return Padding(
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
                                color: Theme.of(context).colorScheme.onSurface,
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) {
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
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: MobiButton(
                          onPressed: canSend
                              ? () {
                                  final memberId = normalizeMobioMemberId(
                                    memberController.text,
                                  );
                                  final amount = int.tryParse(
                                    amountController.text,
                                  );
                                  Navigator.of(context).pop();
                                  _confirmAndTransferTokens(
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
            );
          },
        );
      },
    );

    memberController.dispose();
    amountController.dispose();
    noteController.dispose();
  }

  Future<void> _showRedeemSheet() async {
    final balance = _summary?.balanceTokens ?? 0;
    final amountController = TextEditingController(
      text: balance > 0 ? balance.toString() : '',
    );

    await MobiBottomSheet.show<void>(
      context: context,
      builder: (context) {
        String? sheetError;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final amount = int.tryParse(amountController.text);

            return Padding(
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
                                color: Theme.of(context).colorScheme.onSurface,
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setSheetState(() => sheetError = null),
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
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: MobiButton(
                          onPressed: amount == null
                              ? null
                              : () {
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
                                  _confirmAndRedeemTokens(amountTokens: amount);
                                },
                          child: const Text('Send'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    amountController.dispose();
  }

  Future<void> _confirmAndRedeemTokens({required int amountTokens}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm redemption'),
        content: Text(
          'Redeem ${_format.format(amountTokens)} TOKENS for MoMo cash. The TOKENS will move to the admin wallet and the payout will be sent manually to your registered MoMo number.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final keyScope = 'wallet-redeem:$amountTokens';
    setState(() => _isBusy = true);
    try {
      final receipt = await ref
          .read(walletServiceProvider)
          .redeemTokens(
            amountTokens: amountTokens,
            idempotencyKey: await _pendingOperationKey(
              scope: keyScope,
              prefix: 'wallet-redeem',
            ),
          );
      await _clearPendingOperationKey(keyScope);
      await _load();
      if (!mounted) return;
      await _showRedemptionReceipt(receipt);
    } on Object catch (error) {
      _showSnackBar(_redemptionError(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _showRedemptionReceipt(WalletRedemptionReceipt receipt) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndTransferTokens({
    required String receiverMemberId,
    required int amountTokens,
    String? note,
  }) async {
    setState(() => _isBusy = true);
    final normalizedNote = note?.trim() ?? '';
    late final WalletTransferRecipient recipient;
    try {
      recipient = await ref
          .read(walletServiceProvider)
          .lookupTransferRecipient(receiverMemberId: receiverMemberId);
    } on Object catch (error) {
      _showSnackBar(_transferError(error));
      if (mounted) setState(() => _isBusy = false);
      return;
    }

    if (!mounted) return;
    setState(() => _isBusy = false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final keyScope = _transferKeyScope(
      receiverMemberId: receiverMemberId,
      amountTokens: amountTokens,
      note: normalizedNote,
    );

    setState(() => _isBusy = true);
    try {
      final receipt = await ref
          .read(walletServiceProvider)
          .transferTokens(
            receiverMemberId: receiverMemberId,
            amountTokens: amountTokens,
            idempotencyKey: await _pendingOperationKey(
              scope: keyScope,
              prefix: 'wallet-transfer',
            ),
            note: normalizedNote,
          );
      await _clearPendingOperationKey(keyScope);
      await _load();
      if (!mounted) return;
      await _showTransferReceipt(
        receipt: receipt,
        recipient: recipient,
        amountTokens: amountTokens,
      );
    } on Object catch (error) {
      _showSnackBar(_transferError(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _showTransferReceipt({
    required WalletTransferReceipt receipt,
    required WalletTransferRecipient recipient,
    required int amountTokens,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  String _transferError(Object error) {
    final value = error.toString();
    if (value.contains('RECEIVER_NOT_FOUND')) {
      return 'No wallet was found for that 6-digit member ID.';
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
    return 'Unable to transfer TOKENS. You can retry without being charged twice.';
  }

  String _redemptionError(Object error) {
    final value = error.toString();
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
    return 'Unable to redeem TOKENS. You can retry without being charged twice.';
  }

  String _transferKeyScope({
    required String receiverMemberId,
    required int amountTokens,
    required String note,
  }) {
    return 'wallet-transfer:$receiverMemberId:$amountTokens:$note';
  }

  Future<String> _pendingOperationKey({
    required String scope,
    required String prefix,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final prefKey = 'mobio.pending.$scope';
    final existing = prefs.getString(prefKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final key =
        '$prefix-${DateTime.now().microsecondsSinceEpoch}-'
        '${Random.secure().nextInt(1 << 32).toRadixString(36)}';
    await prefs.setString(prefKey, key);
    return key;
  }

  Future<void> _clearPendingOperationKey(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mobio.pending.$scope');
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
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Scaffold(
      backgroundColor: ext.surfaceContainerLow,
      body: SoftGradient(
        tone: SoftGradientTone.profile,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              MobiPageHeader(
                onBack: widget.onBack,
                title: 'Wallet',
                trailing: IconButton(
                  tooltip: 'Refresh',
                  onPressed: _load,
                  icon: const Icon(LucideIcons.refreshCw),
                ),
              ),
              Expanded(
                child: RefreshIndicator.adaptive(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 140),
                    children: [
                      if (_isLoading) ...[
                        const LoadingSkeleton(height: 156, borderRadius: 28),
                        const SizedBox(height: AppSpacing.md),
                        const LoadingSkeleton(height: 360, borderRadius: 28),
                      ] else if (_error != null) ...[
                        MobiErrorState(
                          title: 'Wallet unavailable',
                          subtitle: _error,
                          icon: LucideIcons.walletCards,
                          onRetry: _load,
                          retryLabel: 'Refresh',
                          height: 260,
                        ),
                      ] else ...[
                        _WalletBalanceCard(summary: _summary!, format: _format),
                        const SizedBox(height: AppSpacing.md),
                        _WalletActionRail(
                          isBusy: _isBusy,
                          onTransfer: _showTransferSheet,
                          onRedeem: _showRedeemSheet,
                          onShare: _shareInvite,
                          onCopy: _copyInvite,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _InviteCard(
                          summary: _summary!,
                          onShare: _shareInvite,
                          onCopy: _copyInvite,
                          onRedeem: _redeemInviteCode,
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
                          ClayCard(
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
    return ClayCard(
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
    return ClayCard(
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
    return ClayCard(
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
            color: AppColors.primaryDim,
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: AppColors.primary,
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
    return ClayCard(
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
