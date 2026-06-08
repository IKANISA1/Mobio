import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/services/admin_service.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/features/admin/widgets/admin_ui.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';

class AdminUserMetrics extends StatelessWidget {
  const AdminUserMetrics({
    super.key,
    required this.users,
    required this.roleFilter,
  });

  final List<AdminUserListItem> users;
  final String roleFilter;

  @override
  Widget build(BuildContext context) {
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
                label: 'Results',
                value: '${users.length}',
                hint: roleFilter == 'all'
                    ? 'Visible now'
                    : '${roleFilter[0].toUpperCase()}${roleFilter.substring(1)} only',
                icon: LucideIcons.users,
                tone: MobiStatusBadgeTone.brand,
              ),
            ),
            _MetricSizedCard(
              width: cardWidth,
              child: AdminMetricCard(
                label: 'Admins',
                value: '$totalAdmins',
                hint: 'Role coverage',
                icon: LucideIcons.shieldCheck,
                tone: MobiStatusBadgeTone.info,
              ),
            ),
            _MetricSizedCard(
              width: cardWidth,
              child: AdminMetricCard(
                label: 'Online',
                value: '$onlineUsers',
                hint: 'Live now',
                icon: LucideIcons.activity,
                tone: MobiStatusBadgeTone.positive,
              ),
            ),
            _MetricSizedCard(
              width: cardWidth,
              child: AdminMetricCard(
                label: 'Drivers',
                value: '$drivers',
                hint: 'Discovery supply',
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
