import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

enum MobiStatusBadgeTone { neutral, brand, positive, info, warning, danger }

class MobiStatusBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final MobiStatusBadgeTone tone;

  const MobiStatusBadge({
    super.key,
    required this.label,
    this.icon,
    this.tone = MobiStatusBadgeTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final colors = switch (tone) {
      MobiStatusBadgeTone.brand => (
        bg: cs.primaryContainer,
        fg: cs.onPrimaryContainer,
      ),
      MobiStatusBadgeTone.positive => (
        bg: cs.primary.withValues(alpha: 0.12),
        fg: cs.primary,
      ),
      MobiStatusBadgeTone.info => (
        bg: cs.secondaryContainer,
        fg: cs.onSecondaryContainer,
      ),
      MobiStatusBadgeTone.warning => (
        bg: Colors.amber.withValues(alpha: 0.14),
        fg: Colors.amber.shade800,
      ),
      MobiStatusBadgeTone.danger => (
        bg: cs.errorContainer,
        fg: cs.onErrorContainer,
      ),
      MobiStatusBadgeTone.neutral => (
        bg: ext.surfaceContainerHighest,
        fg: cs.onSurfaceVariant,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: colors.fg),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTypography.labelMd.copyWith(
              color: colors.fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
