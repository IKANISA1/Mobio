import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/features/admin/data/admin_service.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_dashboard_utils.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

class AdminPriorityPanel extends StatelessWidget {
  const AdminPriorityPanel({
    super.key,
    required this.unreadAlerts,
    required this.blockedAttempts,
    required this.inactiveNumbers,
    required this.isMarkingAlerts,
    required this.onReadAll,
    required this.onAddNumber,
    required this.onGoToUsers,
    required this.onGoToTrips,
  });

  final int unreadAlerts;
  final int blockedAttempts;
  final int inactiveNumbers;
  final bool isMarkingAlerts;
  final VoidCallback onReadAll;
  final VoidCallback onAddNumber;
  final VoidCallback onGoToUsers;
  final VoidCallback onGoToTrips;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(
            title: 'Now',
            subtitle: 'Unread, blocked, paused',
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _AttentionTile(
                label: 'Unread',
                value: '$unreadAlerts',
                tone: unreadAlerts > 0
                    ? MobiStatusBadgeTone.warning
                    : MobiStatusBadgeTone.positive,
                icon: LucideIcons.bellRing,
              ),
              _AttentionTile(
                label: 'Blocked',
                value: '$blockedAttempts',
                tone: blockedAttempts > 0
                    ? MobiStatusBadgeTone.danger
                    : MobiStatusBadgeTone.positive,
                icon: LucideIcons.shield,
              ),
              _AttentionTile(
                label: 'Paused',
                value: '$inactiveNumbers',
                tone: inactiveNumbers > 0
                    ? MobiStatusBadgeTone.warning
                    : MobiStatusBadgeTone.neutral,
                icon: LucideIcons.messageCircle,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AdminActionChip(
                label: 'Read all',
                icon: LucideIcons.checkCheck,
                tone: MobiStatusBadgeTone.positive,
                isBusy: isMarkingAlerts,
                onTap: unreadAlerts == 0 ? null : onReadAll,
              ),
              AdminActionChip(
                label: 'Add number',
                icon: LucideIcons.plus,
                tone: MobiStatusBadgeTone.brand,
                onTap: onAddNumber,
              ),
              AdminActionChip(
                label: 'Users',
                icon: LucideIcons.users,
                tone: MobiStatusBadgeTone.info,
                onTap: onGoToUsers,
              ),
              AdminActionChip(
                label: 'Trips',
                icon: LucideIcons.mapPin,
                tone: MobiStatusBadgeTone.warning,
                onTap: onGoToTrips,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AdminAlertsPanel extends StatelessWidget {
  const AdminAlertsPanel({
    super.key,
    required this.alerts,
    required this.unreadCount,
    required this.isMarkingRead,
    required this.onMarkRead,
    required this.onReadAll,
  });

  final List<AdminNotificationItem> alerts;
  final int unreadCount;
  final bool isMarkingRead;
  final ValueChanged<AdminNotificationItem> onMarkRead;
  final VoidCallback onReadAll;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Alerts',
            subtitle: '${alerts.length} items',
            trailing: unreadCount == 0
                ? null
                : AdminActionChip(
                    label: 'Read all',
                    icon: LucideIcons.checkCheck,
                    tone: MobiStatusBadgeTone.positive,
                    isBusy: isMarkingRead,
                    onTap: onReadAll,
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (alerts.isEmpty)
            const _InlineEmptyState(
              icon: LucideIcons.bellOff,
              title: 'No alerts',
              message: 'Quiet workspace.',
            )
          else
            ...alerts.map(
              (alert) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _AlertRow(
                  notification: alert,
                  onTap: () => onMarkRead(alert),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AdminAccessPanel extends StatelessWidget {
  const AdminAccessPanel({super.key, required this.accessAttempts});

  final List<AdminAccessAttemptItem> accessAttempts;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(title: 'Access', subtitle: 'Recent access'),
          const SizedBox(height: AppSpacing.lg),
          if (accessAttempts.isEmpty)
            const _InlineEmptyState(
              icon: LucideIcons.shield,
              title: 'No access events',
              message: 'No recent attempts.',
            )
          else
            ...accessAttempts.map(
              (attempt) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _AccessAttemptRow(attempt: attempt),
              ),
            ),
        ],
      ),
    );
  }
}

class AdminAllowlistPanel extends StatelessWidget {
  const AdminAllowlistPanel({
    super.key,
    required this.adminNumbers,
    required this.busyNumberId,
    required this.onEdit,
    required this.onToggle,
    required this.onAdd,
  });

  final List<AdminWhatsappNumberItem> adminNumbers;
  final String? busyNumberId;
  final ValueChanged<AdminWhatsappNumberItem> onEdit;
  final ValueChanged<AdminWhatsappNumberItem> onToggle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Allowlist',
            subtitle: '${adminNumbers.length} numbers',
            trailing: AdminActionChip(
              label: 'Add',
              icon: LucideIcons.plus,
              tone: MobiStatusBadgeTone.brand,
              onTap: onAdd,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (adminNumbers.isEmpty)
            const _InlineEmptyState(
              icon: LucideIcons.messageCircle,
              title: 'No numbers',
              message: 'Add a contact to start.',
            )
          else
            ...adminNumbers.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _AllowlistRow(
                  item: item,
                  isBusy: busyNumberId == item.id,
                  onEdit: () => onEdit(item),
                  onToggle: () => onToggle(item),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AdminPlatformSettingsPanel extends StatelessWidget {
  const AdminPlatformSettingsPanel({
    super.key,
    required this.settings,
    required this.isSaving,
    required this.onEdit,
  });

  final AdminPlatformSettings settings;
  final bool isSaving;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Platform settings',
            subtitle: 'Insurance and redemption',
            trailing: AdminActionChip(
              label: 'Edit',
              icon: LucideIcons.settings,
              tone: MobiStatusBadgeTone.brand,
              isBusy: isSaving,
              onTap: onEdit,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SettingRow(
            icon: LucideIcons.shieldCheck,
            label: 'Insurance agent',
            value: settings.insuranceAgentWhatsappE164,
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingRow(
            icon: LucideIcons.walletCards,
            label: 'Redemption wallet',
            value: settings.tokenRedemptionAdminMemberId.trim().isEmpty
                ? 'Not configured'
                : settings.tokenRedemptionAdminMemberId,
            valueColor: settings.tokenRedemptionAdminMemberId.trim().isEmpty
                ? cs.error
                : null,
          ),
        ],
      ),
    );
  }
}

class AdminTokenRedemptionsPanel extends StatelessWidget {
  const AdminTokenRedemptionsPanel({
    super.key,
    required this.redemptions,
    required this.busyRedemptionId,
    required this.onCashSent,
  });

  final List<AdminTokenRedemptionItem> redemptions;
  final String? busyRedemptionId;
  final ValueChanged<AdminTokenRedemptionItem> onCashSent;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Token redemptions',
            subtitle: '${redemptions.length} pending',
          ),
          const SizedBox(height: AppSpacing.lg),
          if (redemptions.isEmpty)
            const _InlineEmptyState(
              icon: LucideIcons.banknote,
              title: 'No pending payouts',
              message: 'Manual MoMo queue is clear.',
            )
          else
            ...redemptions.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _TokenRedemptionRow(
                  item: item,
                  isBusy: busyRedemptionId == item.id,
                  onCashSent: () => onCashSent(item),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Internal Helper Widgets

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelLg.copyWith(
              color: valueColor ?? cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _TokenRedemptionRow extends StatelessWidget {
  const _TokenRedemptionRow({
    required this.item,
    required this.isBusy,
    required this.onCashSent,
  });

  final AdminTokenRedemptionItem item;
  final bool isBusy;
  final VoidCallback onCashSent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final requester = item.requesterName?.trim().isNotEmpty == true
        ? item.requesterName!
        : item.requesterMemberId?.trim().isNotEmpty == true
        ? 'Member ${item.requesterMemberId}'
        : 'Mobio member';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).extension<MobiThemeExtension>()!.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    Text(
                      requester,
                      style: AppTypography.titleMd.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                    MobiStatusBadge(
                      label: '${item.amountTokens} TOKENS',
                      tone: MobiStatusBadgeTone.info,
                    ),
                    MobiStatusBadge(
                      label: '${item.amountRwf} RWF',
                      tone: MobiStatusBadgeTone.positive,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'MoMo ${item.momoNumber ?? 'missing'} · wallet ${item.adminMemberId}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AdminActionChip(
            label: 'Cash sent',
            icon: LucideIcons.check,
            tone: MobiStatusBadgeTone.positive,
            isBusy: isBusy,
            onTap: onCashSent,
          ),
        ],
      ),
    );
  }
}

class _AttentionTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final MobiStatusBadgeTone tone;

  const _AttentionTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AdminDashboardUtils.toneFill(context, tone),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 18,
              color: AdminDashboardUtils.toneColor(context, tone),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTypography.headlineMd.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  label,
                  style: AppTypography.bodySm.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final AdminNotificationItem notification;
  final VoidCallback onTap;

  const _AlertRow({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tone = AdminDashboardUtils.alertTone(notification);

    return InkWell(
      onTap: notification.isRead ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AdminDashboardUtils.toneFill(context, tone),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AdminDashboardUtils.toneColor(
              context,
              tone,
            ).withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                AdminDashboardUtils.alertIcon(notification),
                size: 18,
                color: AdminDashboardUtils.toneColor(context, tone),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        notification.title,
                        style: AppTypography.titleMd.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                      MobiStatusBadge(
                        label: notification.isRead ? 'Seen' : 'New',
                        tone: notification.isRead
                            ? MobiStatusBadgeTone.neutral
                            : tone,
                      ),
                    ],
                  ),
                  if ((notification.body ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      notification.body!,
                      style: AppTypography.bodySm.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AdminDashboardUtils.formatTimestamp(notification.createdAt),
                  style: AppTypography.labelSm.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (!notification.isRead) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AdminActionChip(
                    label: 'Read',
                    icon: LucideIcons.check,
                    tone: tone,
                    onTap: onTap,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessAttemptRow extends StatelessWidget {
  final AdminAccessAttemptItem attempt;

  const _AccessAttemptRow({required this.attempt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tone = AdminDashboardUtils.attemptTone(attempt.status);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).extension<MobiThemeExtension>()!.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    Text(
                      attempt.phoneE164,
                      style: AppTypography.titleMd.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                    MobiStatusBadge(
                      label: AdminDashboardUtils.statusLabel(attempt.status),
                      tone: tone,
                    ),
                    MobiStatusBadge(
                      label: AdminDashboardUtils.statusLabel(attempt.sourceApp),
                      tone: MobiStatusBadgeTone.neutral,
                    ),
                  ],
                ),
                if ((attempt.reason ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    attempt.reason!,
                    style: AppTypography.bodySm.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            AdminDashboardUtils.formatTimestamp(attempt.createdAt),
            style: AppTypography.labelSm.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _AllowlistRow extends StatelessWidget {
  final AdminWhatsappNumberItem item;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _AllowlistRow({
    required this.item,
    required this.isBusy,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).extension<MobiThemeExtension>()!.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    Text(
                      item.displayName?.trim().isNotEmpty == true
                          ? item.displayName!
                          : item.phoneE164,
                      style: AppTypography.titleMd.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                    MobiStatusBadge(
                      label: item.isActive ? 'Active' : 'Paused',
                      tone: item.isActive
                          ? MobiStatusBadgeTone.positive
                          : MobiStatusBadgeTone.warning,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.phoneE164,
                  style: AppTypography.bodySm.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.end,
            children: [
              AdminActionChip(
                label: 'Edit',
                icon: LucideIcons.pencil,
                tone: MobiStatusBadgeTone.info,
                onTap: onEdit,
              ),
              AdminActionChip(
                label: item.isActive ? 'Pause' : 'Enable',
                icon: item.isActive ? LucideIcons.pause : LucideIcons.play,
                tone: item.isActive
                    ? MobiStatusBadgeTone.warning
                    : MobiStatusBadgeTone.positive,
                isBusy: isBusy,
                onTap: onToggle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InlineEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Icon(icon, color: cs.onSurfaceVariant, size: 24),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: AppTypography.titleMd.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
