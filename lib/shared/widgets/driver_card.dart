import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/constants/app_constants.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_app/shared/widgets/vehicle_filter_chips.dart';

/// Discovery card for a nearby driver/passenger listing.
/// The active product scope allows profile browsing and communication only.
class DriverCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onChat;
  final VoidCallback? onTap;

  const DriverCard({
    super.key,
    required this.trip,
    required this.onChat,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final driverId = AppConstants.getDriverId(trip.authorId);
    final vType = trip.effectiveVehicleType;
    final icon = getVehicleIcon(vType);
    final distanceLabel = _distanceLabel(trip.description);

    return Hero(
      tag: 'trip_card_${trip.id ?? trip.hashCode}',
      child: Material(
        type: MaterialType.transparency,
        child: ClayCard(
          onTap: onTap,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [cs.primary, cs.tertiary],
                      ),
                    ),
                    child: Icon(icon, size: 24, color: Colors.white),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driverId,
                          style: AppTypography.titleLg.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            MobiStatusBadge(
                              label: vType.displayName,
                              icon: icon,
                              tone: MobiStatusBadgeTone.info,
                            ),
                            if (distanceLabel != null)
                              MobiStatusBadge(label: distanceLabel),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Open in-app chat with $driverId',
                    excludeSemantics: true,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Material(
                        color: ext.surfaceContainerHigh.withValues(alpha: 0.76),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: onChat,
                          customBorder: const CircleBorder(),
                          splashColor: cs.primary.withValues(alpha: 0.18),
                          child: const Center(
                            child: Icon(
                              LucideIcons.messageCircle,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
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

  String? _distanceLabel(String? value) {
    if (value == null) return null;
    final normalized = value.trim();
    if (!RegExp(
      r'^\d+(\.\d+)?\s+km away$',
      caseSensitive: false,
    ).hasMatch(normalized)) {
      return null;
    }
    return normalized.toUpperCase();
  }
}
