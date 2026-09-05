import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

enum PermissionAccessDialogAction { grantAccess, maybeLater }

class PermissionAccessDialogConfig {
  const PermissionAccessDialogConfig({
    required this.title,
    required this.message,
    required this.icon,
    this.primaryButtonLabel = 'GRANT ACCESS',
    this.secondaryButtonLabel = 'MAYBE LATER',
  });

  final String title;
  final String message;
  final IconData icon;
  final String primaryButtonLabel;
  final String secondaryButtonLabel;

  factory PermissionAccessDialogConfig.location() {
    return const PermissionAccessDialogConfig(
      title: 'LOCATION ACCESS',
      message:
          'Allow location access so Mobio can show nearby places first and auto-fill your pickup point.',
      icon: LucideIcons.mapPin,
      primaryButtonLabel: 'ENABLE LOCATION',
    );
  }

  factory PermissionAccessDialogConfig.backgroundLocation() {
    return const PermissionAccessDialogConfig(
      title: 'LIVE LOCATION SHARING',
      message:
          'Allow background location so Mobio can share your driver location with passengers while you are online, even if you switch apps. Turn off sharing anytime by going offline.',
      icon: LucideIcons.radio,
      primaryButtonLabel: 'ENABLE LIVE SHARING',
    );
  }

  factory PermissionAccessDialogConfig.notifications() {
    return const PermissionAccessDialogConfig(
      title: 'NOTIFICATION ACCESS',
      message:
          'Allow notifications so Mobio can alert you about chats, scheduled trip posts, and account updates.',
      icon: LucideIcons.bell,
      primaryButtonLabel: 'ENABLE NOTIFICATIONS',
    );
  }
}

class PermissionAccessDialog extends StatelessWidget {
  const PermissionAccessDialog({
    super.key,
    required this.config,
    this.onAction,
    this.closeOnAction = false,
  });

  final PermissionAccessDialogConfig config;
  final ValueChanged<PermissionAccessDialogAction>? onAction;
  final bool closeOnAction;

  static Future<PermissionAccessDialogAction> show(
    BuildContext context, {
    required PermissionAccessDialogConfig config,
  }) async {
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final action =
        await showGeneralDialog<PermissionAccessDialogAction>(
          context: context,
          barrierDismissible: false,
          barrierLabel: config.title,
          barrierColor: Colors.black.withValues(alpha: ext.scrimAlpha),
          pageBuilder: (context, animation, secondaryAnimation) {
            return SafeArea(
              child: Center(
                child: PermissionAccessDialog(
                  config: config,
                  closeOnAction: true,
                ),
              ),
            );
          },
          transitionBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
                child: child,
              ),
            );
          },
        ) ??
        PermissionAccessDialogAction.maybeLater;
    return action;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showMessage = config.message.trim().isNotEmpty;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: Colors.transparent,
          child: Semantics(
            label: '${config.title}. ${config.message}',
            child: ClayCard(
              padding: const EdgeInsets.all(28),
              borderRadius: 32,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(config.icon, size: 36, color: cs.primary),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    config.title,
                    textAlign: TextAlign.center,
                    style: AppTypography.headlineMd.copyWith(
                      letterSpacing: 0,
                      color: cs.onSurface,
                    ),
                  ),
                  if (showMessage) ...[
                    const SizedBox(height: 12),
                    Text(
                      config.message,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMd.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  MobiButton(
                    width: double.infinity,
                    onPressed: () => _handleAction(
                      context,
                      PermissionAccessDialogAction.grantAccess,
                    ),
                    child: Text(
                      config.primaryButtonLabel,
                      style: AppTypography.labelMd.copyWith(
                        color: cs.onInverseSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  MobiButton(
                    width: double.infinity,
                    variant: MobiButtonVariant.ghost,
                    onPressed: () => _handleAction(
                      context,
                      PermissionAccessDialogAction.maybeLater,
                    ),
                    child: Text(
                      config.secondaryButtonLabel,
                      style: AppTypography.labelMd.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleAction(
    BuildContext context,
    PermissionAccessDialogAction action,
  ) {
    onAction?.call(action);
    if (closeOnAction) {
      Navigator.of(context).pop(action);
    }
  }
}
