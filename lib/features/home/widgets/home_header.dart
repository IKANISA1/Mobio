import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_app/shared/widgets/mobi_top_command_bar.dart';

class HomeHeader extends StatelessWidget {
  final bool isDriver;
  final int unreadCount;
  final bool isDriverOnline;
  final ValueChanged<bool>? onDriverOnlineToggle;

  const HomeHeader({
    super.key,
    required this.isDriver,
    required this.unreadCount,
    this.isDriverOnline = false,
    this.onDriverOnlineToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MobiTopCommandBar(
          showNotificationDot: unreadCount > 0,
          actions: const [
            MobiTopCommandBarAction(
              icon: LucideIcons.barChart3,
              label: 'Activity',
            ),
            MobiTopCommandBarAction(
              icon: LucideIcons.calendarCheck,
              label: 'Trips',
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
