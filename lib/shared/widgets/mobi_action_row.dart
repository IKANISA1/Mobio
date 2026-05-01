import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

/// Data class for a single action in [MobiActionRow].
class MobiActionItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? accent;

  const MobiActionItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.accent,
  });
}

/// Compact horizontal row of 2–4 icon-led quick actions.
///
/// Replaces ad-hoc `Row(children: [MobiFeatureTile...])` patterns when
/// actions should feel lighter than full feature tiles.
class MobiActionRow extends StatelessWidget {
  final List<MobiActionItem> items;

  const MobiActionRow({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final accent = item.accent ?? cs.primary;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index < items.length - 1 ? AppSpacing.sm : 0,
            ),
            child: _MobiActionTile(
              icon: item.icon,
              label: item.label,
              accent: accent,
              onTap: item.onTap,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MobiActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback? onTap;

  const _MobiActionTile({
    required this.icon,
    required this.label,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: ext.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          splashColor: accent.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md,
              horizontal: AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Icon(icon, size: 20, color: accent),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.labelMd.copyWith(color: cs.onSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
