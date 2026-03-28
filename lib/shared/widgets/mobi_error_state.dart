import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';

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

    return SizedBox(
      height: containerHeight,
      child: ClayCard(
        borderRadius: 40,
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
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: cs.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, size: 28, color: cs.error),
                ),
                const SizedBox(height: 16),

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
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMd.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],

                // Retry button
                if (onRetry != null) ...[
                  const SizedBox(height: 20),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onRetry,
                      borderRadius: BorderRadius.circular(999),
                      splashColor: cs.error.withValues(alpha: 0.12),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: cs.errorContainer,
                          borderRadius: BorderRadius.circular(999),
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
    );
  }
}
