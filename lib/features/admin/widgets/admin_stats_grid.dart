import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/services/admin_service.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/features/admin/widgets/admin_ui.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';

class AdminStatsGrid extends StatelessWidget {
  const AdminStatsGrid({
    super.key,
    required this.stats,
    required this.isLoading,
  });

  final AdminDashboardStats? stats;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.55,
        children: List.generate(
          4,
          (i) => const LoadingSkeleton(
            width: double.infinity,
            height: double.infinity,
            borderRadius: 24,
          ),
        ),
      );
    }

    if (stats == null) return const SizedBox.shrink();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.55,
      children: [
        _StatCard(
          label: 'Drivers',
          value: stats!.activeDrivers.toString(),
          icon: LucideIcons.car,
          color: const Color(0xFF00C853),
        ),
        _StatCard(
          label: 'Active Trips',
          value: stats!.activeTrips.toString(),
          icon: LucideIcons.mapPin,
          color: const Color(0xFF2979FF),
        ),
        _StatCard(
          label: 'Total Users',
          value: stats!.totalUsers.toString(),
          icon: LucideIcons.users,
          color: const Color(0xFFFF9100),
        ),
        _StatCard(
          label: 'Completed',
          value: stats!.completedTrips.toString(),
          icon: LucideIcons.checkCircle,
          color: const Color(0xFF651FFF),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.labelSm.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.headlineMd.copyWith(
              height: 1,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }
}
