import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';

class MobiMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? accent;
  final VoidCallback? onTap;

  const MobiMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resolvedAccent = accent ?? cs.primary;

    return ClayCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderRadius: AppRadii.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) Icon(icon, size: 18, color: resolvedAccent),
          if (icon != null) const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headlineLg.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
