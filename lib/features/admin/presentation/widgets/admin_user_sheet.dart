import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/features/admin/presentation/admin_copy.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_user_widgets.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_shared_types/models/admin/admin_models.dart';

class AdminUserSheet extends StatelessWidget {
  const AdminUserSheet({
    super.key,
    required this.user,
    required this.currentUserId,
    required this.onReviewRole,
    required this.onAddInsuranceReward,
    this.reviewEnabled = true,
  });

  final AdminUserListItem user;
  final String? currentUserId;
  final ValueChanged<String> onReviewRole;
  final Future<void> Function() onAddInsuranceReward;
  final bool reviewEnabled;

  @override
  Widget build(BuildContext context) {
    final copy = AdminCopy.of(context);
    final cs = Theme.of(context).colorScheme;
    final canEdit = currentUserId != user.id;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: SingleChildScrollView(
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
                    label: copy.roleLabel(user.role).toUpperCase(),
                    tone: AdminUserUtils.roleTone(user.role),
                  ),
                  MobiStatusBadge(
                    label: user.isOnline ? copy.online : copy.offline,
                    tone: user.isOnline
                        ? MobiStatusBadgeTone.positive
                        : MobiStatusBadgeTone.neutral,
                  ),
                  MobiStatusBadge(
                    label: user.isDriver
                        ? copy.driverProfile
                        : copy.passengerProfile,
                    tone: user.isDriver
                        ? MobiStatusBadgeTone.info
                        : MobiStatusBadgeTone.neutral,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AdminFieldPair(label: copy.phone, value: user.phone),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AdminFieldPair(
                      label: copy.vehicle,
                      value: user.vehicleType ?? copy.notAssigned,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AdminFieldPair(
                label: copy.joined,
                value: copy.date(user.createdAt),
              ),
              const SizedBox(height: AppSpacing.lg),
              AdminActionChip(
                label: copy.messageRewardAction(copy.number(3000)),
                icon: LucideIcons.coins,
                tone: MobiStatusBadgeTone.positive,
                onTap: () async {
                  final navigator = Navigator.of(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) {
                      final copy = AdminCopy.of(dialogContext);
                      return AlertDialog(
                        title: Text(copy.rewardTitle),
                        content: Text(
                          copy.messageRewardConfirm(
                            copy.number(3000),
                            user.name,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: Text(copy.cancel),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            child: Text(copy.rewardSubmit),
                          ),
                        ],
                      );
                    },
                  );
                  if (confirmed == true) {
                    navigator.pop();
                    await onAddInsuranceReward();
                  }
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              if (!canEdit)
                Text(
                  copy.ownProfileExcluded,
                  style: AppTypography.bodySm.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                )
              else ...[
                Text(
                  copy.reviewProfileRole,
                  style: AppTypography.labelSm.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  copy.trustedAccessDisclosure,
                  style: AppTypography.bodySm.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final role in const ['passenger', 'driver', 'admin'])
                      AdminActionChip(
                        label: copy.reviewRole(role),
                        icon: role == user.role ? LucideIcons.check : null,
                        tone: AdminUserUtils.roleTone(role),
                        onTap: reviewEnabled
                            ? () {
                                Navigator.of(context).pop();
                                onReviewRole(role);
                              }
                            : null,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
