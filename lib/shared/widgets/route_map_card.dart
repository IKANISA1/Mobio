import 'package:flutter/material.dart';

import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/route_info.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';

/// Displays a compact route summary card.
/// The mobile app does not support embedded maps, so this widget intentionally
/// renders a non-map preview of the route and travel metrics.
class RouteMapCard extends StatelessWidget {
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
  final String? originLabel;
  final String? destLabel;
  final RouteInfo? routeInfo;
  final double height;

  const RouteMapCard({
    super.key,
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    this.originLabel,
    this.destLabel,
    this.routeInfo,
    this.height = 200,
  });

  String _formatDistance(int meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '$meters m';
  }

  String _formatDuration(String duration) {
    // Duration comes as "1234s" (seconds)
    final seconds = int.tryParse(duration.replaceAll('s', '')) ?? 0;
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainMinutes = minutes % 60;
    return '${hours}h ${remainMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final routeInfo = this.routeInfo;

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
                colors: [
                  ext.surfaceContainerHighest,
                  ext.surfaceContainerLow,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ROUTE SUMMARY',
                  style: AppTypography.labelSm.copyWith(
                    color: cs.primary,
                  ),
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
                  'Embedded maps are disabled in this build.',
                  style: AppTypography.labelSm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _infoBadge(
                context,
                routeInfo != null
                    ? _formatDistance(routeInfo.distanceMeters)
                    : 'Distance unavailable',
                cs.primaryContainer,
                cs.primary,
              ),
              _infoBadge(
                context,
                routeInfo != null
                    ? _formatDuration(routeInfo.duration)
                    : 'Time unavailable',
                cs.secondaryContainer,
                cs.onSecondaryContainer,
              ),
              _infoBadge(
                context,
                routeInfo?.travelMode ?? 'Preview only',
                ext.surfaceContainer,
                cs.onSurfaceVariant,
              ),
            ],
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
                style: AppTypography.titleMd.copyWith(
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoBadge(BuildContext context, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: AppTypography.labelSm.copyWith(
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
