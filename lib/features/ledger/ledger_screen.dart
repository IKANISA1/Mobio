import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/features/ledger/providers/ledger_provider.dart';
import 'package:mobi_app/features/ledger/widgets/transaction_tile.dart';
import 'package:mobi_app/shared/widgets/ai_empty_state.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_error_state.dart';
import 'package:mobi_app/shared/widgets/mobi_metric_tile.dart';
import 'package:mobi_app/shared/widgets/mobi_page_header.dart';
import 'package:mobi_app/shared/widgets/mobi_state_banner.dart';

class LedgerScreen extends ConsumerWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsStreamProvider);
    final summaryAsync = ref.watch(transactionSummaryProvider);
    final pendingCountAsync = ref.watch(pendingSmsCountProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(ledgerNativeServiceProvider).triggerSync();
            ref.invalidate(transactionsStreamProvider);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: MobiPageHeader(
                  title: 'Ledger',
                  subtitle: Text(
                    'Transaction tracker',
                    style: AppTypography.bodySm.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),

              // Summary Cards
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverToBoxAdapter(
                  child: summaryAsync.when(
                    data: (summary) => Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: MobiMetricTile(
                                label: 'Income',
                                value: NumberFormat.compact().format(
                                  summary['totalIn'] ?? 0.0,
                                ),
                                icon: LucideIcons.trendingUp,
                                accent: AppColors.bioPayGreen,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: MobiMetricTile(
                                label: 'Expenses',
                                value: NumberFormat.compact().format(
                                  summary['totalOut'] ?? 0.0,
                                ),
                                icon: LucideIcons.trendingDown,
                                accent: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                    loading: () => const Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: LoadingSkeleton(
                              height: 92,
                              borderRadius: 24,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: LoadingSkeleton(
                              height: 92,
                              borderRadius: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                    error: (error, stackTrace) => Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: MobiStateBanner(
                        title: 'Ledger summary unavailable',
                        subtitle: userMessageForError(error),
                        icon: LucideIcons.alertTriangle,
                        tone: MobiStateBannerTone.warning,
                        onTap: () => ref.invalidate(transactionSummaryProvider),
                      ),
                    ),
                  ),
                ),
              ),

              // Pending SMS Warning
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverToBoxAdapter(
                  child: pendingCountAsync.when(
                    data: (count) => count > 0
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: MobiStateBanner(
                              title: '$count pending SMS',
                              subtitle: 'Processing your latest receipts...',
                              icon: LucideIcons.refreshCw,
                              onTap: () => ref
                                  .read(ledgerNativeServiceProvider)
                                  .triggerSync(),
                              trailing: Icon(
                                LucideIcons.arrowRight,
                                size: 20,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              ),

              // Transaction List
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Recent Transactions',
                      style: AppTypography.titleLg.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
              ),

              transactionsAsync.when(
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: AiEmptyState(
                        title: 'No transactions found',
                        subtitle:
                            'SMS receipts will appear here automatically.',
                        icon: LucideIcons.receipt,
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            TransactionTile(transaction: transactions[index]),
                        childCount: transactions.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      LoadingSkeleton.listTile(),
                      LoadingSkeleton.listTile(),
                      LoadingSkeleton.listTile(),
                      LoadingSkeleton.listTile(),
                    ]),
                  ),
                ),
                error: (e, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: MobiErrorState(
                      title: 'Unable to load ledger',
                      subtitle: userMessageForError(
                        e,
                        fallback:
                            'Transactions are unavailable. Pull to refresh or try again.',
                      ),
                      onRetry: () => ref.invalidate(transactionsStreamProvider),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}
