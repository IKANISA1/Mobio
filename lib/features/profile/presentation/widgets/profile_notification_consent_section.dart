import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/features/notifications/application/notification_services.dart';
import 'package:mobi_app/features/profile/application/notification_consent_provider.dart';
import 'package:mobi_app/shared/widgets/mobi_section_header.dart';
import 'package:mobi_app/shared/widgets/permission_access_dialog.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';
import 'package:mobi_shared_types/models/notification_consent_settings.dart';

class ProfileNotificationConsentSection extends ConsumerWidget {
  const ProfileNotificationConsentSection({super.key})
    : _captureOverride = null,
      _isCurrentOverride = null;

  @visibleForTesting
  const ProfileNotificationConsentSection.test({
    super.key,
    required AccountSnapshot Function() captureAccount,
    required bool Function(AccountSnapshot) isCurrent,
  }) : _captureOverride = captureAccount,
       _isCurrentOverride = isCurrent;

  final AccountSnapshot Function()? _captureOverride;
  final bool Function(AccountSnapshot)? _isCurrentOverride;

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
            data: (settings) => _ConsentControls(
              settings: settings,
              captureAccount: _captureOverride,
              isCurrent: _isCurrentOverride,
            ),
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
  const _ConsentControls({
    required this.settings,
    this.captureAccount,
    this.isCurrent,
  });

  final NotificationConsentSettings settings;
  final AccountSnapshot Function()? captureAccount;
  final bool Function(AccountSnapshot)? isCurrent;

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

  AccountSnapshot? _captureAccount() =>
      captureAccount?.call() ??
      (SupabaseConfig.isLocalUiPreview ? null : AccountContext.capture());

  bool _current(BuildContext context, AccountSnapshot? account) =>
      context.mounted &&
      (account == null
          ? SupabaseConfig.isLocalUiPreview
          : isCurrent?.call(account) ?? AccountContext.isCurrent(account));

  Future<void> _save(
    BuildContext context,
    Future<void> Function() action, {
    AccountSnapshot? expectedAccount,
  }) async {
    AccountSnapshot? account;
    try {
      account = expectedAccount ?? _captureAccount();
      if (!context.mounted || !_current(context, account)) return;
      await action();
      if (!context.mounted || !_current(context, account)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification consent updated.')),
      );
    } on Object catch (error) {
      if (!context.mounted || !_current(context, account)) return;
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
    AccountSnapshot? account;
    try {
      account = _captureAccount();
    } on Object {
      return;
    }
    if (!context.mounted || !_current(context, account)) return;
    if (value) {
      final pushService = ref.read(pushNotificationServiceProvider);
      final hasPermission = await pushService.hasPermission();
      if (!context.mounted || !_current(context, account)) return;
      if (!hasPermission) {
        if (!context.mounted || !_current(context, account)) return;
        final action = await PermissionAccessDialog.show(
          context,
          config: PermissionAccessDialogConfig.notifications(),
        );
        if (!context.mounted ||
            !_current(context, account) ||
            action != PermissionAccessDialogAction.grantAccess) {
          return;
        }

        final granted = await pushService.requestPermission();
        if (!context.mounted || !_current(context, account)) return;
        if (!granted) {
          if (!context.mounted || !_current(context, account)) return;
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

    if (!context.mounted || !_current(context, account)) return;
    await _save(
      context,
      () => ref
          .read(notificationConsentProvider.notifier)
          .setPromotionalPush(value),
      expectedAccount: account,
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
