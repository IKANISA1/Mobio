import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';

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

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              SizedBox.square(
                dimension: 24,
                child: ClipRect(
                  child: Transform.scale(
                    scale: 1.38,
                    child: Image.asset(
                      'icon/mobi_logo_transparent.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Mobio',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleLg.copyWith(
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            children: [
              Center(
                child: Icon(
                  LucideIcons.bell,
                  size: 22,
                  color: cs.onSurfaceVariant,
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      color: cs.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      textAlign: TextAlign.center,
                      style: AppTypography.labelSm.copyWith(
                        color: cs.onError,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (isDriver) const SizedBox(width: 8),
        if (isDriver)
          Row(
            mainAxisSize: MainAxisSize.min,
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
