import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';

class HomeHeroCard extends StatelessWidget {
  final bool isDriver;
  final int nearbyCount;
  final VoidCallback onTap;

  const HomeHeroCard({
    super.key,
    required this.isDriver,
    required this.nearbyCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Semantics(
      button: true,
      label: isDriver ? 'Passenger scheduled requests' : 'Nearby drivers',
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                isDriver ? 'Requests' : 'Drivers',
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
              const SizedBox(height: AppSpacing.lg),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ext.surfaceContainer.withValues(
                      alpha: ext.surfacePanelAlpha,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.xxl),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.primary.withValues(alpha: 0.16),
                          ),
                          child: Icon(
                            isDriver
                                ? LucideIcons.calendarSearch
                                : LucideIcons.car,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isDriver ? 'Passenger demand' : 'Driver supply',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.titleMd.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isDriver
                                    ? 'Scheduled requests near your routes'
                                    : 'Nearby drivers ready for pickup',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelMd.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        MobiStatusBadge(
                          label: nearbyCount > 0 ? 'Live' : 'Quiet',
                          tone: nearbyCount > 0
                              ? MobiStatusBadgeTone.positive
                              : MobiStatusBadgeTone.neutral,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
