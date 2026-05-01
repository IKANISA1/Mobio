import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';

/// Foreground-only empty state card.
///
/// Screen promo media is rendered by [SoftGradient]. This widget intentionally
/// stays media-free so each screen has a single background layer.
class AiEmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final double? height;
  final VoidCallback? onAction;
  final String? actionLabel;

  const AiEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.height,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final containerHeight = height ?? 260;

    return Semantics(
      container: true,
      label: subtitle == null ? title : '$title. $subtitle',
      child: SizedBox(
        height: containerHeight,
        child: ClayCard(
          borderRadius: AppRadii.hero,
          color: ext.surfaceContainerLowest.withValues(
            alpha: ext.surfacePanelAlpha,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(AppRadii.xl),
                      ),
                      child: Icon(icon, size: 24, color: cs.primary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTypography.titleLg.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySm.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (onAction != null && actionLabel != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onAction,
                        borderRadius: BorderRadius.circular(999),
                        splashColor: cs.primary.withValues(alpha: 0.14),
                        child: Ink(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            border: Border.all(
                              color: cs.primary.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Text(
                            actionLabel!,
                            style: AppTypography.labelLg.copyWith(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
