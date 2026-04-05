import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';

class TripContextCard extends StatelessWidget {
  final Trip trip;

  const TripContextCard({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final timeLabel = trip.departureTime.isNotEmpty
        ? trip.departureTime
        : trip.time.isNotEmpty
        ? trip.time
        : 'Flexible';

    return ClayCard(
      borderRadius: 32,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRIP CONTEXT',
            style: AppTypography.labelSm.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Text(
            '${trip.origin.toUpperCase()} → ${trip.destination.toUpperCase()}',
            style: AppTypography.titleLg,
          ),
          const SizedBox(height: 8),
          Text(
            '${trip.departureDate.isEmpty ? 'Any day' : trip.departureDate} · $timeLabel',
            style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant),
          ),
          if (trip.note != null && trip.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(trip.note!.trim(), style: AppTypography.bodySm),
          ],
        ],
      ),
    );
  }
}
