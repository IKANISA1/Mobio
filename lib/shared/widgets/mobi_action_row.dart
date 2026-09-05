import 'package:flutter/material.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

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

/// Compact horizontal row of circular icon-led quick actions.
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
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: accent.withValues(alpha: 0.14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: ext.surfaceContainerHigh.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 23,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTypography.labelMd.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
