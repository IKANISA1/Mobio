import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/auth/account_action_token.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/features/admin/application/admin_services.dart';
import 'package:mobi_app/features/admin/data/admin_service.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_confirm_dialog.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

/// Admin screen for moderating and monitoring platform trips in real-time.
class AdminTripsScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const AdminTripsScreen({super.key, required this.onBack});

  @override
  ConsumerState<AdminTripsScreen> createState() => _AdminTripsScreenState();
}

class _AdminTripsScreenState extends ConsumerState<AdminTripsScreen> {
  final _actionToken = AccountActionToken.capture();
  bool get _actionIsCurrent => mounted && _actionToken.isCurrent;

  AdminService get _adminService => ref.read(adminServiceProvider);

  late final TextEditingController _searchController;

  bool _isLoading = true;
  String? _error;
  List<AdminTripListItem> _trips = [];

  String? _statusFilter;
  String? _roleFilter;
  String _searchQuery = '';
  String _sortKey = 'newest';
  int _page = 0;
  int _rowsPerPage = 25;
  bool _hasNextPage = false;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadTrips();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrips({bool silent = false}) async {
    if (!_actionIsCurrent) return;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final trips = await _adminService.listTrips(
        status: _statusFilter,
        role: _roleFilter,
        search: _searchQuery,
        limit: _rowsPerPage + 1,
        offset: _page * _rowsPerPage,
      );
      if (_actionIsCurrent) {
        final hasNextPage = trips.length > _rowsPerPage;
        setState(() {
          _trips = trips.take(_rowsPerPage).toList();
          _hasNextPage = hasNextPage;
          _isLoading = false;
        });
      }
    } on Object catch (error) {
      if (_actionIsCurrent) {
        setState(() {
          _isLoading = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _cancelTrip(AdminTripListItem trip) async {
    if (!_actionIsCurrent) return;
    final confirmed = await _showConfirmCancelDialog(trip);
    if (confirmed != true || !_actionIsCurrent) return;

    setState(() => _busyId = trip.id);
    try {
      await _adminService.cancelTrip(
        tripId: trip.id,
        reason: 'Manual moderation from admin trips workspace',
      );

      await _loadTrips(silent: true);
      if (_actionIsCurrent) _showSnackBar('Trip cancelled.');
    } on Object catch (e) {
      if (_actionIsCurrent)
        _showSnackBar(
          userMessageForError(e, fallback: 'Unable to cancel the trip.'),
          isError: true,
        );
    } finally {
      if (_actionIsCurrent) setState(() => _busyId = null);
    }
  }

  Future<bool?> _showConfirmCancelDialog(AdminTripListItem trip) {
    return MobiConfirmDialog.show(
      context: context,
      title: 'Cancel trip',
      body:
          'Stop the active trip from ${trip.authorName}? Use this only for admin override cases.',
      confirmLabel: 'Cancel trip',
      cancelLabel: 'Back',
      isDestructive: true,
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

  @override
  Widget build(BuildContext context) {
    final filteredTrips = _filteredTrips();
    final pageTrips = _pageTrips(filteredTrips);
    final scheduledCount = filteredTrips
        .where((t) => t.status == 'active')
        .length;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: AdminWorkspaceFrame(
          onBack: widget.onBack,
          currentTab: AdminWorkspaceTab.trips,
          title: 'Trips',
          subtitle: 'Live feed.',
          actions: [
            AdminActionChip(
              label: 'Refresh',
              icon: LucideIcons.refreshCw,
              onTap: _loadTrips,
            ),
          ],
          child: RefreshIndicator.adaptive(
            onRefresh: () => _loadTrips(silent: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AdminLayoutTokens.overlayPagePadding,
              children: [
                _buildFilters(),
                const SizedBox(height: AppSpacing.lg),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final cardWidth = width >= 760
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
                            value: '${_trips.length}',
                            hint: 'Current filters',
                            icon: LucideIcons.mapPin,
                            tone: MobiStatusBadgeTone.info,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: AdminMetricCard(
                            label: 'Active',
                            value: '$scheduledCount',
                            hint: 'Needs resolution',
                            icon: LucideIcons.car,
                            tone: MobiStatusBadgeTone.brand,
                          ),
                        ),
                      ],
                    );
                  },
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
                    title: 'Trips unavailable',
                    message: _error!,
                    icon: LucideIcons.alertTriangle,
                    action: AdminActionChip(
                      label: 'Retry',
                      icon: LucideIcons.refreshCw,
                      onTap: _loadTrips,
                    ),
                  )
                else if (filteredTrips.isEmpty)
                  AdminEmptyState(
                    title: 'No trips',
                    message: 'No rows match the current filters.',
                    icon: LucideIcons.search,
                    action: AdminActionChip(
                      label: 'Clear',
                      icon: LucideIcons.x,
                      onTap: () {
                        setState(() {
                          _statusFilter = null;
                          _roleFilter = null;
                          _searchQuery = '';
                          _page = 0;
                          _searchController.clear();
                        });
                        _loadTrips();
                      },
                    ),
                  )
                else
                  _buildFeedList(pageTrips),
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
          const AdminSectionHeader(title: 'Feed', subtitle: 'Role and state'),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 760;
              final search = SizedBox(
                width: isWide ? 420 : double.infinity,
                child: AdminSearchField(
                  controller: _searchController,
                  hintText: 'Search trips, members, routes',
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _page = 0;
                    });
                    _loadTrips(silent: true);
                  },
                ),
              );
              final sort = AdminSortMenu(
                value: _sortKey,
                options: const [
                  AdminSortOption(
                    value: 'newest',
                    label: 'Newest',
                    icon: LucideIcons.clock,
                  ),
                  AdminSortOption(
                    value: 'author',
                    label: 'Author',
                    icon: LucideIcons.user,
                  ),
                  AdminSortOption(
                    value: 'route',
                    label: 'Route',
                    icon: LucideIcons.map,
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
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: AppSpacing.md),
                    sort,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  search,
                  const SizedBox(height: AppSpacing.sm),
                  sort,
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
                label: 'All Roles',
                icon: LucideIcons.globe,
                isSelected: _roleFilter == null,
                onTap: () {
                  setState(() {
                    _roleFilter = null;
                    _page = 0;
                  });
                  _loadTrips(silent: true);
                },
              ),
              AdminFilterChip(
                label: 'Drivers',
                icon: LucideIcons.car,
                isSelected: _roleFilter == 'driver',
                onTap: () {
                  setState(() {
                    _roleFilter = 'driver';
                    _page = 0;
                  });
                  _loadTrips(silent: true);
                },
              ),
              AdminFilterChip(
                label: 'Passengers',
                icon: LucideIcons.user,
                isSelected: _roleFilter == 'passenger',
                onTap: () {
                  setState(() {
                    _roleFilter = 'passenger';
                    _page = 0;
                  });
                  _loadTrips(silent: true);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AdminFilterChip(
                label: 'All Statuses',
                icon: LucideIcons.layers,
                isSelected: _statusFilter == null,
                onTap: () {
                  setState(() {
                    _statusFilter = null;
                    _page = 0;
                  });
                  _loadTrips(silent: true);
                },
              ),
              AdminFilterChip(
                label: 'Active',
                icon: LucideIcons.activity,
                isSelected: _statusFilter == 'active',
                onTap: () {
                  setState(() {
                    _statusFilter = 'active';
                    _page = 0;
                  });
                  _loadTrips(silent: true);
                },
              ),
              AdminFilterChip(
                label: 'Cancelled',
                icon: LucideIcons.ban,
                isSelected: _statusFilter == 'cancelled',
                onTap: () {
                  setState(() {
                    _statusFilter = 'cancelled';
                    _page = 0;
                  });
                  _loadTrips(silent: true);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedList(List<AdminTripListItem> trips) {
    return AdminPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 920;
                if (!isWide) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: AdminTableLabel(label: 'Trips'),
                  );
                }

                return const Row(
                  children: [
                    Expanded(flex: 2, child: AdminTableLabel(label: 'Author')),
                    Expanded(flex: 3, child: AdminTableLabel(label: 'Route')),
                    Expanded(flex: 1, child: AdminTableLabel(label: 'Type')),
                    Expanded(flex: 1, child: AdminTableLabel(label: 'Status')),
                    SizedBox(
                      width: 150,
                      child: AdminTableLabel(label: 'Override'),
                    ),
                  ],
                );
              },
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
          for (var index = 0; index < trips.length; index++) ...[
            _TripRow(
              trip: trips[index],
              isBusy: _busyId == trips[index].id,
              onCancel: () {
                HapticFeedback.heavyImpact();
                _cancelTrip(trips[index]);
              },
            ),
            if (index < trips.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
          ],
          AdminPaginationBar(
            totalItems: _paginationTotal,
            page: _page,
            rowsPerPage: _rowsPerPage,
            onPageChanged: (page) {
              setState(() => _page = page);
              _loadTrips(silent: true);
            },
            onRowsPerPageChanged: (rowsPerPage) {
              setState(() {
                _rowsPerPage = rowsPerPage;
                _page = 0;
              });
              _loadTrips(silent: true);
            },
          ),
        ],
      ),
    );
  }

  List<AdminTripListItem> _filteredTrips() {
    final query = _searchQuery.trim().toLowerCase();
    final rows = query.isEmpty
        ? [..._trips]
        : _trips.where((trip) {
            final haystack = [
              trip.authorName,
              trip.memberId,
              trip.origin,
              trip.destination,
              trip.status,
              trip.role,
              trip.vehicleType,
            ].whereType<String>().join(' ').toLowerCase();
            return haystack.contains(query);
          }).toList();
    return rows..sort(_compareTrips);
  }

  List<AdminTripListItem> _pageTrips(List<AdminTripListItem> trips) {
    return trips;
  }

  int get _paginationTotal =>
      _page * _rowsPerPage + _trips.length + (_hasNextPage ? 1 : 0);

  int _compareTrips(AdminTripListItem a, AdminTripListItem b) {
    switch (_sortKey) {
      case 'author':
        return a.authorName.toLowerCase().compareTo(b.authorName.toLowerCase());
      case 'route':
        final routeA = '${a.origin} ${a.destination}'.toLowerCase();
        final routeB = '${b.origin} ${b.destination}'.toLowerCase();
        return routeA.compareTo(routeB);
      case 'status':
        final statusCompare = a.status.compareTo(b.status);
        if (statusCompare != 0) return statusCompare;
        return b.authorName.compareTo(a.authorName);
      case 'newest':
      default:
        final aDate = DateTime.tryParse(a.createdAt ?? '');
        final bDate = DateTime.tryParse(b.createdAt ?? '');
        if (aDate != null && bDate != null) return bDate.compareTo(aDate);
        if (aDate != null) return -1;
        if (bDate != null) return 1;
        return a.authorName.toLowerCase().compareTo(b.authorName.toLowerCase());
    }
  }
}

class _TripRow extends StatelessWidget {
  final AdminTripListItem trip;
  final bool isBusy;
  final VoidCallback onCancel;

  const _TripRow({
    required this.trip,
    required this.isBusy,
    required this.onCancel,
  });

  MobiStatusBadgeTone _getStatusTone(String status) {
    switch (status) {
      case 'active':
        return MobiStatusBadgeTone.positive;
      case 'cancelled':
        return MobiStatusBadgeTone.danger;
      default:
        return MobiStatusBadgeTone.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    String capitalize(String s) =>
        s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

    final authorWidget = Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: ext.surfaceContainerHigh,
          child: Text(
            trip.authorName.isNotEmpty ? trip.authorName[0].toUpperCase() : '?',
            style: AppTypography.labelSm.copyWith(color: cs.onSurface),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trip.authorName,
                style: AppTypography.titleMd.copyWith(color: cs.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
              if (trip.memberId != null)
                Text(
                  'ID: ${trip.memberId}',
                  style: AppTypography.labelSm.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    final routeWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.mapPin, size: 14, color: cs.primary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                trip.origin,
                style: AppTypography.bodySm.copyWith(color: cs.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(LucideIcons.navigation, size: 14, color: cs.secondary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                trip.destination,
                style: AppTypography.bodySm.copyWith(color: cs.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );

    final statusWidget = MobiStatusBadge(
      label: capitalize(trip.status),
      tone: _getStatusTone(trip.status),
    );

    final typeWidget = MobiStatusBadge(
      label: capitalize(trip.role),
      icon: trip.role == 'driver' ? LucideIcons.car : LucideIcons.user,
      tone: trip.role == 'driver'
          ? MobiStatusBadgeTone.info
          : MobiStatusBadgeTone.neutral,
    );

    final actionsWidget = trip.status == 'active'
        ? AdminActionChip(
            label: 'Cancel',
            icon: LucideIcons.xOctagon,
            tone: MobiStatusBadgeTone.danger,
            isBusy: isBusy,
            onTap: onCancel,
          )
        : const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 920;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 2, child: authorWidget),
                Expanded(flex: 3, child: routeWidget),
                Expanded(flex: 1, child: typeWidget),
                Expanded(flex: 1, child: statusWidget),
                SizedBox(width: 150, child: actionsWidget),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: authorWidget),
                  const SizedBox(width: AppSpacing.sm),
                  statusWidget,
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              routeWidget,
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [typeWidget, actionsWidget],
              ),
            ],
          );
        },
      ),
    );
  }
}
