import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/features/admin/application/admin_services.dart';
import 'package:mobi_app/features/admin/application/admin_users_provider.dart';
import 'package:mobi_app/features/admin/application/admin_users_state.dart';
import 'package:mobi_app/features/admin/data/admin_service.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_user_bulk_actions.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_user_filter_bar.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_user_metrics.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_user_sheet.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_user_widgets.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_sheet.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';

/// Admin user directory with search, filters, bulk actions, and detail review.
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Future<void> _showUserSheet(AdminUserListItem user) async {
    final currentUserId = ref.read(adminServiceProvider).currentUserId;

    await MobiBottomSheet.show<void>(
      context: context,
      builder: (context) => AdminUserSheet(
        user: user,
        currentUserId: currentUserId,
        onUpdateRole: (nextRole) async {
          try {
            await ref
                .read(adminUsersProvider.notifier)
                .updateSingleUserRole(user, nextRole);
            _showSnackBar('${user.name} is now ${nextRole.toUpperCase()}.');
          } on Object catch (e) {
            _showSnackBar(e.toString(), isError: true);
          }
        },
        onAddInsuranceReward: () async {
          try {
            await ref
                .read(adminUsersProvider.notifier)
                .addInsuranceRewardTokens(user);
            _showSnackBar('3000 TOKENS added to ${user.name}.');
          } on Object catch (e) {
            _showSnackBar(e.toString(), isError: true);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(adminUsersProvider);
    final controller = ref.read(adminUsersProvider.notifier);

    return AdminWorkspaceFrame(
      currentTab: AdminWorkspaceTab.users,
      title: 'Users',
      subtitle: 'Directory and roles.',
      actions: [
        AdminActionChip(
          label: 'Refresh',
          icon: LucideIcons.refreshCw,
          isBusy: asyncState.isLoading,
          onTap: controller.refresh,
        ),
      ],
      child: asyncState.when(
        data: (state) => _buildContent(state, controller),
        loading: () => const _UsersLoadingState(),
        error: (err, stack) => ListView(
          padding: AdminLayoutTokens.pagePadding,
          children: [
            AdminEmptyState(
              title: 'Users unavailable',
              message: err.toString(),
              icon: LucideIcons.alertTriangle,
              action: AdminActionChip(
                label: 'Retry',
                icon: LucideIcons.refreshCw,
                onTap: controller.refresh,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AdminUsersState state, AdminUsersController controller) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AdminLayoutTokens.pagePadding,
      children: [
        AdminUserFilterBar(
          searchController: _searchController,
          roleFilter: state.roleFilter,
          onSearchChanged: controller.onSearchChanged,
          onRoleFilterChanged: controller.onRoleFilterChanged,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (state.selectedIds.isNotEmpty) ...[
          AdminUserBulkActions(
            selectedCount: state.selectedIds.length,
            bulkUpdatingRole: state.bulkUpdatingRole,
            onApplyRole: (role) async {
              try {
                await controller.applyRoleToSelected(role);
                _showSnackBar('Updated ${state.selectedIds.length} users.');
              } on Object catch (e) {
                _showSnackBar(e.toString(), isError: true);
              }
            },
            onClear: () => controller.toggleSelectAll(false),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        AdminUserMetrics(users: state.users, roleFilter: state.roleFilter),
        const SizedBox(height: AppSpacing.lg),
        _AdminUsersTableControls(
          totalRows: state.paginationTotal,
          sortKey: state.sortKey,
          onSortChanged: controller.setSortKey,
        ),
        const SizedBox(height: AppSpacing.md),
        if (state.loadError != null) ...[
          AdminPanel(
            child: Row(
              children: [
                Icon(
                  LucideIcons.alertTriangle,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    state.loadError!,
                    style: AppTypography.bodySm.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (state.users.isEmpty)
          const AdminEmptyState(
            title: 'No users',
            message: 'Try another filter.',
            icon: LucideIcons.search,
          )
        else
          AdminPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AdminUserTable(
                  users: state.users,
                  selectedIds: state.selectedIds,
                  updatingUserId: state.updatingUserId,
                  onToggleSelection: controller.toggleSelection,
                  onToggleSelectAll: (selected) =>
                      controller.toggleSelectionFor(
                        state.users.map((user) => user.id),
                        selected,
                      ),
                  onUserTap: _showUserSheet,
                ),
                AdminPaginationBar(
                  totalItems: state.paginationTotal,
                  page: state.page,
                  rowsPerPage: state.rowsPerPage,
                  onPageChanged: controller.setPage,
                  onRowsPerPageChanged: controller.setRowsPerPage,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AdminUsersTableControls extends StatelessWidget {
  const _AdminUsersTableControls({
    required this.totalRows,
    required this.sortKey,
    required this.onSortChanged,
  });

  final int totalRows;
  final String sortKey;
  final ValueChanged<String> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text(
            '$totalRows matching members',
            style: AppTypography.labelMd.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          AdminSortMenu(
            value: sortKey,
            options: const [
              AdminSortOption(
                value: 'online',
                label: 'Online first',
                icon: LucideIcons.activity,
              ),
              AdminSortOption(
                value: 'name_asc',
                label: 'Name A-Z',
                icon: LucideIcons.arrowUpAZ,
              ),
              AdminSortOption(
                value: 'name_desc',
                label: 'Name Z-A',
                icon: LucideIcons.arrowDownZA,
              ),
              AdminSortOption(
                value: 'role',
                label: 'Role',
                icon: LucideIcons.shield,
              ),
              AdminSortOption(
                value: 'newest',
                label: 'Newest',
                icon: LucideIcons.clock,
              ),
            ],
            onChanged: onSortChanged,
          ),
        ],
      ),
    );
  }
}

class _UsersLoadingState extends StatelessWidget {
  const _UsersLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AdminLayoutTokens.pagePadding,
      children: const [
        LoadingSkeleton(height: 108, borderRadius: 28),
        SizedBox(height: AppSpacing.md),
        LoadingSkeleton(height: 360, borderRadius: 28),
      ],
    );
  }
}
