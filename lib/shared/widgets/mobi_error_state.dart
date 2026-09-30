import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/shared/widgets/mobi_tonal_card.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

/// Reusable error state widget with retry action.
///
/// Matches the visual language of [AiEmptyState] but is semantically
/// distinct — always shows an error icon + retry CTA.
class MobiErrorState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryLabel;
  final double? height;

  const MobiErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.subtitle,
    this.icon = LucideIcons.alertTriangle,
    this.onRetry,
    this.retryLabel = 'Try Again',
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final containerHeight = height ?? 240;

    return Semantics(
      container: true,
      liveRegion: true,
      label: subtitle == null ? title : '$title. $subtitle',
      child: SizedBox(
        height: containerHeight,
        child: MobiTonalCard(
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
                  // Error icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                    ),
                    child: Icon(icon, size: 24, color: cs.error),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Title
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTypography.titleLg.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  // Subtitle
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

                  // Retry button
                  if (onRetry != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onRetry,
                        borderRadius: BorderRadius.circular(999),
                        splashColor: cs.error.withValues(alpha: 0.12),
                        child: Ink(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: cs.errorContainer,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            border: Border.all(
                              color: cs.error.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            retryLabel,
                            style: AppTypography.labelLg.copyWith(
                              color: cs.onErrorContainer,
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
