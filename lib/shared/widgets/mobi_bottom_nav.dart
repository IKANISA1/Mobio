import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

import 'package:mobi_app/shared/widgets/glass_container.dart';

/// Floating bottom navigation bar.
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
              customBorderRadius: BorderRadius.circular(42),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ext.surfaceContainerLowest.withValues(alpha: ext.navChromeAlpha),
        borderRadius: BorderRadius.circular(42),
        border: Border.all(
          color: Colors.white.withValues(alpha: ext.cardBorderAlpha),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: ext.surfacePanelShadowAlpha),
            blurRadius: 30,
            spreadRadius: -12,
            offset: const Offset(0, 16),
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
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isActive
                        ? ext.surfaceContainerHigh.withValues(alpha: 0.84)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: ExcludeSemantics(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.icon,
                          size: 22,
                          color: widget.isActive
                              ? Colors.white
                              : cs.onSurfaceVariant,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          textAlign: TextAlign.center,
                          style: AppTypography.labelSm.copyWith(
                            fontWeight: widget.isActive
                                ? FontWeight.w800
                                : FontWeight.w600,
                            letterSpacing: 0,
                            color: widget.isActive
                                ? Colors.white
                                : cs.onSurfaceVariant,
                          ),
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
