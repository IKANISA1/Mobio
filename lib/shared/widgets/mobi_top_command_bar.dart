import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

class MobiTopCommandBarAction {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool showDot;

  const MobiTopCommandBarAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.showDot = false,
  });
}

class MobiTopCommandBar extends StatelessWidget {
  final String searchHint;
  final VoidCallback? onSearchTap;
  final Widget? avatar;
  final bool showNotificationDot;
  final bool showSearch;
  final List<MobiTopCommandBarAction> actions;

  const MobiTopCommandBar({
    super.key,
    this.searchHint = 'Search',
    this.onSearchTap,
    this.avatar,
    this.showNotificationDot = false,
    this.showSearch = true,
    this.actions = const [
      MobiTopCommandBarAction(icon: LucideIcons.barChart3, label: 'Activity'),
      MobiTopCommandBarAction(icon: LucideIcons.creditCard, label: 'Account'),
    ],
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final visibleActions = actions.take(2).toList();

    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox.square(
              dimension: 48,
              child:
                  avatar ??
                  ClipOval(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: ext.surfaceContainerHigh,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: Image.asset(
                          'icon/mobi_logo_transparent.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
            ),
            if (showNotificationDot)
              Positioned(
                right: 0,
                top: -2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.error,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ext.backgroundGradientTop.withValues(alpha: 0.7),
                      width: 2,
                    ),
                  ),
                  child: const SizedBox.square(dimension: 11),
                ),
              ),
          ],
        ),
        if (showSearch) ...[
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Semantics(
              button: true,
              label: searchHint,
              child: Material(
                color: Colors.black.withValues(alpha: ext.blackChromeAlpha),
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  onTap: onSearchTap,
                  borderRadius: BorderRadius.circular(999),
                  splashColor: Colors.white.withValues(
                    alpha: ext.pressedWhiteAlpha,
                  ),
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: ext.surfacePanelBorderAlpha,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.search,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            searchHint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyLg.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        if (showSearch || visibleActions.isNotEmpty)
          const SizedBox(width: AppSpacing.sm),
        if (!showSearch && visibleActions.isNotEmpty) const Spacer(),
        for (final action in visibleActions) ...[
          _CommandCircle(action: action),
          if (action != visibleActions.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _CommandCircle extends StatelessWidget {
  final MobiTopCommandBarAction action;

  const _CommandCircle({required this.action});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    final cs = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: action.label,
      child: Tooltip(
        message: action.label,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox.square(
              dimension: 52,
              child: Material(
                color: Colors.black.withValues(alpha: ext.blackChromeAlpha),
                shape: CircleBorder(
                  side: BorderSide(
                    color: Colors.white.withValues(
                      alpha: ext.surfacePanelBorderAlpha,
                    ),
                  ),
                ),
                child: InkWell(
                  onTap: action.onTap,
                  customBorder: const CircleBorder(),
                  splashColor: Colors.white.withValues(
                    alpha: ext.pressedWhiteAlpha,
                  ),
                  child: Center(
                    child: Icon(action.icon, color: Colors.white, size: 23),
                  ),
                ),
              ),
            ),
            if (action.showDot)
              Positioned(
                right: 2,
                top: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.error,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ext.backgroundGradientTop.withValues(alpha: 0.7),
                      width: 2,
                    ),
                  ),
                  child: const SizedBox.square(dimension: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
