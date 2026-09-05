import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/shared/widgets/glass_container.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

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
      left: 16,
      right: 16,
      child: isAdmin
          ? _AdminNavContainer(child: navRow)
          : GlassCard(
              customBorderRadius: BorderRadius.circular(42),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: navRow,
            ),
    );
  }

  // Passenger nav: Home, Trips, BioPay, Profile
  static const _passengerItems = [
    _NavItem(LucideIcons.compass, 'Home'),
    _NavItem(LucideIcons.calendarCheck, 'Trips'),
    _NavItem(LucideIcons.scanFace, 'BioPay'),
    _NavItem(LucideIcons.user, 'Profile'),
  ];

  // Admin nav mirrors shell branch count.
  static const _adminItems = [
    _NavItem(LucideIcons.layoutDashboard, 'Ops'),
    _NavItem(LucideIcons.users, 'Users'),
    _NavItem(LucideIcons.scanFace, 'BioPay'),
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

/// One accessible navigation target for touch, keyboard and assistive input.
class _TappableNavItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: isActive,
      label: '$label tab',
      hint: isActive ? 'Current tab' : 'Switch tab',
      child: Tooltip(
        excludeFromSemantics: true,
        message: label,
        child: Material(
          color: isActive ? cs.surfaceContainerHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 22,
                        color: isActive ? cs.onSurface : cs.onSurfaceVariant,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: AppTypography.labelSm.copyWith(
                          color: isActive ? cs.onSurface : cs.onSurfaceVariant,
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
    );
  }
}
