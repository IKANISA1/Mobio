import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/features/admin/presentation/admin_copy.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';

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
    final copy = AdminCopy.of(context);
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: copy.directory,
            subtitle: copy.searchAndFilter,
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 760;
              final filterRow = Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final filter in [
                    ('all', copy.filterAll, LucideIcons.list),
                    ('admin', copy.filterAdmins, LucideIcons.shieldCheck),
                    ('driver', copy.filterDrivers, LucideIcons.car),
                    ('passenger', copy.filterPassengers, LucideIcons.user),
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
                        hintText: copy.searchUsers,
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
                    hintText: copy.searchUsers,
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
