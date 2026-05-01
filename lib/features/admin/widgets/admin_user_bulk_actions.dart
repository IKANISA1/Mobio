import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/features/admin/widgets/admin_ui.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';

class AdminUserBulkActions extends StatelessWidget {
  const AdminUserBulkActions({
    super.key,
    required this.selectedCount,
    required this.bulkUpdatingRole,
    required this.onApplyRole,
    required this.onClear,
  });

  final int selectedCount;
  final String? bulkUpdatingRole;
  final ValueChanged<String> onApplyRole;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final summary = Text(
            '$selectedCount selected',
            style: AppTypography.titleLg.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          );
          final actions = Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AdminActionChip(
                label: 'Admin',
                tone: MobiStatusBadgeTone.brand,
                isBusy: bulkUpdatingRole == 'admin',
                onTap: bulkUpdatingRole == null ? () => onApplyRole('admin') : null,
              ),
              AdminActionChip(
                label: 'Driver',
                tone: MobiStatusBadgeTone.info,
                isBusy: bulkUpdatingRole == 'driver',
                onTap: bulkUpdatingRole == null ? () => onApplyRole('driver') : null,
              ),
              AdminActionChip(
                label: 'Passenger',
                tone: MobiStatusBadgeTone.neutral,
                isBusy: bulkUpdatingRole == 'passenger',
                onTap: bulkUpdatingRole == null ? () => onApplyRole('passenger') : null,
              ),
              AdminActionChip(
                label: 'Clear',
                icon: LucideIcons.x,
                tone: MobiStatusBadgeTone.danger,
                onTap: onClear,
              ),
            ],
          );

          if (constraints.maxWidth >= 760) {
            return Row(
              children: [
                Expanded(child: summary),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: actions),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              summary,
              const SizedBox(height: AppSpacing.md),
              actions,
            ],
          );
        },
      ),
    );
  }
}
