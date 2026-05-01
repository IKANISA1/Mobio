import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

/// Tiny read-only metadata chip for inline micro-context.
///
/// Smaller and lighter than [MobiStatusBadge] — designed for inline
/// metadata such as "3 stops", "est. 25 min", departure date pills.
/// Optionally tappable for date-pill filter behavior.
class MobiInfoChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isSelected;

  const MobiInfoChip({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    final bgColor = isSelected
        ? cs.primaryContainer
        : ext.surfaceContainerHigh;
    final fgColor = isSelected
        ? cs.onPrimaryContainer
        : cs.onSurfaceVariant;

    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: isSelected
            ? Border.all(color: cs.primary.withValues(alpha: 0.2))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fgColor),
            const SizedBox(width: AppSpacing.xxs + 1),
          ],
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: fgColor,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;

    return GestureDetector(
      onTap: onTap,
      child: chip,
    );
  }
}
