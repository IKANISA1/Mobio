import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/constants/app_constants.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';

/// Admin Users screen matching transito AdminUsers.
class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Users',
            style: AppTypography.displayMd.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage platform members',
            style: AppTypography.bodyLg.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),

          // User list
          ...AppConstants.mockUsers.map((user) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ClayCard(
              padding: const EdgeInsets.all(24),
              borderRadius: 24,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: AppTypography.titleMd.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.role.name.toUpperCase(),
                          style: AppTypography.labelSm.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(LucideIcons.moreVertical, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}
