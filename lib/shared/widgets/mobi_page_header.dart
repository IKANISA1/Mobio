import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/shared/widgets/mobi_surface_panel.dart';
import 'package:mobi_app/shared/widgets/tappable_icon_button.dart';

/// Compact page header for pushed screens (not tab shells).
///
/// Shows a back button + title + optional trailing badge/action.
/// Used consistently across NearbyScreen, TripDetailsScreen,
/// EditProfileScreen, ChatScreen, and admin screens.
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
    final cs = Theme.of(context).colorScheme;
    final showSubtitle = subtitle != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.md,
        AppSpacing.screenPadding,
        0,
      ),
      child: MobiSurfacePanel(
        padding: const EdgeInsets.all(AppSpacing.lg),
        borderRadius: AppRadii.hero,
        child: Row(
          children: [
            if (showBackButton) ...[
              TappableIconButton(
                icon: LucideIcons.chevronLeft,
                onTap: onBack ?? () => Navigator.maybePop(context),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleLg.copyWith(color: cs.primary),
                  ),
                  if (showSubtitle) ...[const SizedBox(height: 2), subtitle!],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
