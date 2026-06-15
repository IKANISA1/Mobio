import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/admin_service.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/features/admin/widgets/admin_dashboard_utils.dart';
import 'package:mobi_app/features/admin/widgets/admin_ui.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';

class AdminOperationalHealthScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const AdminOperationalHealthScreen({super.key, required this.onBack});

  @override
  ConsumerState<AdminOperationalHealthScreen> createState() =>
      _AdminOperationalHealthScreenState();
}

class _AdminOperationalHealthScreenState
    extends ConsumerState<AdminOperationalHealthScreen> {
  AdminService get _adminService => ref.read(adminServiceProvider);

  final _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  List<AdminOperationalHealthEventItem> _events = [];
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _severityFilter = 'all';
  String _serviceFilter = 'all';
  String _sortKey = 'newest';
  int _page = 0;
  int _rowsPerPage = 25;
  bool _hasNextPage = false;

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
      final events = await _adminService.listOperationalHealthEvents(
        status: _statusFilter == 'all' ? null : _statusFilter,
        severity: _severityFilter == 'all' ? null : _severityFilter,
        service: _serviceFilter == 'all' ? null : _serviceFilter,
        search: _searchQuery,
        limit: _rowsPerPage + 1,
        offset: _page * _rowsPerPage,
      );
      if (!mounted) return;
      final hasNextPage = events.length > _rowsPerPage;
      setState(() {
        _events = events.take(_rowsPerPage).toList();
        _hasNextPage = hasNextPage;
        _isLoading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleEvents = _visibleEvents();
    final pagedEvents = _pagedEvents(visibleEvents);
    final services = _uniqueValues(_events.map((event) => event.service));
    final errorCount = _events.where((event) => event.isError).length;
    final warningCount = _events
        .where((event) => event.isWarning && !event.isError)
        .length;
    final serviceCount = services.length;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: AdminWorkspaceFrame(
          onBack: widget.onBack,
          currentTab: AdminWorkspaceTab.health,
          title: 'Health',
          subtitle: 'Backend runtime events.',
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
                _HealthMetricGrid(
                  totalCount: _events.length,
                  errorCount: errorCount,
                  warningCount: warningCount,
                  serviceCount: serviceCount,
                ),
                const SizedBox(height: AppSpacing.lg),
                AdminPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AdminSectionHeader(
                        title: 'Runtime Events',
                        subtitle: 'Search, filter, inspect',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 900;
                          final search = SizedBox(
                            width: isWide ? 360 : double.infinity,
                            child: AdminSearchField(
                              controller: _searchController,
                              hintText: 'Search service, code, function',
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                  _page = 0;
                                });
                                _load();
                              },
                            ),
                          );
                          final controls = Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              AdminSortMenu(
                                value: _sortKey,
                                options: const [
                                  AdminSortOption(
                                    value: 'newest',
                                    label: 'Newest',
                                    icon: LucideIcons.clock,
                                  ),
                                  AdminSortOption(
                                    value: 'severity',
                                    label: 'Severity',
                                    icon: LucideIcons.shieldAlert,
                                  ),
                                  AdminSortOption(
                                    value: 'service',
                                    label: 'Service',
                                    icon: LucideIcons.server,
                                  ),
                                  AdminSortOption(
                                    value: 'status',
                                    label: 'Status',
                                    icon: LucideIcons.activity,
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
                          AdminFilterChip(
                            label: 'All status',
                            icon: LucideIcons.listFilter,
                            isSelected: _statusFilter == 'all',
                            onTap: () => _setStatusFilter('all'),
                          ),
                          AdminFilterChip(
                            label: 'Error',
                            icon: LucideIcons.alertCircle,
                            isSelected: _statusFilter == 'error',
                            onTap: () => _setStatusFilter('error'),
                          ),
                          AdminFilterChip(
                            label: 'Warn',
                            icon: LucideIcons.alertTriangle,
                            isSelected: _statusFilter == 'warn',
                            onTap: () => _setStatusFilter('warn'),
                          ),
                          AdminFilterChip(
                            label: 'Ok',
                            icon: LucideIcons.checkCircle,
                            isSelected: _statusFilter == 'ok',
                            onTap: () => _setStatusFilter('ok'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          AdminFilterChip(
                            label: 'All severity',
                            icon: LucideIcons.shield,
                            isSelected: _severityFilter == 'all',
                            onTap: () => _setSeverityFilter('all'),
                          ),
                          AdminFilterChip(
                            label: 'Critical',
                            isSelected: _severityFilter == 'critical',
                            onTap: () => _setSeverityFilter('critical'),
                          ),
                          AdminFilterChip(
                            label: 'Warning',
                            isSelected: _severityFilter == 'warning',
                            onTap: () => _setSeverityFilter('warning'),
                          ),
                          AdminFilterChip(
                            label: 'Info',
                            isSelected: _severityFilter == 'info',
                            onTap: () => _setSeverityFilter('info'),
                          ),
                        ],
                      ),
                      if (services.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            AdminFilterChip(
                              label: 'All services',
                              icon: LucideIcons.server,
                              isSelected: _serviceFilter == 'all',
                              onTap: () => _setServiceFilter('all'),
                            ),
                            for (final service in services.take(8))
                              AdminFilterChip(
                                label: _humanize(service),
                                isSelected: _serviceFilter == service,
                                onTap: () => _setServiceFilter(service),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_isLoading)
                  const Column(
                    children: [
                      LoadingSkeleton(height: 108, borderRadius: 28),
                      SizedBox(height: AppSpacing.md),
                      LoadingSkeleton(height: 360, borderRadius: 28),
                    ],
                  )
                else if (_error != null)
                  AdminEmptyState(
                    title: 'Health events unavailable',
                    message: _error!,
                    icon: LucideIcons.alertTriangle,
                    action: AdminActionChip(
                      label: 'Retry',
                      icon: LucideIcons.refreshCw,
                      onTap: _load,
                    ),
                  )
                else if (visibleEvents.isEmpty)
                  const AdminEmptyState(
                    title: 'No health events',
                    message: 'No operational events match this view.',
                    icon: LucideIcons.activity,
                  )
                else
                  AdminPanel(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var index = 0; index < pagedEvents.length; index++)
                          Column(
                            children: [
                              _OperationalHealthRow(item: pagedEvents[index]),
                              if (index < pagedEvents.length - 1)
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
                          totalItems: _paginationTotal,
                          page: _page,
                          rowsPerPage: _rowsPerPage,
                          onPageChanged: (page) {
                            setState(() => _page = page);
                            _load();
                          },
                          onRowsPerPageChanged: (rows) {
                            setState(() {
                              _rowsPerPage = rows;
                              _page = 0;
                            });
                            _load();
                          },
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

  void _setStatusFilter(String value) {
    setState(() {
      _statusFilter = value;
      _page = 0;
    });
    _load();
  }

  void _setSeverityFilter(String value) {
    setState(() {
      _severityFilter = value;
      _page = 0;
    });
    _load();
  }

  void _setServiceFilter(String value) {
    setState(() {
      _serviceFilter = value;
      _page = 0;
    });
    _load();
  }

  List<AdminOperationalHealthEventItem> _visibleEvents() {
    final query = _searchQuery.trim().toLowerCase();
    final events = _events.where((event) {
      if (_statusFilter != 'all' && event.status != _statusFilter) {
        return false;
      }
      if (_severityFilter != 'all' && event.severity != _severityFilter) {
        return false;
      }
      if (_serviceFilter != 'all' && event.service != _serviceFilter) {
        return false;
      }
      if (query.isEmpty) return true;

      return event.service.toLowerCase().contains(query) ||
          event.component.toLowerCase().contains(query) ||
          event.status.toLowerCase().contains(query) ||
          event.severity.toLowerCase().contains(query) ||
          (event.issueCode ?? '').toLowerCase().contains(query) ||
          event.message.toLowerCase().contains(query) ||
          (event.functionName ?? '').toLowerCase().contains(query) ||
          event.userName.toLowerCase().contains(query) ||
          (event.subjectType ?? '').toLowerCase().contains(query) ||
          (event.subjectId ?? '').toLowerCase().contains(query) ||
          event.metadata.toString().toLowerCase().contains(query);
    }).toList();

    return events..sort((a, b) {
      return switch (_sortKey) {
        'severity' => _severityRank(b).compareTo(_severityRank(a)),
        'service' => a.service.compareTo(b.service),
        'status' => a.status.compareTo(b.status),
        _ => _dateValue(
          b.createdAt ?? b.occurredAt,
        ).compareTo(_dateValue(a.createdAt ?? a.occurredAt)),
      };
    });
  }

  List<AdminOperationalHealthEventItem> _pagedEvents(
    List<AdminOperationalHealthEventItem> events,
  ) {
    return events;
  }

  int get _paginationTotal =>
      _page * _rowsPerPage + _events.length + (_hasNextPage ? 1 : 0);

  int _dateValue(String? value) =>
      DateTime.tryParse(value ?? '')?.millisecondsSinceEpoch ?? 0;

  int _severityRank(AdminOperationalHealthEventItem event) {
    if (event.severity == 'critical') return 3;
    if (event.status == 'error') return 3;
    if (event.severity == 'warning') return 2;
    if (event.status == 'warn') return 2;
    return 1;
  }

  List<String> _uniqueValues(Iterable<String> values) {
    final set = <String>{};
    for (final value in values) {
      final normalized = value.trim();
      if (normalized.isNotEmpty) set.add(normalized);
    }
    final list = set.toList()..sort();
    return list;
  }
}

class _HealthMetricGrid extends StatelessWidget {
  const _HealthMetricGrid({
    required this.totalCount,
    required this.errorCount,
    required this.warningCount,
    required this.serviceCount,
  });

  final int totalCount;
  final int errorCount;
  final int warningCount;
  final int serviceCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width >= 1120
            ? (width - AppSpacing.md * 3) / 4
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
                label: 'Events',
                value: '$totalCount',
                hint: 'Latest loaded',
                icon: LucideIcons.activity,
                tone: MobiStatusBadgeTone.brand,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: AdminMetricCard(
                label: 'Errors',
                value: '$errorCount',
                hint: 'Needs review',
                icon: LucideIcons.alertCircle,
                tone: errorCount > 0
                    ? MobiStatusBadgeTone.danger
                    : MobiStatusBadgeTone.positive,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: AdminMetricCard(
                label: 'Warnings',
                value: '$warningCount',
                hint: 'Potential drift',
                icon: LucideIcons.alertTriangle,
                tone: warningCount > 0
                    ? MobiStatusBadgeTone.warning
                    : MobiStatusBadgeTone.neutral,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: AdminMetricCard(
                label: 'Services',
                value: '$serviceCount',
                hint: 'Reporting events',
                icon: LucideIcons.server,
                tone: MobiStatusBadgeTone.info,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OperationalHealthRow extends StatelessWidget {
  const _OperationalHealthRow({required this.item});

  final AdminOperationalHealthEventItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final tone = _eventTone(item);

    return Semantics(
      container: true,
      label:
          '${_humanize(item.service)}, ${_humanize(item.status)}, ${item.message}',
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 940;
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
                    _eventIcon(item),
                    size: 20,
                    color: AdminDashboardUtils.toneColor(context, tone),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMd.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${_humanize(item.service)} | ${AdminDashboardUtils.formatTimestamp(item.createdAt ?? item.occurredAt)}',
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

            final badges = Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                MobiStatusBadge(label: _humanize(item.status), tone: tone),
                MobiStatusBadge(
                  label: _humanize(item.severity),
                  tone: _severityTone(item),
                ),
                MobiStatusBadge(
                  label: _humanize(item.component),
                  tone: MobiStatusBadgeTone.neutral,
                ),
                if (item.issueCode != null)
                  MobiStatusBadge(
                    label: item.issueCode!,
                    tone: MobiStatusBadgeTone.info,
                  ),
              ],
            );

            final details = DecoratedBox(
              decoration: BoxDecoration(
                color: ext.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  _detailsPreview(item),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm.copyWith(color: cs.onSurface),
                ),
              ),
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: identity),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(flex: 3, child: badges),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(flex: 4, child: details),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                const SizedBox(height: AppSpacing.md),
                badges,
                const SizedBox(height: AppSpacing.md),
                details,
              ],
            );
          },
        ),
      ),
    );
  }
}

String _humanize(String value) {
  return value
      .trim()
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);

String _detailsPreview(AdminOperationalHealthEventItem item) {
  final lines = <String>[
    if (item.functionName != null) 'Function: ${item.functionName}',
    if (item.userId != null) 'User: ${item.userName}',
    if (item.subjectType != null) 'Subject: ${_humanize(item.subjectType!)}',
    if (item.subjectId != null) 'Subject ID: ${_shortId(item.subjectId!)}',
    if (item.metadata.isNotEmpty)
      ...item.metadata.entries
          .take(3)
          .map((entry) => '${_humanize(entry.key)}: ${entry.value}'),
  ];

  return lines.isEmpty ? 'No detail payload' : lines.join('\n');
}

MobiStatusBadgeTone _eventTone(AdminOperationalHealthEventItem item) {
  if (item.status == 'error' || item.severity == 'critical') {
    return MobiStatusBadgeTone.danger;
  }
  if (item.status == 'warn' || item.severity == 'warning') {
    return MobiStatusBadgeTone.warning;
  }
  if (item.status == 'ok') {
    return MobiStatusBadgeTone.positive;
  }
  return MobiStatusBadgeTone.info;
}

MobiStatusBadgeTone _severityTone(AdminOperationalHealthEventItem item) {
  return switch (item.severity) {
    'critical' => MobiStatusBadgeTone.danger,
    'warning' => MobiStatusBadgeTone.warning,
    'info' => MobiStatusBadgeTone.info,
    _ => MobiStatusBadgeTone.neutral,
  };
}

IconData _eventIcon(AdminOperationalHealthEventItem item) {
  if (item.status == 'error' || item.severity == 'critical') {
    return LucideIcons.alertCircle;
  }
  if (item.status == 'warn' || item.severity == 'warning') {
    return LucideIcons.alertTriangle;
  }
  if ((item.functionName ?? '').isNotEmpty) {
    return LucideIcons.workflow;
  }
  return LucideIcons.activity;
}
