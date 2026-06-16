import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';

enum MobiStateBannerTone { neutral, brand, info, positive, warning, danger }

/// Compact inline banner for status, permission, and availability messaging.
///
/// Use this instead of custom one-off notice cards so the app keeps a single
/// pattern for lightweight inline guidance.
class MobiStateBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final MobiStateBannerTone tone;

  const MobiStateBanner({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.tone = MobiStateBannerTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final colors = switch (tone) {
      MobiStateBannerTone.brand => (
        accent: cs.primary,
        accentBackground: cs.primaryContainer,
      ),
      MobiStateBannerTone.info => (
        accent: ext.onInfoContainer,
        accentBackground: ext.infoContainer,
      ),
      MobiStateBannerTone.positive => (
        accent: cs.onTertiaryContainer,
        accentBackground: cs.tertiaryContainer,
      ),
      MobiStateBannerTone.warning => (
        accent: ext.onCautionContainer,
        accentBackground: ext.cautionContainer,
      ),
      MobiStateBannerTone.danger => (
        accent: cs.onErrorContainer,
        accentBackground: cs.errorContainer,
      ),
      MobiStateBannerTone.neutral => (
        accent: cs.onSurfaceVariant,
        accentBackground: ext.surfaceContainerHigh,
      ),
    };

    final resolvedTrailing =
        trailing ??
        (onTap != null
            ? Icon(Icons.chevron_right_rounded, size: 20, color: colors.accent)
            : null);
    final showSubtitle =
        tone == MobiStateBannerTone.danger &&
        subtitle?.trim().isNotEmpty == true;

    return ClayCard(
      onTap: onTap,
      semanticLabel: subtitle?.trim().isNotEmpty == true
          ? '$title. $subtitle'
          : title,
      borderRadius: AppRadii.xxl,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.accentBackground,
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Icon(icon, size: 18, color: colors.accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMd.copyWith(color: cs.onSurface),
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
          if (resolvedTrailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            resolvedTrailing,
          ],
        ],
      ),
    );
  }
}
