import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';

class MobiFeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? accent;
  final Color? accentBackground;
  final VoidCallback? onTap;
  final Widget? trailing;

  const MobiFeatureTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.accent,
    this.accentBackground,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resolvedAccent = accent ?? cs.primary;

    return ClayCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentBackground ?? resolvedAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Icon(icon, size: 22, color: resolvedAccent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMd.copyWith(color: cs.onSurface),
                ),
                if (subtitle != null) ...[
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
          trailing ??
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
        ],
      ),
    );
  }
}
