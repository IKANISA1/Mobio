import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';

class MobiFeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? accent;
  final Color? accentBackground;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Optional badge widget shown between title text and trailing chevron.
  /// Use for notification counts, status indicators, etc.
  final Widget? badge;

  /// When `true`, uses smaller padding and icon container for
  /// settings-density lists.
  final bool compact;

  const MobiFeatureTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.accent,
    this.accentBackground,
    this.onTap,
    this.trailing,
    this.badge,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resolvedAccent = accent ?? cs.primary;
    final showSubtitle = subtitle?.trim().isNotEmpty == true;
    final isDense = compact || !showSubtitle;
    final resolvedTrailing =
        trailing ??
        (onTap != null
            ? Icon(
                LucideIcons.chevronRight,
                size: isDense ? 16.0 : 18.0,
                color: cs.onSurfaceVariant,
              )
            : null);

    final iconSize = isDense ? 18.0 : 22.0;
    final containerSize = isDense ? 40.0 : 48.0;
    final tilePadding = isDense
        ? const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          )
        : const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          );

    return ClayCard(
      onTap: onTap,
      padding: tilePadding,
      child: Row(
        children: [
          Container(
            width: containerSize,
            height: containerSize,
            decoration: BoxDecoration(
              color: accentBackground ?? resolvedAccent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: accentBackground == null ? cs.onSurface : resolvedAccent,
            ),
          ),
          SizedBox(width: isDense ? AppSpacing.sm : AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (compact ? AppTypography.bodySm : AppTypography.titleMd)
                          .copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                ),
                if (showSubtitle) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySm.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (badge != null) ...[const SizedBox(width: AppSpacing.xs), badge!],
          if (resolvedTrailing != null) ...[
            const SizedBox(width: AppSpacing.xs),
            resolvedTrailing,
          ],
        ],
      ),
    );
  }
}
