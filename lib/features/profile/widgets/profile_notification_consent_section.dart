import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/features/profile/providers/notification_consent_provider.dart';
import 'package:mobi_app/models/notification_consent_settings.dart';
import 'package:mobi_app/shared/widgets/mobi_section_header.dart';
import 'package:mobi_app/shared/widgets/permission_access_dialog.dart';

class ProfileNotificationConsentSection extends ConsumerWidget {
  const ProfileNotificationConsentSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(notificationConsentProvider);
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MobiSectionHeader(
          title: 'Notifications',
          caption: 'Promo consent',
          icon: LucideIcons.bell,
        ),
        const SizedBox(height: AppSpacing.md),
        Material(
          color: ext.surfaceContainerLowest,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.16)),
          ),
          child: consent.when(
            data: (settings) => _ConsentControls(settings: settings),
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.alertTriangle, color: cs.error, size: 20),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      userMessageForError(
                        error,
                        fallback:
                            'Notification consent settings are unavailable.',
                      ),
                      style: AppTypography.bodySm.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(notificationConsentProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConsentControls extends ConsumerWidget {
  const _ConsentControls({required this.settings});

  final NotificationConsentSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        _ConsentSwitch(
          title: 'Promotional in-app notifications',
          value: settings.promotionalInApp,
          onChanged: (value) => unawaited(
            _save(
              context,
              () => ref
                  .read(notificationConsentProvider.notifier)
                  .setPromotionalInApp(value),
            ),
          ),
        ),
        Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.18)),
        _ConsentSwitch(
          title: 'Promotional push notifications',
          value: settings.promotionalPush,
          onChanged: (value) =>
              unawaited(_savePromotionalPush(ref, context, value)),
        ),
      ],
    );
  }

  Future<void> _save(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification consent updated.')),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userMessageForError(
              error,
              fallback: 'Unable to update notification consent.',
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _savePromotionalPush(
    WidgetRef ref,
    BuildContext context,
    bool value,
  ) async {
    if (value) {
      final pushService = ref.read(pushNotificationServiceProvider);
      final hasPermission = await pushService.hasPermission();
      if (!hasPermission) {
        if (!context.mounted) return;
        final action = await PermissionAccessDialog.show(
          context,
          config: PermissionAccessDialogConfig.notifications(),
        );
        if (action != PermissionAccessDialogAction.grantAccess) {
          return;
        }

        final granted = await pushService.requestPermission();
        if (!granted) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Notification access was not enabled.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
          return;
        }
      }

      await pushService.registerToken();
    }

    if (!context.mounted) return;
    await _save(
      context,
      () => ref
          .read(notificationConsentProvider.notifier)
          .setPromotionalPush(value),
    );
  }
}

class _ConsentSwitch extends StatelessWidget {
  const _ConsentSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      title: Text(
        title,
        style: AppTypography.titleMd.copyWith(color: cs.onSurface),
      ),
    );
  }
}
