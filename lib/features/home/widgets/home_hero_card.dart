import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
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

    return Semantics(
      button: true,
      label: isDriver ? 'Nearby passengers' : 'Nearby drivers',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.hero),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              MobiStatusBadge(
                label: nearbyCount > 0 ? 'Live network' : 'Quiet network',
                icon: nearbyCount > 0 ? LucideIcons.radio : LucideIcons.moon,
                tone: nearbyCount > 0
                    ? MobiStatusBadgeTone.positive
                    : MobiStatusBadgeTone.neutral,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                isDriver ? 'Passengers nearby' : 'Drivers nearby',
                textAlign: TextAlign.center,
                style: AppTypography.displayLg.copyWith(
                  color: Colors.white,
                  fontSize: 40,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                nearbyCount.toString(),
                textAlign: TextAlign.center,
                style: AppTypography.heroNumber.copyWith(
                  color: Colors.white,
                  fontSize: 64,
                  height: 0.98,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isDriver ? 'Ready to pick up' : 'Ready to book',
                textAlign: TextAlign.center,
                style: AppTypography.bodyLg.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
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
        ),
      ),
    );
  }
}
