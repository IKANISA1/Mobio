import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/constants/app_constants.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/ride_request_service.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_app/shared/widgets/vehicle_filter_chips.dart';

/// Driver card matching transito DriverCard exactly.
/// Chat action keeps WhatsApp's immediacy, but stays inside MOBI.
/// Request button allows passengers to send a ride request to the driver.
class DriverCard extends ConsumerStatefulWidget {
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
  ConsumerState<DriverCard> createState() => _DriverCardState();
}

class _DriverCardState extends ConsumerState<DriverCard> {
  RideRequestService get requestService => ref.read(rideRequestServiceProvider);

  bool _isRequesting = false;
  bool _hasRequested = false;

  Future<void> _sendRequest() async {
    if (_isRequesting || _hasRequested) return;
    setState(() => _isRequesting = true);

    try {
      await ref
          .read(rideRequestServiceProvider)
          .sendRequest(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
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

    return Hero(
      tag: 'trip_card_${widget.trip.id ?? widget.trip.hashCode}',
      child: Material(
        type: MaterialType.transparency,
        child: ClayCard(
          onTap: widget.onTap,
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
                      color: ext.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                    ),
                    child: Icon(icon, size: 24, color: cs.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driverId,
                          style: AppTypography.titleLg.copyWith(
                            color: cs.onSurface,
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
                            if (widget.trip.price != null)
                              MobiStatusBadge(
                                label: widget.trip.price!.toUpperCase(),
                              ),
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
                        color: ext.surfaceContainer,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: widget.onChat,
                          customBorder: const CircleBorder(),
                          splashColor: cs.primary.withValues(alpha: 0.18),
                          child: Center(
                            child: Icon(
                              LucideIcons.messageCircle,
                              size: 20,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Material(
                color: _hasRequested ? cs.primaryContainer : cs.primary,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                child: InkWell(
                  onTap: _hasRequested ? null : _sendRequest,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  splashColor: cs.onPrimary.withValues(alpha: 0.16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                      horizontal: AppSpacing.lg,
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
                            color: _hasRequested ? cs.primary : cs.onPrimary,
                          ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          _hasRequested ? 'Requested' : 'Request',
                          style: AppTypography.labelLg.copyWith(
                            color: _hasRequested ? cs.primary : cs.onPrimary,
                          ),
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
