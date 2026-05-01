import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/constants/app_constants.dart';
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
    return ClayCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${trip.origin.toUpperCase()} → ${trip.destination.toUpperCase()}',
                      style: AppTypography.titleMd.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      trip.departureTime,
                      style: AppTypography.headlineLg.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, size: 18),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (trip.authorId.isNotEmpty)
                MobiStatusBadge(
                  label: AppConstants.getDriverId(trip.authorId),
                  tone: MobiStatusBadgeTone.brand,
                ),
              MobiStatusBadge(
                label: trip.vehicleTypeStr.toUpperCase(),
                icon: getVehicleIconFromId(trip.vehicleTypeStr),
                tone: MobiStatusBadgeTone.info,
              ),
              const MobiStatusBadge(
                label: 'Upcoming',
                tone: MobiStatusBadgeTone.positive,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
