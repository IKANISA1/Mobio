import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/features/admin/presentation/admin_copy.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_shared_types/models/admin/admin_models.dart';

class AdminUserMetrics extends StatelessWidget {
  const AdminUserMetrics({
    super.key,
    required this.users,
    required this.roleFilter,
    required this.totalExact,
    this.asOf,
  });

  final List<AdminUserListItem> users;
  final String roleFilter;
  final int? totalExact;
  final DateTime? asOf;

  @override
  Widget build(BuildContext context) {
    final copy = AdminCopy.of(context);
    final totalAdmins = users.where((user) => user.role == 'admin').length;
    final onlineUsers = users.where((user) => user.isOnline).length;
    final drivers = users.where((user) => user.isDriver).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width >= 1200
            ? (width - AppSpacing.md * 3) / 4
            : width >= 760
            ? (width - AppSpacing.md) / 2
            : width;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _MetricSizedCard(
              width: cardWidth,
              child: AdminMetricCard(
                label: copy.matchingUsers,
                value: totalExact == null
                    ? copy.unavailable
                    : copy.number(totalExact!),
                hint: asOf == null
                    ? copy.countUnavailable
                    : copy.messageSnapshotAt(copy.timestamp(asOf!)),
                icon: LucideIcons.users,
                tone: MobiStatusBadgeTone.brand,
              ),
            ),
            _MetricSizedCard(
              width: cardWidth,
              child: AdminMetricCard(
                label: copy.adminProfiles,
                value: copy.number(totalAdmins),
                hint: copy.pageAtSnapshot,
                icon: LucideIcons.shieldCheck,
                tone: MobiStatusBadgeTone.info,
              ),
            ),
            _MetricSizedCard(
              width: cardWidth,
              child: AdminMetricCard(
                label: copy.online,
                value: copy.number(onlineUsers),
                hint: copy.pageAtSnapshot,
                icon: LucideIcons.activity,
                tone: MobiStatusBadgeTone.positive,
              ),
            ),
            _MetricSizedCard(
              width: cardWidth,
              child: AdminMetricCard(
                label: copy.filterDrivers,
                value: copy.number(drivers),
                hint: copy.pageAtSnapshot,
                icon: LucideIcons.car,
                tone: MobiStatusBadgeTone.info,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricSizedCard extends StatelessWidget {
  const _MetricSizedCard({required this.width, required this.child});
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, child: child);
  }
}
