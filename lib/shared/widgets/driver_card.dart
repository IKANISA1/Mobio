import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/core/constants/app_constants.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/vehicle_filter_chips.dart';
import 'package:mobi_app/shared/widgets/whatsapp_icon.dart';

/// Driver card matching transito DriverCard exactly.
/// WhatsApp button now uses Material ripple for instant feedback.
class DriverCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onWhatsApp;

  const DriverCard({
    super.key,
    required this.trip,
    required this.onWhatsApp,
  });

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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
          // WhatsApp button — Material ripple for instant feedback
          SizedBox(
            width: 48,
            height: 48,
            child: Material(
              color: cs.primary,
              shape: const CircleBorder(),
              elevation: 4,
              shadowColor: cs.primary.withValues(alpha: 0.4),
              child: InkWell(
                onTap: onWhatsApp,
                customBorder: const CircleBorder(),
                splashColor: Colors.white.withValues(alpha: 0.3),
                highlightColor: Colors.white.withValues(alpha: 0.15),
                child: const Center(
                  child: WhatsAppIcon(size: 24, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
