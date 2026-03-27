import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/constants/app_constants.dart';
import 'package:mobi_app/core/services/ride_request_service.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/vehicle_filter_chips.dart';

/// Driver card matching transito DriverCard exactly.
/// Chat action keeps WhatsApp's immediacy, but stays inside MOBI.
/// Request button allows passengers to send a ride request to the driver.
class DriverCard extends StatefulWidget {
  final Trip trip;
  final VoidCallback onChat;

  const DriverCard({super.key, required this.trip, required this.onChat});

  @override
  State<DriverCard> createState() => _DriverCardState();
}

class _DriverCardState extends State<DriverCard> {
  final _requestService = RideRequestService();
  bool _isRequesting = false;
  bool _hasRequested = false;

  Future<void> _sendRequest() async {
    if (_isRequesting || _hasRequested) return;
    setState(() => _isRequesting = true);

    try {
      await _requestService.sendRequest(
        responderId: widget.trip.authorId,
        tripId: widget.trip.id,
        metadata: {
          'vehicle_type': widget.trip.vehicleTypeStr,
          'source': 'nearby_drivers',
        },
      );
      if (mounted) {
        setState(() {
          _isRequesting = false;
          _hasRequested = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ride request sent!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _isRequesting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final driverId = AppConstants.getDriverId(widget.trip.authorId);
    final vType = widget.trip.effectiveVehicleType;
    final icon = getVehicleIcon(vType);

    return ClayCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
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
                              Icon(
                                icon,
                                size: 8,
                                color: cs.onSecondaryContainer,
                              ),
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
                        if (widget.trip.price != null)
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
                              widget.trip.price!.toUpperCase(),
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
            ],
          ),

          const SizedBox(height: 16),

          // Action row: Request + Chat
          Row(
            children: [
              // Request button
              Expanded(
                child: Material(
                  color: _hasRequested
                      ? cs.primaryContainer
                      : cs.primary,
                  borderRadius: BorderRadius.circular(16),
                  elevation: _hasRequested ? 0 : 3,
                  shadowColor: cs.primary.withValues(alpha: 0.3),
                  child: InkWell(
                    onTap: _hasRequested ? null : _sendRequest,
                    borderRadius: BorderRadius.circular(16),
                    splashColor: cs.onPrimary.withValues(alpha: 0.2),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isRequesting)
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.onPrimary,
                              ),
                            )
                          else
                            Icon(
                              _hasRequested
                                  ? LucideIcons.checkCircle
                                  : LucideIcons.send,
                              size: 16,
                              color: _hasRequested
                                  ? cs.primary
                                  : cs.onPrimary,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            _hasRequested ? 'REQUESTED' : 'REQUEST',
                            style: AppTypography.labelSm.copyWith(
                              letterSpacing: 1,
                              color: _hasRequested
                                  ? cs.primary
                                  : cs.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Chat button
              Semantics(
                button: true,
                label: 'Open in-app chat with $driverId',
                excludeSemantics: true,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Material(
                    color: ext.surfaceContainer,
                    shape: const CircleBorder(),
                    elevation: 2,
                    shadowColor: cs.shadow.withValues(alpha: 0.15),
                    child: InkWell(
                      onTap: widget.onChat,
                      customBorder: const CircleBorder(),
                      splashColor: cs.primary.withValues(alpha: 0.22),
                      child: Center(
                        child: Icon(
                          LucideIcons.messageCircle,
                          size: 22,
                          color: cs.primary,
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
    );
  }
}

