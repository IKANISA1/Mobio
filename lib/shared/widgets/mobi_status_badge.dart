import 'package:flutter/material.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

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
        bg: cs.tertiaryContainer,
        fg: cs.onTertiaryContainer,
      ),
      MobiStatusBadgeTone.info => (
        bg: ext.infoContainer,
        fg: ext.onInfoContainer,
      ),
      MobiStatusBadgeTone.warning => (
        bg: ext.cautionContainer,
        fg: ext.onCautionContainer,
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
          Flexible(
            child: Text(
              label,
              style: AppTypography.labelMd.copyWith(
                color: colors.fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
