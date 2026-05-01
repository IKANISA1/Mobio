import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/mobi_metric_tile.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';

class HomeHeroCard extends StatelessWidget {
  final bool isDriver;
  final int nearbyCount;
  final int unreadCount;
  final int scheduledCount;
  final VoidCallback onTap;

  const HomeHeroCard({
    super.key,
    required this.isDriver,
    required this.nearbyCount,
    required this.unreadCount,
    required this.scheduledCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClayCard(
      onTap: onTap,
      color: cs.primaryContainer.withValues(alpha: 0.92),
      borderRadius: AppRadii.hero,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isDriver ? 'Nearby passengers' : 'Nearby drivers',
                  style: AppTypography.titleLg.copyWith(
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              MobiStatusBadge(
                label: nearbyCount > 0 ? 'Live' : 'Quiet',
                icon: LucideIcons.sparkles,
                tone: nearbyCount > 0
                    ? MobiStatusBadgeTone.positive
                    : MobiStatusBadgeTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            nearbyCount.toString(),
            style: AppTypography.heroNumber.copyWith(
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isDriver ? 'Ready to pick up' : 'Ready to book',
            style: AppTypography.bodySm.copyWith(
              color: cs.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: MobiMetricTile(
                  label: 'Unread',
                  value: '$unreadCount',
                  icon: LucideIcons.bell,
                  accent: cs.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: MobiMetricTile(
                  label: 'Scheduled',
                  value: '$scheduledCount',
                  icon: LucideIcons.calendarClock,
                  accent: cs.tertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
