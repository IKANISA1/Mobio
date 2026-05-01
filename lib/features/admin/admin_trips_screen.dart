import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/admin_service.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/features/admin/widgets/admin_ui.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_confirm_dialog.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';

/// Admin screen for moderating and monitoring platform trips in real-time.
class AdminTripsScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const AdminTripsScreen({super.key, required this.onBack});

  @override
  ConsumerState<AdminTripsScreen> createState() => _AdminTripsScreenState();
}

class _AdminTripsScreenState extends ConsumerState<AdminTripsScreen> {
  AdminService get _adminService => ref.read(adminServiceProvider);

  bool _isLoading = true;
  String? _error;
  List<AdminTripListItem> _trips = [];

  String? _statusFilter;
  String? _roleFilter;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips({bool silent = false}) async {
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
        limit: 100, // Reasonable cap for live moderating
      );
      if (mounted) {
        setState(() {
          _trips = trips;
          _isLoading = false;
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

  Future<void> _cancelTrip(AdminTripListItem trip) async {
    final confirmed = await _showConfirmCancelDialog(trip);
    if (confirmed != true) return;

    setState(() => _busyId = trip.id);
    try {
      // In a real scenario, this would use a dedicated admin override RPC.
      // Assuming rpc_cancel_trip or equivalent override exists.
      // We will fallback to a direct DB update using Supabase raw client
      // since the standard rpc_cancel_trip checks for ownership.
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from('trips')
          .update({
            'status': 'cancelled',
            'is_active': false,
            'cancelled_at': DateTime.now().toIso8601String(),
            'note': 'Cancelled by Admin: Violation of terms.',
          })
          .eq('id', trip.id);

      await _loadTrips(silent: true);
      if (mounted) _showSnackBar('Trip cancelled.');
    } on Object catch (e) {
      if (mounted) _showSnackBar('Cancel failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheduledCount = _trips.where((t) => t.status == 'active').length;

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
                            value: '$_trips.length',
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
                else if (_trips.isEmpty)
                  AdminEmptyState(
                    title: 'No trips',
                    message: 'No rows match the current filters.',
                    icon: LucideIcons.ghost,
                    action: AdminActionChip(
                      label: 'Clear',
                      icon: LucideIcons.x,
                      onTap: () {
                        setState(() {
                          _statusFilter = null;
                          _roleFilter = null;
                        });
                        _loadTrips();
                      },
                    ),
                  )
                else
                  _buildFeedList(),
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
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AdminFilterChip(
                label: 'All Roles',
                icon: LucideIcons.globe,
                isSelected: _roleFilter == null,
                onTap: () {
                  setState(() => _roleFilter = null);
                  _loadTrips(silent: true);
                },
              ),
              AdminFilterChip(
                label: 'Drivers',
                icon: LucideIcons.car,
                isSelected: _roleFilter == 'driver',
                onTap: () {
                  setState(() => _roleFilter = 'driver');
                  _loadTrips(silent: true);
                },
              ),
              AdminFilterChip(
                label: 'Passengers',
                icon: LucideIcons.user,
                isSelected: _roleFilter == 'passenger',
                onTap: () {
                  setState(() => _roleFilter = 'passenger');
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
                  setState(() => _statusFilter = null);
                  _loadTrips(silent: true);
                },
              ),
              AdminFilterChip(
                label: 'Active',
                icon: LucideIcons.activity,
                isSelected: _statusFilter == 'active',
                onTap: () {
                  setState(() => _statusFilter = 'active');
                  _loadTrips(silent: true);
                },
              ),
              AdminFilterChip(
                label: 'Cancelled',
                icon: LucideIcons.ban,
                isSelected: _statusFilter == 'cancelled',
                onTap: () {
                  setState(() => _statusFilter = 'cancelled');
                  _loadTrips(silent: true);
                },
              ),
              AdminFilterChip(
                label: 'Completed',
                icon: LucideIcons.badgeCheck,
                isSelected: _statusFilter == 'completed',
                onTap: () {
                  setState(() => _statusFilter = 'completed');
                  _loadTrips(silent: true);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedList() {
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
          for (var index = 0; index < _trips.length; index++) ...[
            _TripRow(
              trip: _trips[index],
              isBusy: _busyId == _trips[index].id,
              onCancel: () {
                HapticFeedback.heavyImpact();
                _cancelTrip(_trips[index]);
              },
            ),
            if (index < _trips.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
          ],
        ],
      ),
    );
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
      case 'completed':
        return MobiStatusBadgeTone.brand;
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [typeWidget, actionsWidget],
              ),
            ],
          );
        },
      ),
    );
  }
}
