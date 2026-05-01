import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/services/admin_service.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/features/admin/widgets/admin_ui.dart';
import 'package:mobi_app/features/admin/widgets/admin_user_widgets.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';

class AdminUserSheet extends StatelessWidget {
  const AdminUserSheet({
    super.key,
    required this.user,
    required this.currentUserId,
    required this.onUpdateRole,
  });

  final AdminUserListItem user;
  final String? currentUserId;
  final ValueChanged<String> onUpdateRole;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canEdit = currentUserId != user.id;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminSectionHeader(
              title: user.name,
              subtitle: user.memberId ?? user.phone,
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                MobiStatusBadge(
                  label: user.role.toUpperCase(),
                  tone: AdminUserUtils.roleTone(user.role),
                ),
                MobiStatusBadge(
                  label: user.isOnline ? 'Online' : 'Offline',
                  tone: user.isOnline
                      ? MobiStatusBadgeTone.positive
                      : MobiStatusBadgeTone.neutral,
                ),
                MobiStatusBadge(
                  label: user.hasFaceId ? 'Face ready' : 'No face',
                  tone: user.hasFaceId
                      ? MobiStatusBadgeTone.info
                      : MobiStatusBadgeTone.warning,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AdminFieldPair(label: 'Phone', value: user.phone),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AdminFieldPair(
                    label: 'Vehicle',
                    value: user.vehicleType ?? 'Not assigned',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AdminFieldPair(
              label: 'Joined',
              value: AdminUserUtils.formatDate(user.createdAt),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!canEdit)
              Text(
                'Current role locked.',
                style: AppTypography.bodySm.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              )
            else ...[
              Text(
                'Change Role',
                style: AppTypography.labelSm.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final role in const ['passenger', 'driver', 'admin'])
                    AdminActionChip(
                      label: role[0].toUpperCase() + role.substring(1),
                      icon: role == user.role ? LucideIcons.check : null,
                      tone: AdminUserUtils.roleTone(role),
                      onTap: () {
                        if (role != user.role) {
                          Navigator.of(context).pop();
                          onUpdateRole(role);
                        }
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
