import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/async/external_action.dart';
import 'package:mobi_app/core/auth/account_action_token.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/features/admin/application/admin_services.dart';
import 'package:mobi_app/features/admin/data/admin_service.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_dashboard_utils.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_sheet.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_input_field.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  final _actionToken = AccountActionToken.capture();
  bool get _actionIsCurrent => mounted && _actionToken.isCurrent;

  AdminService get _adminService => ref.read(adminServiceProvider);

  final _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  List<AdminUserReportItem> _reports = [];
  String _statusFilter = 'open';
  String _searchQuery = '';
  int _page = 0;
  int _rowsPerPage = 25;
  bool _hasNextPage = false;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReports({bool silent = false}) async {
    if (!_actionIsCurrent) return;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final reports = await _adminService.listUserReports(
        status: _statusFilter,
        search: _searchQuery,
        limit: _rowsPerPage + 1,
        offset: _page * _rowsPerPage,
      );
      if (!_actionIsCurrent) return;
      final hasNextPage = reports.length > _rowsPerPage;
      setState(() {
        _reports = reports.take(_rowsPerPage).toList();
        _hasNextPage = hasNextPage;
        _isLoading = false;
      });
    } on Object catch (error) {
      if (!_actionIsCurrent) return;
      setState(() {
        _isLoading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _reviewReport(AdminUserReportItem report, String status) async {
    if (!_actionIsCurrent) return;
    final notes = await _showReviewReportSheet(status);
    if (notes == null || !_actionIsCurrent) return;

    setState(() => _busyId = report.id);
    try {
      await _adminService.reviewUserReport(
        reportId: report.id,
        status: status,
        notes: notes,
      );
      await _loadReports(silent: true);
      _showSnackBar('Report ${_humanize(status).toLowerCase()}.');
    } on Object catch (error) {
      _showSnackBar(
        userMessageForError(error, fallback: 'Unable to record the review.'),
        isError: true,
      );
    } finally {
      if (_actionIsCurrent) {
        setState(() => _busyId = null);
      }
    }
  }

  Future<String?> _showReviewReportSheet(String status) async {
    final notesController = TextEditingController();
    final result = await MobiBottomSheet.show<String>(
      context: context,
      title: '${_humanize(status)} report',
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MobiInputField(
                label: 'Resolution notes',
                hint: 'Decision or follow-up action',
                controller: notesController,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
              ),
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
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(notesController.text.trim()),
                      child: Text(_humanize(status)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    notesController.dispose();
    return result;
  }

  Future<void> _showReportDetailSheet(AdminUserReportItem report) {
    final cs = Theme.of(context).colorScheme;
    return MobiBottomSheet.show<void>(
      context: context,
      title: 'Report details',
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AdminDashboardUtils.formatTimestamp(
                              report.createdAt,
                            ),
                            style: AppTypography.bodySm.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AdminActionChip(
                      label: 'Close',
                      icon: LucideIcons.x,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    MobiStatusBadge(
                      label: _humanize(report.status),
                      tone: _statusTone(report.status),
                    ),
                    MobiStatusBadge(
                      label: _humanize(report.category),
                      tone: report.category == 'unsafe_behavior'
                          ? MobiStatusBadgeTone.danger
                          : MobiStatusBadgeTone.info,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '${report.reporterName} reported ${report.reportedName}',
                  style: AppTypography.titleMd.copyWith(color: cs.onSurface),
                ),
                const SizedBox(height: AppSpacing.sm),
                SelectableText(
                  report.details.trim().isEmpty
                      ? 'No details provided.'
                      : report.details,
                  style: AppTypography.bodyMd.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 640;
                    final fields = [
                      AdminFieldPair(
                        label: 'Reporter',
                        value: report.reporterPhone ?? report.reporterId,
                      ),
                      AdminFieldPair(
                        label: 'Reported',
                        value: report.reportedPhone ?? report.reportedId,
                      ),
                      AdminFieldPair(
                        label: 'Trip',
                        value: report.tripId ?? 'None',
                      ),
                      AdminFieldPair(
                        label: 'Conversation',
                        value: report.conversationId ?? 'None',
                      ),
                      AdminFieldPair(label: 'Report ID', value: report.id),
                    ];
                    if (!isWide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final field in fields) ...[
                            field,
                            const SizedBox(height: AppSpacing.md),
                          ],
                        ],
                      );
                    }
                    return Wrap(
                      spacing: AppSpacing.xl,
                      runSpacing: AppSpacing.md,
                      children: [
                        for (final field in fields)
                          SizedBox(width: 220, child: field),
                      ],
                    );
                  },
                ),
                if (report.resolutionNotes?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Resolution notes',
                    style: AppTypography.labelLg.copyWith(color: cs.onSurface),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SelectableText(
                    report.resolutionNotes!,
                    style: AppTypography.bodyMd.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    AdminActionChip(
                      label: 'Reviewing',
                      icon: LucideIcons.eye,
                      onTap: report.status == 'open'
                          ? () {
                              Navigator.of(context).pop();
                              _reviewReport(report, 'reviewing');
                            }
                          : null,
                    ),
                    AdminActionChip(
                      label: 'Resolve',
                      icon: LucideIcons.checkCircle2,
                      tone: MobiStatusBadgeTone.positive,
                      onTap: report.isResolved
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              _reviewReport(report, 'resolved');
                            },
                    ),
                    AdminActionChip(
                      label: 'Dismiss',
                      icon: LucideIcons.xCircle,
                      tone: MobiStatusBadgeTone.warning,
                      onTap: report.isResolved
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              _reviewReport(report, 'dismissed');
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!_actionIsCurrent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  int get _paginationTotal =>
      _page * _rowsPerPage + _reports.length + (_hasNextPage ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final openCount = _reports.where((report) => report.isOpen).length;
    final resolvedCount = _reports.where((report) => report.isResolved).length;
    final unsafeCount = _reports
        .where((report) => report.category == 'unsafe_behavior')
        .length;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: AdminWorkspaceFrame(
          onBack: widget.onBack,
          currentTab: AdminWorkspaceTab.reports,
          title: 'Reports',
          subtitle: 'Chat safety and user blocks.',
          actions: [
            AdminActionChip(
              label: 'Refresh',
              icon: LucideIcons.refreshCw,
              isBusy: _isLoading,
              onTap: _isLoading ? null : _loadReports,
            ),
          ],
          child: RefreshIndicator.adaptive(
            onRefresh: () => _loadReports(silent: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AdminLayoutTokens.overlayPagePadding,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final cardWidth = width >= 1100
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
                            label: 'Visible',
                            value: '${_reports.length}',
                            hint: _statusFilter == 'all'
                                ? 'All reports'
                                : '${_humanize(_statusFilter)} queue',
                            icon: LucideIcons.inbox,
                            tone: MobiStatusBadgeTone.info,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: AdminMetricCard(
                            label: 'Open',
                            value: '$openCount',
                            hint: 'Needs review',
                            icon: LucideIcons.shieldAlert,
                            tone: openCount > 0
                                ? MobiStatusBadgeTone.warning
                                : MobiStatusBadgeTone.positive,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: AdminMetricCard(
                            label: 'Resolved',
                            value: '$resolvedCount',
                            hint: unsafeCount > 0
                                ? '$unsafeCount unsafe-behavior reports'
                                : 'Moderation decisions',
                            icon: LucideIcons.checkCircle2,
                            tone: MobiStatusBadgeTone.positive,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildFilters(),
                const SizedBox(height: AppSpacing.lg),
                if (_isLoading)
                  const Column(
                    children: [
                      LoadingSkeleton(height: 108, borderRadius: 28),
                      SizedBox(height: AppSpacing.md),
                      LoadingSkeleton(height: 320, borderRadius: 28),
                    ],
                  )
                else if (_error != null)
                  AdminEmptyState(
                    title: 'Reports unavailable',
                    message: _error!,
                    icon: LucideIcons.alertTriangle,
                    action: AdminActionChip(
                      label: 'Retry',
                      icon: LucideIcons.refreshCw,
                      onTap: _loadReports,
                    ),
                  )
                else if (_reports.isEmpty)
                  AdminEmptyState(
                    title: 'No reports',
                    message: 'No user reports match this view.',
                    icon: LucideIcons.inbox,
                    action: AdminActionChip(
                      label: 'Clear',
                      icon: LucideIcons.x,
                      onTap: () {
                        setState(() {
                          _statusFilter = 'open';
                          _searchQuery = '';
                          _searchController.clear();
                        });
                        _loadReports();
                      },
                    ),
                  )
                else
                  _buildReportList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(
            title: 'Moderation queue',
            subtitle: 'Search reports, reporters, and reported users',
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 820;
              final search = SizedBox(
                width: isWide ? 420 : double.infinity,
                child: AdminSearchField(
                  controller: _searchController,
                  hintText: 'Search report details or users',
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _page = 0;
                    });
                    _loadReports(silent: true);
                  },
                ),
              );
              final filters = Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final status in const [
                    'open',
                    'reviewing',
                    'resolved',
                    'dismissed',
                    'all',
                  ])
                    AdminFilterChip(
                      label: _humanize(status),
                      isSelected: _statusFilter == status,
                      onTap: () {
                        setState(() {
                          _statusFilter = status;
                          _page = 0;
                        });
                        _loadReports();
                      },
                    ),
                ],
              );

              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        search,
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: filters),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        search,
                        const SizedBox(height: AppSpacing.md),
                        filters,
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReportList() {
    return AdminPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final report in _reports)
            _ReportTile(
              report: report,
              isBusy: _busyId == report.id,
              onViewDetails: () => _showReportDetailSheet(report),
              onMarkReviewing: report.status == 'open'
                  ? () => _reviewReport(report, 'reviewing')
                  : null,
              onResolve: report.isResolved
                  ? null
                  : () => _reviewReport(report, 'resolved'),
              onDismiss: report.isResolved
                  ? null
                  : () => _reviewReport(report, 'dismissed'),
              onCopyConversation: report.conversationId == null
                  ? null
                  : () async {
                      if (!_actionIsCurrent) return;
                      try {
                        await ExternalAction.run(
                          Clipboard.setData(
                            ClipboardData(text: report.conversationId!),
                          ),
                          operation: 'copy_conversation_id',
                        );
                        _showSnackBar('Conversation ID copied.');
                      } on Object {
                        _showSnackBar(
                          'Conversation ID copy was not confirmed.',
                        );
                      }
                    },
            ),
          AdminPaginationBar(
            totalItems: _paginationTotal,
            page: _page,
            rowsPerPage: _rowsPerPage,
            onPageChanged: (value) {
              setState(() => _page = value);
              _loadReports(silent: true);
            },
            onRowsPerPageChanged: (value) {
              setState(() {
                _rowsPerPage = value;
                _page = 0;
              });
              _loadReports(silent: true);
            },
          ),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.report,
    required this.isBusy,
    this.onMarkReviewing,
    this.onResolve,
    this.onDismiss,
    this.onCopyConversation,
    this.onViewDetails,
  });

  final AdminUserReportItem report;
  final bool isBusy;
  final VoidCallback? onMarkReviewing;
  final VoidCallback? onResolve;
  final VoidCallback? onDismiss;
  final VoidCallback? onCopyConversation;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                MobiStatusBadge(
                  label: _humanize(report.status),
                  tone: _statusTone(report.status),
                ),
                MobiStatusBadge(
                  label: _humanize(report.category),
                  tone: report.category == 'unsafe_behavior'
                      ? MobiStatusBadgeTone.danger
                      : MobiStatusBadgeTone.info,
                ),
                Text(
                  AdminDashboardUtils.formatTimestamp(report.createdAt),
                  style: AppTypography.labelMd.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${report.reporterName} reported ${report.reportedName}',
              style: AppTypography.titleMd.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              report.details.trim().isEmpty
                  ? 'No details provided.'
                  : report.details,
              style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 760;
                final fields = [
                  AdminFieldPair(
                    label: 'Reporter',
                    value: report.reporterPhone ?? report.reporterId,
                  ),
                  AdminFieldPair(
                    label: 'Reported',
                    value: report.reportedPhone ?? report.reportedId,
                  ),
                  AdminFieldPair(label: 'Trip', value: report.tripId ?? 'None'),
                  AdminFieldPair(
                    label: 'Conversation',
                    value: report.conversationId ?? 'None',
                  ),
                ];

                return isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final field in fields)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  right: AppSpacing.md,
                                ),
                                child: field,
                              ),
                            ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final field in fields) ...[
                            field,
                            const SizedBox(height: AppSpacing.sm),
                          ],
                        ],
                      );
              },
            ),
            if (report.resolutionNotes?.trim().isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Resolution: ${report.resolutionNotes}',
                style: AppTypography.bodySm.copyWith(color: cs.onSurface),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AdminActionChip(
                  label: 'Details',
                  icon: LucideIcons.panelTopOpen,
                  onTap: onViewDetails,
                ),
                AdminActionChip(
                  label: 'Reviewing',
                  icon: LucideIcons.eye,
                  isBusy: isBusy && onMarkReviewing != null,
                  onTap: isBusy ? null : onMarkReviewing,
                ),
                AdminActionChip(
                  label: 'Resolve',
                  icon: LucideIcons.checkCircle2,
                  tone: MobiStatusBadgeTone.positive,
                  isBusy: isBusy && onResolve != null,
                  onTap: isBusy ? null : onResolve,
                ),
                AdminActionChip(
                  label: 'Dismiss',
                  icon: LucideIcons.xCircle,
                  tone: MobiStatusBadgeTone.warning,
                  isBusy: isBusy && onDismiss != null,
                  onTap: isBusy ? null : onDismiss,
                ),
                AdminActionChip(
                  label: 'Copy conversation',
                  icon: LucideIcons.copy,
                  onTap: onCopyConversation,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

MobiStatusBadgeTone _statusTone(String status) {
  return switch (status) {
    'resolved' => MobiStatusBadgeTone.positive,
    'dismissed' => MobiStatusBadgeTone.neutral,
    'reviewing' => MobiStatusBadgeTone.warning,
    _ => MobiStatusBadgeTone.danger,
  };
}

String _humanize(String value) {
  final normalized = value.trim().replaceAll('_', ' ');
  if (normalized.isEmpty) return value;
  return normalized
      .split(' ')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}
