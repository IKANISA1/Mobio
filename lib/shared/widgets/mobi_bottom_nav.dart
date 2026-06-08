import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

import 'package:mobi_app/shared/widgets/glass_container.dart';

/// Bottom navigation bar — 3-tab design: Discover / Trips / Profile.
/// Matches the transito UI with frosted glass background,
/// active tab pill (green circle + label), and animated transitions.
/// Each tab now provides opacity + scale feedback on press.
class MobiBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isAdmin;

  const MobiBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = isAdmin ? _adminItems : _passengerItems;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final navRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(items.length, (index) {
        final item = items[index];
        final isActive = currentIndex == index;
        return Expanded(
          child: _TappableNavItem(
            onTap: () => onTap(index),
            isActive: isActive,
            icon: item.icon,
            label: item.label,
            isAdmin: isAdmin,
          ),
        );
      }),
    );

    return Positioned(
      bottom: 12 + safeBottom,
      left: 20,
      right: 20,
      child: isAdmin
          ? _AdminNavContainer(child: navRow)
          : GlassCard(
              customBorderRadius: BorderRadius.circular(AppRadii.hero),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: navRow,
            ),
    );
  }

  // 3-tab passenger nav: Home, Trips, Profile
  static const _passengerItems = [
    _NavItem(LucideIcons.compass, 'Home'),
    _NavItem(LucideIcons.calendarCheck, 'Trips'),
    _NavItem(LucideIcons.user, 'Profile'),
  ];

  // Admin nav: Dashboard, Users, Profile
  static const _adminItems = [
    _NavItem(LucideIcons.layoutDashboard, 'Ops'),
    _NavItem(LucideIcons.users, 'Users'),
    _NavItem(LucideIcons.user, 'Account'),
  ];
}

class _AdminNavContainer extends StatelessWidget {
  final Widget child;

  const _AdminNavContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ext.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.hero),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 28,
            spreadRadius: -22,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: child,
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

/// Nav item with opacity + scale press feedback.
class _TappableNavItem extends StatefulWidget {
  final VoidCallback onTap;
  final bool isActive;
  final IconData icon;
  final String label;
  final bool isAdmin;

  const _TappableNavItem({
    required this.onTap,
    required this.isActive,
    required this.icon,
    required this.label,
    this.isAdmin = false,
  });

  @override
  State<_TappableNavItem> createState() => _TappableNavItemState();
}

class _TappableNavItemState extends State<_TappableNavItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final fastDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 100);
    final settleDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return Semantics(
      button: true,
      selected: widget.isActive,
      label: '${widget.label} tab',
      hint: widget.isActive ? 'Current tab' : 'Switch tab',
      onTap: widget.onTap,
      child: Tooltip(
        message: widget.label,
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
            child: AnimatedOpacity(
              duration: fastDuration,
              opacity: _isPressed ? 0.7 : 1.0,
              child: AnimatedScale(
                duration: fastDuration,
                scale: reduceMotion || !_isPressed ? 1.0 : 0.95,
                child: AnimatedContainer(
                  duration: settleDuration,
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.isActive ? 12 : 0,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isActive
                        ? cs.primary.withValues(
                            alpha: widget.isAdmin ? 0.1 : 0.14,
                          )
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.icon,
                          size: 20,
                          color: widget.isActive
                              ? cs.primary
                              : cs.onSurfaceVariant,
                        ),
                        AnimatedSize(
                          duration: settleDuration,
                          curve: Curves.easeOutCubic,
                          child: widget.isActive
                              ? Row(
                                  children: [
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                      textAlign: TextAlign.center,
                                      style: AppTypography.labelSm.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0,
                                        color: cs.primary,
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
