import 'dart:convert';

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
import 'package:mobi_app/shared/widgets/mobi_bottom_sheet.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';

class AdminAuditLogScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final String? initialSearch;

  const AdminAuditLogScreen({
    super.key,
    required this.onBack,
    this.initialSearch,
  });

  @override
  ConsumerState<AdminAuditLogScreen> createState() =>
      _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends ConsumerState<AdminAuditLogScreen> {
  AdminService get _adminService => ref.read(adminServiceProvider);

  final _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  List<AdminAuditLogItem> _logs = [];
  String _searchQuery = '';
  String _actionFilter = 'all';
  String _targetFilter = 'all';
  String _sortKey = 'newest';
  int _page = 0;
  int _rowsPerPage = 25;

  @override
  void initState() {
    super.initState();
    final initialSearch = widget.initialSearch?.trim();
    if (initialSearch != null && initialSearch.isNotEmpty) {
      _searchController.text = initialSearch;
      _searchQuery = initialSearch;
    }
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAuditDetailSheet(AdminAuditLogItem item) {
    final cs = Theme.of(context).colorScheme;
    final payload = item.details.isEmpty
        ? 'No detail payload'
        : const JsonEncoder.withIndent('  ').convert(item.details);

    return MobiBottomSheet.show<void>(
      context: context,
      title: 'Audit event',
      builder: (context) {
        final tone = _actionTone(item.action);
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
                            AdminDashboardUtils.formatTimestamp(item.createdAt),
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
                    MobiStatusBadge(label: _humanize(item.action), tone: tone),
                    MobiStatusBadge(
                      label: _humanize(item.targetType),
                      tone: MobiStatusBadgeTone.neutral,
                    ),
                    if (_isSensitiveAction(item))
                      const MobiStatusBadge(
                        label: 'Sensitive',
                        icon: LucideIcons.shieldAlert,
                        tone: MobiStatusBadgeTone.warning,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 640;
                    final fields = [
                      AdminFieldPair(label: 'Actor', value: item.adminName),
                      AdminFieldPair(label: 'Action', value: item.action),
                      AdminFieldPair(
                        label: 'Target type',
                        value: item.targetType,
                      ),
                      AdminFieldPair(
                        label: 'Target ID',
                        value: item.targetId ?? 'None',
                      ),
                      AdminFieldPair(
                        label: 'Created',
                        value: item.createdAt ?? 'Unknown',
                      ),
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
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Detail payload',
                  style: AppTypography.labelLg.copyWith(color: cs.onSurface),
                ),
                const SizedBox(height: AppSpacing.xs),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).extension<MobiThemeExtension>()!.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: SelectableText(
                      payload,
                      style: AppTypography.bodySm.copyWith(
                        color: cs.onSurface,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final logs = await _adminService.listAuditLogs(limit: 100);
      if (mounted) {
        setState(() {
          _logs = logs;
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

  @override
  Widget build(BuildContext context) {
    final visibleLogs = _visibleLogs();
    final pagedLogs = _pagedLogs(visibleLogs);
    final uniqueActions = _uniqueValues(_logs.map((log) => log.action));
    final uniqueTargets = _uniqueValues(_logs.map((log) => log.targetType));
    final sensitiveCount = _logs.where(_isSensitiveAction).length;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: AdminWorkspaceFrame(
          onBack: widget.onBack,
          currentTab: AdminWorkspaceTab.audit,
          title: 'Audit',
          subtitle: 'Admin actions.',
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
                _AuditMetricGrid(
                  totalCount: _logs.length,
                  sensitiveCount: sensitiveCount,
                  actorCount: _uniqueValues(
                    _logs.map((log) => log.adminName),
                  ).length,
                ),
                const SizedBox(height: AppSpacing.lg),
                AdminPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AdminSectionHeader(
                        title: 'Events',
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
                              hintText: 'Search action, actor, target',
                              onChanged: (value) => setState(() {
                                _searchQuery = value;
                                _page = 0;
                              }),
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
                                    value: 'actor',
                                    label: 'Actor',
                                    icon: LucideIcons.user,
                                  ),
                                  AdminSortOption(
                                    value: 'action',
                                    label: 'Action',
                                    icon: LucideIcons.activity,
                                  ),
                                  AdminSortOption(
                                    value: 'target',
                                    label: 'Target',
                                    icon: LucideIcons.crosshair,
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
                            label: 'All actions',
                            icon: LucideIcons.list,
                            isSelected: _actionFilter == 'all',
                            onTap: () => setState(() {
                              _actionFilter = 'all';
                              _page = 0;
                            }),
                          ),
                          for (final action in uniqueActions.take(6))
                            AdminFilterChip(
                              label: _humanize(action),
                              isSelected: _actionFilter == action,
                              onTap: () => setState(() {
                                _actionFilter = action;
                                _page = 0;
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          AdminFilterChip(
                            label: 'All targets',
                            icon: LucideIcons.box,
                            isSelected: _targetFilter == 'all',
                            onTap: () => setState(() {
                              _targetFilter = 'all';
                              _page = 0;
                            }),
                          ),
                          for (final target in uniqueTargets.take(6))
                            AdminFilterChip(
                              label: _humanize(target),
                              isSelected: _targetFilter == target,
                              onTap: () => setState(() {
                                _targetFilter = target;
                                _page = 0;
                              }),
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
                      LoadingSkeleton(height: 108, borderRadius: 28),
                      SizedBox(height: AppSpacing.md),
                      LoadingSkeleton(height: 360, borderRadius: 28),
                    ],
                  )
                else if (_error != null)
                  AdminEmptyState(
                    title: 'Audit log unavailable',
                    message: _error!,
                    icon: LucideIcons.alertTriangle,
                    action: AdminActionChip(
                      label: 'Retry',
                      icon: LucideIcons.refreshCw,
                      onTap: _load,
                    ),
                  )
                else if (visibleLogs.isEmpty)
                  const AdminEmptyState(
                    title: 'No audit events',
                    message: 'No admin actions match this view.',
                    icon: LucideIcons.clipboardList,
                  )
                else
                  AdminPanel(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var index = 0; index < pagedLogs.length; index++)
                          Column(
                            children: [
                              _AuditLogRow(
                                item: pagedLogs[index],
                                onViewDetails: () =>
                                    _showAuditDetailSheet(pagedLogs[index]),
                              ),
                              if (index < pagedLogs.length - 1)
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
                          totalItems: visibleLogs.length,
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

  List<AdminAuditLogItem> _visibleLogs() {
    final query = _searchQuery.trim().toLowerCase();
    final logs = _logs.where((log) {
      final matchesAction =
          _actionFilter == 'all' || log.action == _actionFilter;
      final matchesTarget =
          _targetFilter == 'all' || log.targetType == _targetFilter;
      if (!matchesAction || !matchesTarget) return false;
      if (query.isEmpty) return true;

      return log.action.toLowerCase().contains(query) ||
          log.targetType.toLowerCase().contains(query) ||
          log.adminName.toLowerCase().contains(query) ||
          (log.targetId ?? '').toLowerCase().contains(query) ||
          log.details.toString().toLowerCase().contains(query);
    }).toList();

    return logs..sort((a, b) {
      return switch (_sortKey) {
        'actor' => a.adminName.toLowerCase().compareTo(
          b.adminName.toLowerCase(),
        ),
        'action' => a.action.compareTo(b.action),
        'target' => a.targetType.compareTo(b.targetType),
        _ => _dateValue(b.createdAt).compareTo(_dateValue(a.createdAt)),
      };
    });
  }

  List<AdminAuditLogItem> _pagedLogs(List<AdminAuditLogItem> logs) {
    if (logs.isEmpty) return const [];
    final safeRowsPerPage = _rowsPerPage <= 0 ? 25 : _rowsPerPage;
    final start = (_page * safeRowsPerPage).clamp(0, logs.length).toInt();
    final end = (start + safeRowsPerPage).clamp(0, logs.length).toInt();
    return logs.sublist(start, end);
  }

  int _dateValue(String? value) =>
      DateTime.tryParse(value ?? '')?.millisecondsSinceEpoch ?? 0;

  bool _isSensitiveAction(AdminAuditLogItem log) {
    final action = log.action.toLowerCase();
    return action.contains('role') ||
        action.contains('risk') ||
        action.contains('cancel') ||
        action.contains('whatsapp') ||
        action.contains('delete');
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

class _AuditMetricGrid extends StatelessWidget {
  const _AuditMetricGrid({
    required this.totalCount,
    required this.sensitiveCount,
    required this.actorCount,
  });

  final int totalCount;
  final int sensitiveCount;
  final int actorCount;

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
                label: 'Events',
                value: '$totalCount',
                hint: 'Latest loaded',
                icon: LucideIcons.clipboardList,
                tone: MobiStatusBadgeTone.brand,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: AdminMetricCard(
                label: 'Sensitive',
                value: '$sensitiveCount',
                hint: 'Actions requiring review',
                icon: LucideIcons.shieldAlert,
                tone: sensitiveCount > 0
                    ? MobiStatusBadgeTone.warning
                    : MobiStatusBadgeTone.neutral,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: AdminMetricCard(
                label: 'Actors',
                value: '$actorCount',
                hint: 'Admins in view',
                icon: LucideIcons.users,
                tone: MobiStatusBadgeTone.info,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AuditLogRow extends StatelessWidget {
  const _AuditLogRow({required this.item, this.onViewDetails});

  final AdminAuditLogItem item;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final tone = _actionTone(item.action);

    return Semantics(
      container: true,
      label:
          '${item.adminName}, ${_humanize(item.action)}, ${_humanize(item.targetType)}',
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
                    _actionIcon(item.action),
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
                        _humanize(item.action),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMd.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${item.adminName} | ${AdminDashboardUtils.formatTimestamp(item.createdAt)}',
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

            final target = Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                MobiStatusBadge(label: _humanize(item.targetType), tone: tone),
                if (item.targetId != null)
                  MobiStatusBadge(
                    label: _shortId(item.targetId!),
                    tone: MobiStatusBadgeTone.neutral,
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
                  _detailsPreview(item.details),
                  maxLines: 4,
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
                  Expanded(flex: 2, child: target),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(flex: 4, child: details),
                  const SizedBox(width: AppSpacing.md),
                  AdminActionChip(
                    label: 'Details',
                    icon: LucideIcons.panelTopOpen,
                    onTap: onViewDetails,
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                const SizedBox(height: AppSpacing.md),
                target,
                const SizedBox(height: AppSpacing.md),
                details,
                const SizedBox(height: AppSpacing.md),
                AdminActionChip(
                  label: 'Details',
                  icon: LucideIcons.panelTopOpen,
                  onTap: onViewDetails,
                ),
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
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);

String _detailsPreview(Map<String, dynamic> details) {
  if (details.isEmpty) return 'No detail payload';
  return details.entries
      .take(4)
      .map((entry) => '${_humanize(entry.key)}: ${entry.value}')
      .join('\n');
}

MobiStatusBadgeTone _actionTone(String action) {
  final normalized = action.toLowerCase();
  if (normalized.contains('risk') ||
      normalized.contains('cancel') ||
      normalized.contains('delete')) {
    return MobiStatusBadgeTone.danger;
  }
  if (normalized.contains('role') || normalized.contains('whatsapp')) {
    return MobiStatusBadgeTone.warning;
  }
  if (normalized.contains('send') || normalized.contains('promo')) {
    return MobiStatusBadgeTone.info;
  }
  return MobiStatusBadgeTone.brand;
}

IconData _actionIcon(String action) {
  final normalized = action.toLowerCase();
  if (normalized.contains('risk')) return LucideIcons.shieldAlert;
  if (normalized.contains('role')) return LucideIcons.userCog;
  if (normalized.contains('whatsapp')) return LucideIcons.messageCircle;
  if (normalized.contains('cancel')) return LucideIcons.ban;
  if (normalized.contains('promo') || normalized.contains('send')) {
    return LucideIcons.radio;
  }
  return LucideIcons.activity;
}
