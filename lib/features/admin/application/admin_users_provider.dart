import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/admin/application/admin_services.dart';
import 'package:mobi_app/features/admin/application/admin_users_state.dart';
import 'package:mobi_app/features/admin/data/admin_service.dart';

final adminUsersProvider =
    AsyncNotifierProvider.autoDispose<AdminUsersController, AdminUsersState>(
      AdminUsersController.new,
    );

class AdminUsersController extends AsyncNotifier<AdminUsersState> {
  AdminService get _adminService => ref.read(adminServiceProvider);
  Timer? _searchDebounce;
  int _requestVersion = 0;

  @override
  FutureOr<AdminUsersState> build() async {
    ref.onDispose(() {
      _searchDebounce?.cancel();
    });
    return _fetchUsers(const AdminUsersState());
  }

  Future<AdminUsersState> _fetchUsers(AdminUsersState request) async {
    try {
      final users = await _adminService.listUsers(
        role: request.roleFilter == 'all' ? null : request.roleFilter,
        search: request.searchQuery.trim().isEmpty
            ? null
            : request.searchQuery.trim(),
        limit: request.rowsPerPage + 1,
        offset: request.page * request.rowsPerPage,
      );
      final pageUsers = users.take(request.rowsPerPage).toList()
        ..sort((a, b) => _sortUsers(a, b, request.sortKey));
      return request.copyWith(
        users: pageUsers,
        selectedIds: request.selectedIds.intersection(
          pageUsers.map((user) => user.id).toSet(),
        ),
        isLoading: false,
        loadError: null,
        hasNextPage: users.length > request.rowsPerPage,
      );
    } on Object catch (error) {
      AppLogger.warning('Admin user list failed (${error.runtimeType}).');
      return request.copyWith(
        users: [],
        selectedIds: {},
        isLoading: false,
        loadError: 'Unable to load users. Check your connection and try again.',
        hasNextPage: false,
      );
    }
  }

  Future<void> _loadUsers([AdminUsersState? request]) async {
    if (!ref.mounted) return;
    final snapshot = request ?? state.value ?? const AdminUsersState();
    final version = ++_requestVersion;
    state = AsyncValue.data(
      snapshot.copyWith(isLoading: true, loadError: null),
    );
    state = const AsyncValue.loading();
    final loaded = await _fetchUsers(snapshot);
    if (!ref.mounted || version != _requestVersion) return;

    // Selection, local sort and operation indicators may change while loading.
    // Apply the fetched records only to the still-current query and page.
    final current = state.value ?? snapshot;
    final users = [...loaded.users]
      ..sort((a, b) => _sortUsers(a, b, current.sortKey));
    state = AsyncValue.data(
      loaded.copyWith(
        users: users,
        sortKey: current.sortKey,
        selectedIds: current.selectedIds.intersection(
          users.map((user) => user.id).toSet(),
        ),
        updatingUserId: current.updatingUserId,
        bulkUpdatingRole: current.bulkUpdatingRole,
      ),
    );
  }

  void onSearchChanged(String query) {
    final current = state.value;
    if (current == null) return;
    _searchDebounce?.cancel();
    // Invalidate an in-flight result as soon as the query changes, including
    // the debounce interval before the replacement request starts.
    _requestVersion++;
    state = AsyncValue.data(
      current.copyWith(
        searchQuery: query,
        page: 0,
        selectedIds: {},
        isLoading: false,
        loadError: null,
      ),
    );
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_loadUsers());
    });
  }

  Future<void> onRoleFilterChanged(String role) async {
    _searchDebounce?.cancel();
    final current = state.value ?? const AdminUsersState();
    await _loadUsers(
      current.copyWith(roleFilter: role, page: 0, selectedIds: {}),
    );
  }

  void setSortKey(String sortKey) {
    final current = state.value;
    if (current == null || current.sortKey == sortKey) return;
    final users = [...current.users]..sort((a, b) => _sortUsers(a, b, sortKey));
    state = AsyncValue.data(current.copyWith(users: users, sortKey: sortKey));
  }

  Future<void> setPage(int page) async {
    final current = state.value;
    if (current == null) return;
    _searchDebounce?.cancel();
    await _loadUsers(
      current.copyWith(page: page < 0 ? 0 : page, selectedIds: {}),
    );
  }

  Future<void> setRowsPerPage(int rowsPerPage) async {
    final current = state.value;
    if (current == null || rowsPerPage <= 0) return;
    _searchDebounce?.cancel();
    await _loadUsers(
      current.copyWith(rowsPerPage: rowsPerPage, page: 0, selectedIds: {}),
    );
  }

  Future<void> refresh() async {
    _searchDebounce?.cancel();
    await _loadUsers();
  }

  void _requireIdle(AdminUsersState current) {
    if (state.isLoading) {
      throw const ValidationException(
        message: 'Wait for users to finish loading.',
      );
    }
    if (current.updatingUserId != null || current.bulkUpdatingRole != null) {
      throw const ValidationException(
        message: 'A user update is already in progress.',
      );
    }
  }

  void toggleSelection(String userId, bool isSelected) {
    final currentState = state.value;
    if (currentState == null || state.isLoading) return;

    final newSelectedIds = Set<String>.from(currentState.selectedIds);
    if (isSelected) {
      if (currentState.users.any((user) => user.id == userId)) {
        newSelectedIds.add(userId);
      }
    } else {
      newSelectedIds.remove(userId);
    }

    state = AsyncValue.data(currentState.copyWith(selectedIds: newSelectedIds));
  }

  void toggleSelectAll(bool isSelected) {
    final currentState = state.value;
    if (currentState == null || state.isLoading) return;

    final newSelectedIds = isSelected
        ? currentState.users.map((u) => u.id).toSet()
        : <String>{};

    state = AsyncValue.data(currentState.copyWith(selectedIds: newSelectedIds));
  }

  void toggleSelectionFor(Iterable<String> userIds, bool isSelected) {
    final currentState = state.value;
    if (currentState == null || state.isLoading) return;

    final newSelectedIds = Set<String>.from(currentState.selectedIds);
    if (isSelected) {
      final visibleIds = currentState.users.map((user) => user.id).toSet();
      newSelectedIds.addAll(userIds.where(visibleIds.contains));
    } else {
      newSelectedIds.removeAll(userIds);
    }

    state = AsyncValue.data(currentState.copyWith(selectedIds: newSelectedIds));
  }

  Future<void> updateSingleUserRole(
    AdminUserListItem user,
    String nextRole,
  ) async {
    final currentState = state.value;
    if (currentState == null) return;
    if (_adminService.currentUserId == user.id || user.role == nextRole) return;

    _requireIdle(currentState);
    state = AsyncValue.data(currentState.copyWith(updatingUserId: user.id));

    try {
      await _adminService.updateUserRole(userId: user.id, role: nextRole);
      if (!ref.mounted) return;
      await _loadUsers();
      if (!ref.mounted) return;
      state = AsyncValue.data(
        (state.value ?? currentState).copyWith(updatingUserId: null),
      );
    } on Object {
      if (!ref.mounted) rethrow;
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(
          finalState.copyWith(
            updatingUserId: null,
            loadError: 'Unable to update the user. Refresh and try again.',
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> addInsuranceRewardTokens(AdminUserListItem user) async {
    final currentState = state.value;
    if (currentState == null) return;

    _requireIdle(currentState);
    state = AsyncValue.data(currentState.copyWith(updatingUserId: user.id));

    try {
      await _adminService.adjustUserTokens(
        userId: user.id,
        amountTokens: 3000,
        note: 'Motor insurance purchase reward',
      );
      if (!ref.mounted) return;
      await _loadUsers();
      if (!ref.mounted) return;
      state = AsyncValue.data(
        (state.value ?? currentState).copyWith(updatingUserId: null),
      );
    } on Object {
      if (!ref.mounted) rethrow;
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(
          finalState.copyWith(
            updatingUserId: null,
            loadError: 'Unable to update the user. Refresh and try again.',
          ),
        );
      }
      rethrow;
    }
  }

  Future<AdminRoleUpdateResult> applyRoleToSelected(String role) async {
    final current = state.value;
    if (current == null) {
      throw const ValidationException(message: 'Wait for users to load.');
    }
    _requireIdle(current);
    final selected = Set<String>.of(current.selectedIds);
    final currentUserId = _adminService.currentUserId;
    final targetIds = current.users
        .where(
          (user) =>
              selected.contains(user.id) &&
              user.id != currentUserId &&
              user.role != role,
        )
        .map((user) => user.id)
        .toSet();
    final skipped = selected.length - targetIds.length;
    if (targetIds.isEmpty) {
      state = AsyncValue.data(current.copyWith(selectedIds: {}));
      return AdminRoleUpdateResult(
        updatedCount: 0,
        failedIds: const {},
        skippedCount: skipped,
      );
    }

    state = AsyncValue.data(current.copyWith(bulkUpdatingRole: role));
    final failedIds = <String>{};
    await Future.wait(
      targetIds.map((id) async {
        try {
          await _adminService.updateUserRole(userId: id, role: role);
        } on Object {
          failedIds.add(id);
        }
      }),
    );
    final result = AdminRoleUpdateResult(
      updatedCount: targetIds.length - failedIds.length,
      failedIds: Set.unmodifiable(failedIds),
      skippedCount: skipped,
    );
    if (!ref.mounted) return result;
    final latest = state.value ?? current;
    state = AsyncValue.data(
      latest.copyWith(
        selectedIds: latest.selectedIds.difference(
          selected.difference(failedIds),
        ),
      ),
    );
    // Refresh even on partial failure: some independent RPCs may have committed.
    await _loadUsers();
    if (ref.mounted) {
      state = AsyncValue.data(
        (state.value ?? latest).copyWith(bulkUpdatingRole: null),
      );
    }
    return result;
  }

  int _sortUsers(AdminUserListItem a, AdminUserListItem b, String sortKey) {
    switch (sortKey) {
      case 'name_desc':
        return b.name.toLowerCase().compareTo(a.name.toLowerCase());
      case 'role':
        final roleCompare = a.role.compareTo(b.role);
        if (roleCompare != 0) return roleCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case 'newest':
        final aDate = DateTime.tryParse(a.createdAt ?? '');
        final bDate = DateTime.tryParse(b.createdAt ?? '');
        if (aDate != null && bDate != null) return bDate.compareTo(aDate);
        if (aDate != null) return -1;
        if (bDate != null) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case 'online':
      default:
        if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
        if (a.role != b.role) return a.role.compareTo(b.role);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }
  }
}
