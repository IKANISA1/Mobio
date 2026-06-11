import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/constants/app_constants.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_app/shared/widgets/vehicle_filter_chips.dart';

class ScheduledTripCard extends StatelessWidget {
  final Trip trip;

  const ScheduledTripCard({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = getVehicleIconFromId(trip.vehicleTypeStr);

    return ClayCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderRadius: AppRadii.hero,
      child: Row(
        children: [
          SizedBox.square(
            dimension: 58,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [cs.primary, cs.secondary],
                ),
              ),
              child: Icon(icon, size: 25, color: Colors.white),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trip.origin} → ${trip.destination}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMd.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  trip.departureTime,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const MobiStatusBadge(
                label: 'Upcoming',
                tone: MobiStatusBadgeTone.positive,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                trip.authorId.isNotEmpty
                    ? AppConstants.getDriverId(trip.authorId)
                    : trip.vehicleTypeStr.toUpperCase(),
                style: AppTypography.labelMd.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(LucideIcons.chevronRight, size: 18),
        ],
      ),
    );
  }
}
