import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_app/shared/widgets/mobi_top_command_bar.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

class HomeHeader extends StatelessWidget {
  final bool isDriver;
  final int unreadCount;
  final bool isDriverOnline;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<bool>? onDriverOnlineToggle;
  final VoidCallback? onNotifications;

  const HomeHeader({
    super.key,
    required this.isDriver,
    required this.unreadCount,
    required this.onModeChanged,
    this.isDriverOnline = false,
    this.onDriverOnlineToggle,
    this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MobiTopCommandBar(
          showSearch: false,
          centerControl: SizedBox(
            height: 48,
            child: _HomeModeToggle(
              isDriver: isDriver,
              onChanged: onModeChanged,
            ),
          ),
          actions: [
            MobiTopCommandBarAction(
              icon: LucideIcons.bell,
              label: 'Notifications',
              onTap: onNotifications,
              showDot: unreadCount > 0,
            ),
          ],
        ),
        if (isDriver) const SizedBox(height: AppSpacing.md),
        if (isDriver)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              MobiStatusBadge(
                label: isDriverOnline ? 'Online' : 'Offline',
                icon: isDriverOnline ? LucideIcons.radio : LucideIcons.pause,
                tone: isDriverOnline
                    ? MobiStatusBadgeTone.positive
                    : MobiStatusBadgeTone.neutral,
              ),
              const SizedBox(width: AppSpacing.xs),
              SizedBox(
                height: 28,
                child: Switch(
                  value: isDriverOnline,
                  onChanged: onDriverOnlineToggle,
                  activeThumbColor: cs.primary,
                  activeTrackColor: cs.primary.withValues(alpha: 0.3),
                  inactiveThumbColor: cs.onSurfaceVariant,
                  inactiveTrackColor: ext.surfaceContainer,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _HomeModeToggle extends StatelessWidget {
  const _HomeModeToggle({required this.isDriver, required this.onChanged});

  final bool isDriver;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: Colors.white.withValues(alpha: ext.surfacePanelBorderAlpha),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          children: [
            _HomeModeSegment(
              label: 'Passenger',
              selected: !isDriver,
              onTap: () => onChanged('passenger'),
            ),
            const SizedBox(width: 5),
            _HomeModeSegment(
              label: 'Driver',
              selected: isDriver,
              onTap: () => onChanged('driver'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeModeSegment extends StatelessWidget {
  const _HomeModeSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: selected
              ? cs.onSurface.withValues(alpha: .16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            splashColor: Colors.white.withValues(alpha: ext.pressedWhiteAlpha),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: selected
                    ? Border.all(
                        color: Colors.white.withValues(
                          alpha: ext.surfacePanelBorderAlpha,
                        ),
                      )
                    : null,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: AppTypography.labelMd.copyWith(
                  color: selected ? cs.onSurface : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
