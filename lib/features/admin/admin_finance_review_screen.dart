import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/admin_service.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/features/admin/widgets/admin_dashboard_utils.dart';
import 'package:mobi_app/features/admin/widgets/admin_ui.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';

class AdminFinanceReviewScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const AdminFinanceReviewScreen({super.key, required this.onBack});

  @override
  ConsumerState<AdminFinanceReviewScreen> createState() =>
      _AdminFinanceReviewScreenState();
}

class _AdminFinanceReviewScreenState
    extends ConsumerState<AdminFinanceReviewScreen> {
  AdminService get _adminService => ref.read(adminServiceProvider);

  final _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  String? _busyId;
  List<AdminRiskFlagItem> _flags = [];
  String _statusFilter = 'open';
  String _severityFilter = 'all';
  String _searchQuery = '';
  String _sortKey = 'priority';
  int _page = 0;
  int _rowsPerPage = 25;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final flags = await _adminService.listRiskFlags(
        status: _statusFilter,
        severity: _severityFilter == 'all' ? null : _severityFilter,
        limit: 100,
      );

      if (mounted) {
        setState(() {
          _flags = flags;
          _isLoading = false;
          _page = 0;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _review(AdminRiskFlagItem item, String action) async {
    final notes = await _showReviewDialog(item, action);
    if (notes == null) return;

    setState(() => _busyId = item.id);
    try {
      await _adminService.reviewRiskFlag(
        riskFlagId: item.id,
        action: action,
        notes: notes,
      );
      await _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'approve'
                  ? 'External USSD review approved.'
                  : 'External USSD review rejected.',
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Review failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<String?> _showReviewDialog(
    AdminRiskFlagItem item,
    String action,
  ) async {
    final notesController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        final ext = Theme.of(context).extension<MobiThemeExtension>()!;
        final isApprove = action == 'approve';

        return AlertDialog(
          backgroundColor: ext.surfaceContainerLowest,
          title: Text(isApprove ? 'Approve review' : 'Reject review'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This records a manual review for an external USSD payment reconciliation. No in-app payment is created or charged.',
                  style: AppTypography.bodySm.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: notesController,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: 'Review notes',
                    filled: true,
                    fillColor: ext.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _amountLabel(item),
                  style: AppTypography.labelMd.copyWith(color: cs.onSurface),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            MobiButton(
              variant: isApprove
                  ? MobiButtonVariant.primary
                  : MobiButtonVariant.danger,
              onPressed: () =>
                  Navigator.of(context).pop(notesController.text.trim()),
              child: Text(isApprove ? 'Approve' : 'Reject'),
            ),
          ],
        );
      },
    );
    notesController.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final openCount = _flags.where((flag) => flag.isOpen).length;
    final criticalCount = _flags
        .where((flag) => const {'critical', 'high'}.contains(flag.severity))
        .length;
    final resolvedCount = _flags.where((flag) => flag.resolved).length;
    final visibleFlags = _visibleFlags();
    final pagedFlags = _pagedFlags(visibleFlags);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: AdminWorkspaceFrame(
          onBack: widget.onBack,
          currentTab: AdminWorkspaceTab.finance,
          title: 'Finance',
          subtitle: 'External USSD review.',
          actions: [
            AdminActionChip(
              label: 'Refresh',
              icon: LucideIcons.refreshCw,
              isBusy: _isLoading,
              onTap: _isLoading ? null : _load,
            ),
          ],
          child: RefreshIndicator.adaptive(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AdminLayoutTokens.overlayPagePadding,
              children: [
                _FinanceMetricGrid(
                  openCount: openCount,
                  criticalCount: criticalCount,
                  resolvedCount: resolvedCount,
                ),
                const SizedBox(height: AppSpacing.lg),
                AdminPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AdminSectionHeader(
                        title: 'Queue',
                        subtitle: 'Search, filter, review',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 900;
                          final search = SizedBox(
                            width: isWide ? 360 : double.infinity,
                            child: AdminSearchField(
                              controller: _searchController,
                              hintText: 'Search member, ref, reason',
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                  _page = 0;
                                });
                              },
                            ),
                          );
                          final controls = Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              for (final filter in const [
                                ('open', 'Open', LucideIcons.alertCircle),
                                ('resolved', 'Resolved', LucideIcons.check),
                                ('all', 'All', LucideIcons.list),
                              ])
                                AdminFilterChip(
                                  label: filter.$2,
                                  icon: filter.$3,
                                  isSelected: _statusFilter == filter.$1,
                                  onTap: () {
                                    setState(() {
                                      _statusFilter = filter.$1;
                                      _page = 0;
                                    });
                                    _load();
                                  },
                                ),
                              AdminSortMenu(
                                value: _sortKey,
                                options: const [
                                  AdminSortOption(
                                    value: 'priority',
                                    label: 'Priority',
                                    icon: LucideIcons.siren,
                                  ),
                                  AdminSortOption(
                                    value: 'newest',
                                    label: 'Newest',
                                    icon: LucideIcons.clock,
                                  ),
                                  AdminSortOption(
                                    value: 'amount',
                                    label: 'Amount',
                                    icon: LucideIcons.wallet,
                                  ),
                                ],
                                onChanged: (value) => setState(() {
                                  _sortKey = value;
                                  _page = 0;
                                }),
                              ),
                            ],
                          );

                          return isWide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    search,
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(child: controls),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    search,
                                    const SizedBox(height: AppSpacing.md),
                                    controls,
                                  ],
                                );
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final severity in const [
                            ('all', 'All severity'),
                            ('critical', 'Critical'),
                            ('high', 'High'),
                            ('medium', 'Medium'),
                            ('low', 'Low'),
                          ])
                            AdminFilterChip(
                              label: severity.$2,
                              isSelected: _severityFilter == severity.$1,
                              onTap: () {
                                setState(() {
                                  _severityFilter = severity.$1;
                                  _page = 0;
                                });
                                _load();
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_isLoading)
                  const Column(
                    children: [
                      LoadingSkeleton(height: 120, borderRadius: 28),
                      SizedBox(height: AppSpacing.md),
                      LoadingSkeleton(height: 320, borderRadius: 28),
                    ],
                  )
                else if (_error != null)
                  AdminEmptyState(
                    title: 'Finance review unavailable',
                    message: _error!,
                    icon: LucideIcons.alertTriangle,
                    action: AdminActionChip(
                      label: 'Retry',
                      icon: LucideIcons.refreshCw,
                      onTap: _load,
                    ),
                  )
                else if (visibleFlags.isEmpty)
                  const AdminEmptyState(
                    title: 'No review items',
                    message: 'No external USSD risk flags match this view.',
                    icon: LucideIcons.shieldCheck,
                  )
                else
                  AdminPanel(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var index = 0; index < pagedFlags.length; index++)
                          Column(
                            children: [
                              _FinanceReviewRow(
                                item: pagedFlags[index],
                                isBusy: _busyId == pagedFlags[index].id,
                                onApprove: _canApprove(pagedFlags[index])
                                    ? () {
                                        HapticFeedback.lightImpact();
                                        _review(pagedFlags[index], 'approve');
                                      }
                                    : null,
                                onReject: pagedFlags[index].isOpen
                                    ? () {
                                        HapticFeedback.lightImpact();
                                        _review(pagedFlags[index], 'reject');
                                      }
                                    : null,
                              ),
                              if (index < pagedFlags.length - 1)
                                Divider(
                                  height: 1,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.35),
                                ),
                            ],
                          ),
                        AdminPaginationBar(
                          totalItems: visibleFlags.length,
                          page: _page,
                          rowsPerPage: _rowsPerPage,
                          onPageChanged: (page) => setState(() => _page = page),
                          onRowsPerPageChanged: (rows) => setState(() {
                            _rowsPerPage = rows;
                            _page = 0;
                          }),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<AdminRiskFlagItem> _sortedFlags(List<AdminRiskFlagItem> flags) {
    return [...flags]..sort((a, b) {
      return switch (_sortKey) {
        'amount' => _reviewAmount(b).compareTo(_reviewAmount(a)),
        'newest' => _dateValue(b.createdAt).compareTo(_dateValue(a.createdAt)),
        _ => _priorityValue(a).compareTo(_priorityValue(b)),
      };
    });
  }

  List<AdminRiskFlagItem> _visibleFlags() {
    final query = _searchQuery.trim().toLowerCase();
    final flags = _flags.where((flag) {
      if (query.isEmpty) return true;
      return flag.profileName.toLowerCase().contains(query) ||
          (flag.profilePhone ?? '').toLowerCase().contains(query) ||
          flag.flagType.toLowerCase().contains(query) ||
          flag.severity.toLowerCase().contains(query) ||
          (flag.description ?? '').toLowerCase().contains(query) ||
          (flag.transactionRef ?? '').toLowerCase().contains(query) ||
          (flag.intentStatus ?? '').toLowerCase().contains(query) ||
          flag.id.toLowerCase().contains(query);
    }).toList();

    return _sortedFlags(flags);
  }

  List<AdminRiskFlagItem> _pagedFlags(List<AdminRiskFlagItem> flags) {
    if (flags.isEmpty) return const [];
    final safeRowsPerPage = _rowsPerPage <= 0 ? 25 : _rowsPerPage;
    final start = (_page * safeRowsPerPage).clamp(0, flags.length).toInt();
    final end = (start + safeRowsPerPage).clamp(start, flags.length).toInt();
    return flags.sublist(start, end);
  }

  bool _canApprove(AdminRiskFlagItem item) {
    return item.isOpen && item.intentId != null && item.transactionId != null;
  }

  int _priorityValue(AdminRiskFlagItem item) {
    final severity = switch (item.severity.toLowerCase()) {
      'critical' => 0,
      'high' => 1,
      'medium' => 2,
      'low' => 3,
      _ => 4,
    };
    return item.resolved ? severity + 10 : severity;
  }

  int _dateValue(String? value) =>
      DateTime.tryParse(value ?? '')?.millisecondsSinceEpoch ?? 0;

  double _reviewAmount(AdminRiskFlagItem item) =>
      item.amount ?? item.transactionAmount ?? 0;
}

class _FinanceMetricGrid extends StatelessWidget {
  const _FinanceMetricGrid({
    required this.openCount,
    required this.criticalCount,
    required this.resolvedCount,
  });

  final int openCount;
  final int criticalCount;
  final int resolvedCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width >= 1120
            ? (width - AppSpacing.md * 2) / 3
            : width >= 760
            ? (width - AppSpacing.md) / 2
            : width;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            SizedBox(
              width: cardWidth,
              child: AdminMetricCard(
                label: 'Open',
                value: '$openCount',
                hint: 'Needs review',
                icon: LucideIcons.alertCircle,
                tone: openCount > 0
                    ? MobiStatusBadgeTone.warning
                    : MobiStatusBadgeTone.positive,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: AdminMetricCard(
                label: 'Priority',
                value: '$criticalCount',
                hint: 'High or critical',
                icon: LucideIcons.siren,
                tone: criticalCount > 0
                    ? MobiStatusBadgeTone.danger
                    : MobiStatusBadgeTone.neutral,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: AdminMetricCard(
                label: 'Resolved',
                value: '$resolvedCount',
                hint: 'In current view',
                icon: LucideIcons.checkCheck,
                tone: MobiStatusBadgeTone.positive,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FinanceReviewRow extends StatelessWidget {
  const _FinanceReviewRow({
    required this.item,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
  });

  final AdminRiskFlagItem item;
  final bool isBusy;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final tone = _severityTone(item.severity);

    return Semantics(
      container: true,
      label:
          '${item.profileName}, ${_humanize(item.flagType)}, ${_humanize(item.severity)} severity',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 920;
            final identity = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AdminDashboardUtils.toneFill(context, tone),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _severityIcon(item.severity),
                    color: AdminDashboardUtils.toneColor(context, tone),
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.profileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMd.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        [
                          _humanize(item.flagType),
                          item.profilePhone,
                          AdminDashboardUtils.formatTimestamp(item.createdAt),
                        ].whereType<String>().join('  |  '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            final status = Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                MobiStatusBadge(label: _humanize(item.severity), tone: tone),
                MobiStatusBadge(
                  label: item.resolved ? 'Resolved' : 'Open',
                  tone: item.resolved
                      ? MobiStatusBadgeTone.positive
                      : MobiStatusBadgeTone.warning,
                ),
                if (item.intentStatus != null)
                  MobiStatusBadge(
                    label: _humanize(item.intentStatus!),
                    tone: _intentTone(item.intentStatus!),
                  ),
              ],
            );

            final facts = DecoratedBox(
              decoration: BoxDecoration(
                color: ext.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FactLine(label: 'Amount', value: _amountLabel(item)),
                    _FactLine(
                      label: 'Reference',
                      value: item.transactionRef ?? 'No transaction ref',
                    ),
                    _FactLine(
                      label: 'Method',
                      value: _humanize(item.paymentMethod ?? 'external_ussd'),
                    ),
                    if ((item.description ?? '').trim().isNotEmpty)
                      _FactLine(label: 'Reason', value: item.description!),
                  ],
                ),
              ),
            );

            final actions = Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AdminActionChip(
                  label: 'Approve',
                  icon: LucideIcons.check,
                  tone: MobiStatusBadgeTone.positive,
                  isBusy: isBusy && onApprove != null,
                  onTap: isBusy ? null : onApprove,
                ),
                AdminActionChip(
                  label: 'Reject',
                  icon: LucideIcons.x,
                  tone: MobiStatusBadgeTone.danger,
                  isBusy: isBusy && onReject != null,
                  onTap: isBusy ? null : onReject,
                ),
              ],
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: identity),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(flex: 2, child: status),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(flex: 4, child: facts),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(width: 190, child: actions),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                const SizedBox(height: AppSpacing.md),
                status,
                const SizedBox(height: AppSpacing.md),
                facts,
                const SizedBox(height: AppSpacing.md),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FactLine extends StatelessWidget {
  const _FactLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: AppTypography.labelSm.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySm.copyWith(color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

String _amountLabel(AdminRiskFlagItem item) {
  final amount = item.amount ?? item.transactionAmount;
  final currency = item.currency ?? item.transactionCurrency ?? '';
  if (amount == null) return 'Amount not linked';
  return '${NumberFormat.decimalPattern().format(amount)} $currency'.trim();
}

String _humanize(String value) {
  return value
      .trim()
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

MobiStatusBadgeTone _severityTone(String severity) {
  return switch (severity.toLowerCase()) {
    'critical' || 'high' => MobiStatusBadgeTone.danger,
    'medium' => MobiStatusBadgeTone.warning,
    'low' => MobiStatusBadgeTone.info,
    _ => MobiStatusBadgeTone.neutral,
  };
}

IconData _severityIcon(String severity) {
  return switch (severity.toLowerCase()) {
    'critical' || 'high' => LucideIcons.siren,
    'medium' => LucideIcons.alertTriangle,
    _ => LucideIcons.info,
  };
}

MobiStatusBadgeTone _intentTone(String status) {
  return switch (status.toLowerCase()) {
    'completed' => MobiStatusBadgeTone.positive,
    'failed' || 'disputed' => MobiStatusBadgeTone.danger,
    'processing' || 'authorized' => MobiStatusBadgeTone.warning,
    _ => MobiStatusBadgeTone.neutral,
  };
}
