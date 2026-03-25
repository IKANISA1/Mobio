import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobi_app/shared/widgets/glass_container.dart';

/// Bottom navigation bar — 3-tab design: Discover / BioPay / Profile.
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

    return Positioned(
      bottom: 16 + safeBottom,
      left: 24,
      right: 24,
      child: GlassCard(
        customBorderRadius: BorderRadius.circular(40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
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
              ),
            );
          }),
        ),
      ),
    );
  }

  // 3-tab passenger nav: Discover, BioPay, Profile
  static const _passengerItems = [
    _NavItem(LucideIcons.compass, 'Discover'),
    _NavItem(LucideIcons.shieldCheck, 'BioPay'),
    _NavItem(LucideIcons.user, 'Profile'),
  ];

  // Admin nav: Dashboard, Users, Profile
  static const _adminItems = [
    _NavItem(LucideIcons.layoutDashboard, 'Dashboard'),
    _NavItem(LucideIcons.users, 'Users'),
    _NavItem(LucideIcons.user, 'Profile'),
  ];
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

  const _TappableNavItem({
    required this.onTap,
    required this.isActive,
    required this.icon,
    required this.label,
  });

  @override
  State<_TappableNavItem> createState() => _TappableNavItemState();
}

class _TappableNavItemState extends State<_TappableNavItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 100),
        opacity: _isPressed ? 0.6 : 1.0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 100),
          scale: _isPressed ? 0.92 : 1.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with active circle background
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: widget.isActive ? 48 : 40,
                height: widget.isActive ? 48 : 40,
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? cs.primary
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  size: widget.isActive ? 22 : 20,
                  color: widget.isActive
                      ? cs.onPrimary
                      : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              // Label
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: widget.isActive
                      ? cs.primary
                      : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
