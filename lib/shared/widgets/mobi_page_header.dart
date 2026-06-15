import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/shared/widgets/tappable_icon_button.dart';

/// Reference-style pushed-page header.
class MobiPageHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Widget? subtitle;
  final bool showBackButton;

  const MobiPageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.subtitle,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final showSubtitle = subtitle != null;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.md,
        AppSpacing.screenPadding,
        0,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            if (showBackButton) ...[
              TappableIconButton(
                icon: LucideIcons.chevronLeft,
                semanticLabel: 'Back',
                onTap: onBack ?? () => Navigator.maybePop(context),
                backgroundColor: Colors.black.withValues(
                  alpha: ext.blackChromeAlpha,
                ),
                iconColor: Colors.white,
                borderRadius: AppRadii.pill,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headlineLg.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    if (showSubtitle) ...[const SizedBox(height: 4), subtitle!],
                  ],
                ),
              ),
            ),
            if (trailing != null)
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: trailing!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
