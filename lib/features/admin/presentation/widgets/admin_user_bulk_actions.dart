import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/features/admin/presentation/admin_copy.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';

class AdminUserBulkActions extends StatelessWidget {
  const AdminUserBulkActions({
    super.key,
    required this.selectedCount,
    required this.bulkUpdatingRole,
    required this.onReviewRole,
    required this.onClear,
    this.reviewEnabled = true,
  });

  final int selectedCount;
  final String? bulkUpdatingRole;
  final ValueChanged<String> onReviewRole;
  final VoidCallback onClear;
  final bool reviewEnabled;

  @override
  Widget build(BuildContext context) {
    final copy = AdminCopy.of(context);
    return AdminPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final summary = Text(
            copy.selectedCount(selectedCount),
            style: AppTypography.titleLg.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          );
          final actions = Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AdminActionChip(
                label: copy.reviewRole('admin'),
                tone: MobiStatusBadgeTone.brand,
                isBusy: bulkUpdatingRole == 'admin',
                onTap: reviewEnabled && bulkUpdatingRole == null
                    ? () => onReviewRole('admin')
                    : null,
              ),
              AdminActionChip(
                label: copy.reviewRole('driver'),
                tone: MobiStatusBadgeTone.info,
                isBusy: bulkUpdatingRole == 'driver',
                onTap: reviewEnabled && bulkUpdatingRole == null
                    ? () => onReviewRole('driver')
                    : null,
              ),
              AdminActionChip(
                label: copy.reviewRole('passenger'),
                tone: MobiStatusBadgeTone.neutral,
                isBusy: bulkUpdatingRole == 'passenger',
                onTap: reviewEnabled && bulkUpdatingRole == null
                    ? () => onReviewRole('passenger')
                    : null,
              ),
              AdminActionChip(
                label: copy.clear,
                icon: LucideIcons.x,
                tone: MobiStatusBadgeTone.danger,
                onTap: bulkUpdatingRole == null ? onClear : null,
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
