import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/constants/app_constants.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/vehicle_filter_chips.dart';

/// Driver card matching transito DriverCard exactly.
/// Chat action keeps WhatsApp's immediacy, but stays inside MOBI.
class DriverCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onChat;

  const DriverCard({super.key, required this.trip, required this.onChat});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final driverId = AppConstants.getDriverId(trip.authorId);
    final vType = trip.effectiveVehicleType;
    final icon = getVehicleIcon(vType);

    return ClayCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // Vehicle icon box
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: ext.surfaceContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 40, color: cs.primary),
          ),
          const SizedBox(width: 20),
          // Driver ID + badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driverId,
                  style: AppTypography.headlineMd.copyWith(
                    fontSize: 24,
                    letterSpacing: -0.5,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Vehicle type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 8, color: cs.onSecondaryContainer),
                          const SizedBox(width: 4),
                          Text(
                            vType.displayName,
                            style: AppTypography.badgeText.copyWith(
                              color: cs.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Distance badge
                    if (trip.price != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ext.surfaceContainer,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          trip.price!.toUpperCase(),
                          style: AppTypography.badgeText.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // In-app chat button — keeps the rounded high-contrast affordance.
          Semantics(
            button: true,
            label: 'Open in-app chat with $driverId',
            excludeSemantics: true,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Material(
                color: cs.primary,
                shape: const CircleBorder(),
                elevation: 4,
                shadowColor: cs.primary.withValues(alpha: 0.4),
                child: InkWell(
                  onTap: onChat,
                  customBorder: const CircleBorder(),
                  splashColor: cs.onPrimary.withValues(alpha: 0.22),
                  highlightColor: cs.onPrimary.withValues(alpha: 0.12),
                  child: Center(
                    child: Icon(
                      LucideIcons.messageCircle,
                      size: 22,
                      color: cs.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
