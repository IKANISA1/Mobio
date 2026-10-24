import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/auth/account_action_token.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/admin/application/admin_services.dart';
import 'package:mobi_app/features/admin/application/admin_users_provider.dart';
import 'package:mobi_app/features/admin/application/admin_users_state.dart'
    show AdminUsersState;
import 'package:mobi_app/features/admin/domain/admin_role_change.dart';
import 'package:mobi_app/features/admin/domain/admin_role_recovery.dart';
import 'package:mobi_app/features/admin/presentation/admin_copy.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_role_change_review.dart';
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
import 'package:mobi_shared_types/models/admin/admin_models.dart';

/// Admin user directory with search, filters, bulk actions, and detail review.
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _actionToken = AccountActionToken.capture();
  bool get _actionIsCurrent => mounted && _actionToken.isCurrent;
  AdminCopy get copy => AdminCopy.of(context);

  late final TextEditingController _searchController;
  bool _reviewOpen = false;
  bool _closeOpen = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    AccountContext.changes.addListener(_accountChanged);
  }

  @override
  void dispose() {
    AccountContext.changes.removeListener(_accountChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _accountChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _changeQuery(
    FutureOr<void> Function() action, {
    bool allowMissingState = false,
  }) async {
    if (!_actionIsCurrent) return;
    final latest = ref.read(adminUsersProvider).value;
    if (latest == null ? !allowMissingState : !latest.canChangeQuery) return;
    try {
      await action();
    } on Object catch (error) {
      _showSnackBar(
        (copy) => copy.error(error, fallback: AdminCopyReason.queryFailed),
        isError: true,
      );
    }
  }

  void _showSnackBar(
    String Function(AdminCopy) message, {
    bool isError = false,
  }) {
    if (!_actionIsCurrent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message(AdminCopy.of(context))),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Future<void> _showUserSheet(AdminUserListItem user) async {
    if (!_actionIsCurrent) return;
    final currentUserId = ref.read(adminServiceProvider).currentUserId;

    await MobiBottomSheet.show<void>(
      context: context,
      builder: (sheetContext) => ValueListenableBuilder<int>(
        valueListenable: AccountContext.changes,
        builder: (context, revision, child) {
          final copy = AdminCopy.of(context);
          if (!_actionIsCurrent) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(copy.accountPanelChanged),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: Text(copy.close),
                  ),
                ],
              ),
            );
          }
          return AdminUserSheet(
            user: user,
            currentUserId: currentUserId,
            reviewEnabled:
                ref.read(adminUsersProvider).value?.canPrepareReview ?? false,
            onReviewRole: (nextRole) =>
                _reviewRole(nextRole, targetIds: {user.id}),
            onAddInsuranceReward: () async {
              if (!_actionIsCurrent) return;
              try {
                await ref
                    .read(adminUsersProvider.notifier)
                    .addInsuranceRewardTokens(user);
                _showSnackBar(
                  (copy) =>
                      copy.messageRewardAdded(copy.number(3000), user.name),
                );
              } on Object catch (e) {
                _showSnackBar(
                  (copy) =>
                      copy.error(e, fallback: AdminCopyReason.userUpdateFailed),
                  isError: true,
                );
              }
            },
          );
        },
      ),
    );
  }

  Future<void> _reviewRole(String role, {Set<String>? targetIds}) async {
    if (!_actionIsCurrent || _reviewOpen) return;
    final controller = ref.read(adminUsersProvider.notifier);
    AdminRoleReview? review;
    var dispatchStarted = false;
    _reviewOpen = true;
    try {
      review = controller.prepareRoleReview(role, targetIds: targetIds);
      final frozen = review;
      final confirmed = await MobiBottomSheet.show<bool>(
        context: context,
        builder: (sheetContext) => ValueListenableBuilder<int>(
          valueListenable: AccountContext.changes,
          builder: (context, revision, child) => Consumer(
            builder: (context, ref, child) {
              final copy = AdminCopy.of(context);
              final current = ref.watch(adminUsersProvider).value;
              if (!_actionIsCurrent ||
                  current?.roleReview?.reviewId != frozen.reviewId) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(copy.reviewUnavailable),
                      const SizedBox(height: AppSpacing.md),
                      TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: Text(copy.close),
                      ),
                    ],
                  ),
                );
              }
              return AdminRoleChangeReview(
                review: frozen,
                remaining: current?.reviewRemaining ?? Duration.zero,
                canConfirm:
                    _actionIsCurrent &&
                    current?.roleReview?.reviewId == frozen.reviewId &&
                    (current?.reviewCanConfirm ?? false),
                onCancel: () => Navigator.of(sheetContext).pop(false),
                onConfirm: () {
                  if (!_actionIsCurrent) return;
                  final latest = ref.read(adminUsersProvider).value;
                  if (latest?.roleReview?.reviewId != frozen.reviewId ||
                      !(latest?.reviewCanConfirm ?? false)) {
                    return;
                  }
                  Navigator.of(sheetContext).pop(true);
                },
              );
            },
          ),
        ),
      );
      if (!_actionIsCurrent) return;
      if (confirmed != true) {
        controller.cancelRoleReview(frozen.reviewId);
        return;
      }
      dispatchStarted = true;
      await controller.confirmRoleReview(frozen.reviewId);
    } on Object {
      if (!dispatchStarted && _actionIsCurrent && review != null) {
        controller.cancelRoleReview(review.reviewId);
      }
      _showSnackBar(
        (copy) =>
            dispatchStarted ? copy.reviewContinueFailed : copy.reviewShowFailed,
        isError: true,
      );
    } finally {
      _reviewOpen = false;
    }
  }

  Future<void> _reconcileRoleWork() async {
    if (!_actionIsCurrent) return;
    try {
      await ref.read(adminUsersProvider.notifier).reconcileOutstanding();
    } on Object {
      _showSnackBar((copy) => copy.statusUnconfirmed, isError: true);
    }
  }

  Future<void> _closeRoleWork() async {
    if (!_actionIsCurrent || _closeOpen) return;
    _closeOpen = true;
    var choiceMade = false;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final copy = AdminCopy.of(dialogContext);
          return AlertDialog(
            title: Text(copy.closeBatchTitle),
            content: Text(copy.closeBatchBody),
            actions: [
              TextButton(
                onPressed: () {
                  if (choiceMade) return;
                  choiceMade = true;
                  Navigator.of(dialogContext).pop(false);
                },
                child: Text(copy.cancel),
              ),
              FilledButton(
                onPressed: () {
                  if (choiceMade) return;
                  choiceMade = true;
                  Navigator.of(dialogContext).pop(true);
                },
                child: Text(copy.closeBatch),
              ),
            ],
          );
        },
      );
      if (!_actionIsCurrent || confirmed != true) return;
      await ref.read(adminUsersProvider.notifier).closeOutstanding();
    } on Object {
      _showSnackBar((copy) => copy.closureUnconfirmed, isError: true);
    } finally {
      _closeOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AdminCopy.of(context);
    final asyncState = ref.watch(adminUsersProvider);
    final controller = ref.read(adminUsersProvider.notifier);

    return AdminWorkspaceFrame(
      currentTab: AdminWorkspaceTab.users,
      title: copy.usersTitle,
      subtitle: copy.usersSubtitle,
      actions: [
        AdminActionChip(
          label: copy.refresh,
          icon: LucideIcons.refreshCw,
          isBusy: asyncState.isLoading,
          onTap:
              _actionIsCurrent &&
                  (asyncState.value?.canChangeQuery ?? !asyncState.isLoading)
              ? () => _changeQuery(controller.refresh, allowMissingState: true)
              : null,
        ),
      ],
      child: asyncState.when(
        data: (state) => _buildContent(state, controller),
        loading: () => const _UsersLoadingState(),
        error: (err, stack) => ListView(
          padding: AdminLayoutTokens.pagePadding,
          children: [
            AdminEmptyState(
              title: copy.usersUnavailable,
              message: copy.usersLoadFailed,
              icon: LucideIcons.alertTriangle,
              action: AdminActionChip(
                label: copy.retry,
                icon: LucideIcons.refreshCw,
                onTap: () =>
                    _changeQuery(controller.refresh, allowMissingState: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AdminUsersState state, AdminUsersController controller) {
    if (!_actionIsCurrent) {
      return AdminEmptyState(
        title: copy.accountChangedTitle,
        message: copy.accountChangedBody,
        icon: LucideIcons.lock,
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AdminLayoutTokens.pagePadding,
      children: [
        if (state.roleOutcomes.isNotEmpty ||
            state.roleEnvelope != null ||
            state.roleWorkSealed ||
            state.recoveryPhase != AdminRoleRecoveryPhase.ready ||
            state.recoveryError != null) ...[
          AdminRoleChangeOutcome(
            outcomes: state.roleOutcomes,
            phase: state.recoveryPhase,
            workSealed: state.roleWorkSealed,
            canReconcile: state.canReconcile,
            canClose: state.canCloseOutstanding,
            recoveryError: state.recoveryError,
            onReconcile: _reconcileRoleWork,
            onClose: _closeRoleWork,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        _AdminQueryControls(
          key: const ValueKey('admin.users.query.filters'),
          enabled: state.canChangeQuery,
          child: AdminUserFilterBar(
            searchController: _searchController,
            roleFilter: state.roleFilter,
            onSearchChanged: (value) =>
                _changeQuery(() => controller.onSearchChanged(value)),
            onRoleFilterChanged: (value) =>
                _changeQuery(() => controller.onRoleFilterChanged(value)),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (state.selectedIds.isNotEmpty) ...[
          AdminUserBulkActions(
            selectedCount: state.selectedIds.length,
            bulkUpdatingRole: state.bulkUpdatingRole,
            reviewEnabled: state.canPrepareReview,
            onReviewRole: _reviewRole,
            onClear: () {
              if (_actionIsCurrent) controller.toggleSelectAll(false);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        AdminUserMetrics(
          users: state.users,
          roleFilter: state.roleFilter,
          totalExact: state.totalExact,
          asOf: state.asOf,
        ),
        const SizedBox(height: AppSpacing.lg),
        _AdminUsersTableControls(
          totalRows: state.totalExact,
          asOf: state.asOf,
          expiresAt: state.expiresAt,
          expired: state.snapshotExpired,
          remaining: state.reviewRemaining,
          age: state.snapshotAge,
          ageIsUpperBound: state.snapshotAgeIsUpperBound,
          sortKey: state.sortKey,
          queryEnabled: state.canChangeQuery,
          onSortChanged: (value) =>
              _changeQuery(() => controller.setSortKey(value)),
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
                    copy.controlledMessage(state.loadError),
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
          AdminEmptyState(
            title: copy.noUsers,
            message: copy.tryFilter,
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
                  onToggleSelection: (id, selected) {
                    if (_actionIsCurrent) {
                      controller.toggleSelection(id, selected);
                    }
                  },
                  onToggleSelectAll: (selected) {
                    if (_actionIsCurrent) {
                      controller.toggleSelectionFor(
                        state.users.map((user) => user.id),
                        selected,
                      );
                    }
                  },
                  onUserTap: _showUserSheet,
                ),
                if (state.totalExact != null && !state.snapshotExpired)
                  _AdminQueryControls(
                    key: const ValueKey('admin.users.query.pagination'),
                    enabled: state.canChangeQuery && !state.isLoading,
                    child: AdminPaginationBar(
                      totalItems: state.totalExact!,
                      page: state.page,
                      rowsPerPage: state.rowsPerPage,
                      onPageChanged: (value) =>
                          _changeQuery(() => controller.setPage(value)),
                      onRowsPerPageChanged: (value) =>
                          _changeQuery(() => controller.setRowsPerPage(value)),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Keep the shared query components and geometry while disabling their input.
/// Callback owners also check current state, covering stale menu/callback races.
class _AdminQueryControls extends StatelessWidget {
  const _AdminQueryControls({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    enabled: enabled,
    child: Focus(
      canRequestFocus: false,
      descendantsAreFocusable: enabled,
      descendantsAreTraversable: enabled,
      child: AbsorbPointer(
        absorbing: !enabled,
        child: Opacity(opacity: enabled ? 1 : 0.45, child: child),
      ),
    ),
  );
}

class _AdminUsersTableControls extends StatelessWidget {
  const _AdminUsersTableControls({
    required this.totalRows,
    required this.sortKey,
    required this.onSortChanged,
    required this.asOf,
    required this.expiresAt,
    required this.expired,
    required this.remaining,
    required this.age,
    required this.ageIsUpperBound,
    required this.queryEnabled,
  });

  final int? totalRows;
  final DateTime? asOf;
  final DateTime? expiresAt;
  final bool expired;
  final Duration remaining;
  final Duration age;
  final bool ageIsUpperBound;
  final bool queryEnabled;
  final String sortKey;
  final ValueChanged<String> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final copy = AdminCopy.of(context);
    return AdminPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                totalRows == null
                    ? copy.matchingCountUnavailable
                    : copy.matchingCount(totalRows!),
                style: AppTypography.labelMd.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              _AdminQueryControls(
                key: const ValueKey('admin.users.query.sort'),
                enabled: queryEnabled,
                child: AdminSortMenu(
                  value: sortKey,
                  options: [
                    AdminSortOption(
                      value: 'online',
                      label: copy.sortOnline,
                      icon: LucideIcons.activity,
                    ),
                    AdminSortOption(
                      value: 'name_asc',
                      label: copy.sortNameAsc,
                      icon: LucideIcons.arrowUpAZ,
                    ),
                    AdminSortOption(
                      value: 'name_desc',
                      label: copy.sortNameDesc,
                      icon: LucideIcons.arrowDownZA,
                    ),
                    AdminSortOption(
                      value: 'role',
                      label: copy.sortRole,
                      icon: LucideIcons.shield,
                    ),
                    AdminSortOption(
                      value: 'newest',
                      label: copy.sortNewest,
                      icon: LucideIcons.clock,
                    ),
                  ],
                  onChanged: onSortChanged,
                ),
              ),
            ],
          ),
          if (asOf != null && expiresAt != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              copy.messageSnapshotRange(
                copy.timestamp(asOf!),
                copy.timestamp(expiresAt!),
              ),
              style: AppTypography.bodySm.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              copy.snapshotAge(age, upperBound: ageIsUpperBound),
              style: AppTypography.bodySm.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Semantics(
              liveRegion: expired,
              child: Text(
                expired
                    ? copy.snapshotExpired
                    : copy.snapshotRemaining(remaining),
                style: AppTypography.bodySm.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
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
