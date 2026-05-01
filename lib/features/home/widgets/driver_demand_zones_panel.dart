import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/services/driver_location_service.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_app/shared/widgets/mobi_surface_panel.dart';

class DriverDemandZonesPanel extends StatelessWidget {
  const DriverDemandZonesPanel({
    super.key,
    required this.zones,
    required this.isLoading,
    required this.onRefresh,
  });

  final List<DriverDemandZone> zones;
  final bool isLoading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final topSignal = zones.isEmpty ? null : zones.first;

    return MobiSurfacePanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderRadius: AppRadii.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Icon(LucideIcons.radar, color: cs.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Passenger probability',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleLg.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      topSignal == null
                          ? 'Live demand signals'
                          : 'Top signal: ${topSignal.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySm.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'Refresh demand zones',
                child: IconButton(
                  onPressed: isLoading ? null : onRefresh,
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (isLoading)
            const LoadingSkeleton(height: 212, borderRadius: AppRadii.xxl)
          else if (zones.isEmpty)
            _DemandZonesEmpty(onRefresh: onRefresh)
          else ...[
            SizedBox(
              height: 172,
              width: double.infinity,
              child: _DemandZoneMap(zones: zones),
            ),
            const SizedBox(height: AppSpacing.md),
            ...zones
                .take(3)
                .indexed
                .map(
                  (entry) => Padding(
                    padding: EdgeInsets.only(
                      bottom: entry.$1 == math.min(zones.length, 3) - 1
                          ? 0
                          : AppSpacing.sm,
                    ),
                    child: _DemandZoneRow(rank: entry.$1 + 1, zone: entry.$2),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _DemandZonesEmpty extends StatelessWidget {
  const _DemandZonesEmpty({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.mapPin, color: cs.primary),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No active demand signals',
            textAlign: TextAlign.center,
            style: AppTypography.titleMd.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Signals appear from scheduled passenger trips and active events.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onRefresh,
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class _DemandZoneMap extends StatelessWidget {
  const _DemandZoneMap({required this.zones});

  final List<DriverDemandZone> zones;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.xxl),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.52),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DemandZonePainter(
                  zones: zones,
                  primary: cs.primary,
                  secondary: cs.tertiary,
                  grid: cs.outlineVariant,
                ),
              ),
            ),
            Positioned(
              right: AppSpacing.sm,
              top: AppSpacing.sm,
              child: MobiStatusBadge(
                label: '${zones.length} signals',
                icon: LucideIcons.activity,
                tone: MobiStatusBadgeTone.info,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemandZoneRow extends StatelessWidget {
  const _DemandZoneRow({required this.rank, required this.zone});

  final int rank;
  final DriverDemandZone zone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final probability = (zone.probability.clamp(0, 1) * 100).round();
    final timeLabel = _formatStartsAt(zone.startsAt);

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Text(
            '$rank',
            style: AppTypography.labelMd.copyWith(color: cs.onPrimaryContainer),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                zone.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleMd.copyWith(color: cs.onSurface),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                [
                  _sourceLabel(zone.source),
                  ?timeLabel,
                  if (zone.reason.isNotEmpty) zone.reason,
                ].join(' / '),
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
        MobiStatusBadge(
          label: '$probability%',
          icon: LucideIcons.trendingUp,
          tone: probability >= 70
              ? MobiStatusBadgeTone.positive
              : MobiStatusBadgeTone.warning,
        ),
      ],
    );
  }

  String _sourceLabel(String source) {
    return switch (source) {
      'scheduled_trips' => 'Trips',
      'events' => 'Event',
      _ => source.isEmpty ? 'Signal' : source,
    };
  }

  String? _formatStartsAt(String? value) {
    if (value == null || value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return DateFormat('EEE HH:mm').format(parsed.toLocal());
  }
}

class _DemandZonePainter extends CustomPainter {
  const _DemandZonePainter({
    required this.zones,
    required this.primary,
    required this.secondary,
    required this.grid,
  });

  final List<DriverDemandZone> zones;
  final Color primary;
  final Color secondary;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.24)
      ..strokeWidth = 1;

    for (var i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      final y = size.height * i / 4;
      canvas
        ..drawLine(Offset(x, 0), Offset(x, size.height), gridPaint)
        ..drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (zones.isEmpty) return;

    final bounds = _DemandBounds.fromZones(zones);
    final ordered = zones.toList()
      ..sort((a, b) => a.probability.compareTo(b.probability));

    for (final zone in ordered) {
      final probability = zone.probability.clamp(0, 1).toDouble();
      final point = bounds.project(zone, size);
      final color = Color.lerp(secondary, primary, probability) ?? primary;
      final radius = 18 + probability * 26;

      canvas
        ..drawCircle(
          point,
          radius,
          Paint()..color = color.withValues(alpha: 0.16),
        )
        ..drawCircle(
          point,
          radius * 0.56,
          Paint()..color = color.withValues(alpha: 0.22),
        )
        ..drawCircle(point, 5 + probability * 5, Paint()..color = color);
    }

    final top = zones.reduce(
      (best, next) => next.probability > best.probability ? next : best,
    );
    final topPoint = bounds.project(top, size);
    canvas.drawCircle(
      topPoint,
      15,
      Paint()
        ..color = primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
  }

  @override
  bool shouldRepaint(covariant _DemandZonePainter oldDelegate) {
    return oldDelegate.zones != zones ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.grid != grid;
  }
}

class _DemandBounds {
  const _DemandBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  factory _DemandBounds.fromZones(List<DriverDemandZone> zones) {
    var minLat = zones.first.latitude;
    var maxLat = zones.first.latitude;
    var minLng = zones.first.longitude;
    var maxLng = zones.first.longitude;

    for (final zone in zones.skip(1)) {
      minLat = math.min(minLat, zone.latitude);
      maxLat = math.max(maxLat, zone.latitude);
      minLng = math.min(minLng, zone.longitude);
      maxLng = math.max(maxLng, zone.longitude);
    }

    const minSpan = 0.01;
    if ((maxLat - minLat).abs() < minSpan) {
      final center = (maxLat + minLat) / 2;
      minLat = center - minSpan / 2;
      maxLat = center + minSpan / 2;
    }
    if ((maxLng - minLng).abs() < minSpan) {
      final center = (maxLng + minLng) / 2;
      minLng = center - minSpan / 2;
      maxLng = center + minSpan / 2;
    }

    return _DemandBounds(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
    );
  }

  Offset project(DriverDemandZone zone, Size size) {
    final x = ((zone.longitude - minLng) / (maxLng - minLng)).clamp(0, 1);
    final y = (1 - (zone.latitude - minLat) / (maxLat - minLat)).clamp(0, 1);
    const inset = 24.0;

    return Offset(
      inset + x * math.max(0, size.width - inset * 2),
      inset + y * math.max(0, size.height - inset * 2),
    );
  }
}
