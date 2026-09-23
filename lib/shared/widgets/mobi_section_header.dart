import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';

class MobiSectionHeader extends StatelessWidget {
  final String title;
  final String? caption;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MobiSectionHeader({
    super.key,
    required this.title,
    this.caption,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showCaption = caption?.trim().isNotEmpty == true;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: AppTypography.titleLg.copyWith(color: cs.onSurface),
                ),
              ),
              if (showCaption) ...[
                const SizedBox(height: 2),
                Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onAction != null)
          TextButton.icon(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: cs.onSurface,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
            icon: const Icon(LucideIcons.chevronRight, size: 16),
            label: Text(actionLabel ?? 'More', style: AppTypography.labelLg),
          ),
      ],
    );
  }
}
