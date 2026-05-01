import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/features/admin/widgets/admin_ui.dart';

class AdminUserFilterBar extends StatelessWidget {
  const AdminUserFilterBar({
    super.key,
    required this.searchController,
    required this.roleFilter,
    required this.onSearchChanged,
    required this.onRoleFilterChanged,
  });

  final TextEditingController searchController;
  final String roleFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onRoleFilterChanged;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(
            title: 'Directory',
            subtitle: 'Search and filter',
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 760;
              final filterRow = Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final filter in const [
                    ('all', 'All', LucideIcons.list),
                    ('admin', 'Admins', LucideIcons.shieldCheck),
                    ('driver', 'Drivers', LucideIcons.car),
                    ('passenger', 'Passengers', LucideIcons.user),
                  ])
                    AdminFilterChip(
                      label: filter.$2,
                      icon: filter.$3,
                      isSelected: roleFilter == filter.$1,
                      onTap: () => onRoleFilterChanged(filter.$1),
                    ),
                ],
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(
                      child: AdminSearchField(
                        controller: searchController,
                        hintText: 'Search users',
                        onChanged: onSearchChanged,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: filterRow),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AdminSearchField(
                    controller: searchController,
                    hintText: 'Search users',
                    onChanged: onSearchChanged,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  filterRow,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
