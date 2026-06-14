import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/wallet.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_sheet.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_page_header.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:share_plus/share_plus.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
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
      if (SupabaseConfig.isLocalUiPreview) {
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
        ShareParams(
          text:
              'Join me on Mobio. Use code ${referral.code} and start with token rewards: ${referral.shareUrl}',
        ),
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

  Future<void> _showTransferSheet() async {
    final memberController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    await MobiBottomSheet.show<void>(
      context: context,
      builder: (context) {
        String? sheetError;
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                              'Transfer tokens',
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Receiver 6-digit ID',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Tokens'),
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
                          onPressed: () {
                            final memberId = memberController.text.trim();
                            final amount = int.tryParse(amountController.text);
                            if (!RegExp(r'^\d{6}$').hasMatch(memberId)) {
                              setSheetState(
                                () => sheetError =
                                    'Enter the receiver 6-digit member ID.',
                              );
                              return;
                            }
                            if (amount == null || amount <= 0) {
                              setSheetState(
                                () =>
                                    sheetError = 'Enter a valid token amount.',
                              );
                              return;
                            }
                            Navigator.of(context).pop();
                            _transferTokens(
                              receiverMemberId: memberId,
                              amountTokens: amount,
                              note: noteController.text.trim(),
                            );
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

    memberController.dispose();
    amountController.dispose();
    noteController.dispose();
  }

  Future<void> _transferTokens({
    required String receiverMemberId,
    required int amountTokens,
    String? note,
  }) async {
    setState(() => _isBusy = true);
    try {
      await ref
          .read(walletServiceProvider)
          .transferTokens(
            receiverMemberId: receiverMemberId,
            amountTokens: amountTokens,
            note: note,
          );
      _showSnackBar('Tokens transferred.');
      await _load();
    } on Object catch (_) {
      _showSnackBar('Unable to transfer tokens.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
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
                        ClayCard(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            _error!,
                            style: AppTypography.bodyMd.copyWith(
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ] else ...[
                        _WalletBalanceCard(summary: _summary!, format: _format),
                        const SizedBox(height: AppSpacing.md),
                        _WalletActionRail(
                          isBusy: _isBusy,
                          onTransfer: _showTransferSheet,
                          onShare: _shareInvite,
                          onCopy: _copyInvite,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _InviteCard(
                          summary: _summary!,
                          onShare: _shareInvite,
                          onCopy: _copyInvite,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Activity',
                          style: AppTypography.titleMd.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w800,
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
  balanceTokens: 3200,
  rwfEquivalent: 3200,
  lifetimeEarnedTokens: 5200,
  lifetimeSentTokens: 1400,
  lifetimeReceivedTokens: 900,
  successfulReferrals: 8,
  referralCode: '482913',
  shareUrl: 'https://mobio.ikanisa.com/invite/482913',
);

List<TokenLedgerEntry> _previewLedgerEntries() {
  final now = DateTime.now();
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
            '${format.format(summary.balanceTokens)} tokens',
            style: AppTypography.displayMd.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w900,
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
              fontWeight: FontWeight.w900,
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
    required this.onShare,
    required this.onCopy,
  });

  final bool isBusy;
  final VoidCallback onTransfer;
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
              fontWeight: FontWeight.w800,
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
  });

  final WalletSummary summary;
  final VoidCallback onShare;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final code = summary.referralCode?.trim();
    final shareUrl = summary.shareUrl?.trim();
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
                        fontWeight: FontWeight.w900,
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
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.outline.withValues(alpha: 0.14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code?.isNotEmpty == true ? code! : 'Create invite code',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleLg.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w900,
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
        ],
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
                  entry.reason.replaceAll('_', ' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMd.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
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
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
