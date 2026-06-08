import 'package:flutter/material.dart';

import 'package:mobi_app/core/services/google_maps_deep_link_service.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';

/// Displays a compact trip-location summary card.
/// The mobile app does not support embedded maps, so this widget intentionally
/// renders a non-map preview and opens Google Maps through a deep link.
class RouteMapCard extends StatelessWidget {
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
  final String? originLabel;
  final String? destLabel;
  final double height;

  const RouteMapCard({
    super.key,
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    this.originLabel,
    this.destLabel,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return ClayCard(
      padding: const EdgeInsets.all(24),
      borderRadius: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: height),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ext.surfaceContainerHighest, ext.surfaceContainerLow],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TRIP POST LOCATIONS',
                  style: AppTypography.labelSm.copyWith(color: cs.primary),
                ),
                const SizedBox(height: 18),
                _routeStop(
                  context: context,
                  icon: Icons.radio_button_checked,
                  label: 'FROM',
                  value: originLabel ?? 'Origin',
                  iconColor: cs.primary,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 11),
                  child: Container(
                    width: 2,
                    height: 28,
                    color: cs.outlineVariant,
                  ),
                ),
                _routeStop(
                  context: context,
                  icon: Icons.location_on,
                  label: 'TO',
                  value: destLabel ?? 'Destination',
                  iconColor: cs.error,
                ),
                const SizedBox(height: 18),
                Text(
                  'Open the route in Google Maps. Live bus tracking depends on a driver app or approved GPS device feed.',
                  style: AppTypography.labelSm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openGoogleMaps(context),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Open in Google Maps'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeStop({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 22, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.labelSm.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleMd.copyWith(color: cs.onSurface),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openGoogleMaps(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final opened = await GoogleMapsDeepLinkService.openRoute(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
    );

    if (!opened) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Unable to open Google Maps.')),
      );
    }
  }
}
