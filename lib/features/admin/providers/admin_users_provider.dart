import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/admin_service.dart';
import 'package:mobi_app/features/admin/models/admin_users_state.dart';

final adminUsersProvider =
    AsyncNotifierProvider.autoDispose<AdminUsersController, AdminUsersState>(
      AdminUsersController.new,
    );

class AdminUsersController extends AsyncNotifier<AdminUsersState> {
  AdminService get _adminService => ref.read(adminServiceProvider);
  Timer? _searchDebounce;

  @override
  FutureOr<AdminUsersState> build() async {
    ref.onDispose(() {
      _searchDebounce?.cancel();
    });

    return _fetchUsers();
  }

  Future<AdminUsersState> _fetchUsers({
    String? roleFilter,
    String? searchQuery,
    int? page,
    int? rowsPerPage,
  }) async {
    final role = roleFilter ?? state.value?.roleFilter ?? 'all';
    final query = searchQuery ?? state.value?.searchQuery ?? '';
    final sortKey = state.value?.sortKey ?? 'online';
    final safeRowsPerPage = rowsPerPage ?? state.value?.rowsPerPage ?? 25;
    final safePage = page ?? state.value?.page ?? 0;

    try {
      final users = await _adminService.listUsers(
        role: role == 'all' ? null : role,
        search: query.trim().isEmpty ? null : query.trim(),
        limit: safeRowsPerPage + 1,
        offset: safePage * safeRowsPerPage,
      );

      final hasNextPage = users.length > safeRowsPerPage;
      final sortedUsers = users.take(safeRowsPerPage).toList()
        ..sort((a, b) => _sortUsers(a, b, sortKey));
      final currentSelectedIds = state.value?.selectedIds ?? <String>{};

      return AdminUsersState(
        users: sortedUsers,
        selectedIds: currentSelectedIds.intersection(
          sortedUsers.map((u) => u.id).toSet(),
        ),
        isLoading: false,
        roleFilter: role,
        searchQuery: query,
        sortKey: sortKey,
        page: safePage,
        rowsPerPage: safeRowsPerPage,
        hasNextPage: hasNextPage,
      );
    } on Object catch (error) {
      return AdminUsersState(
        isLoading: false,
        loadError: error.toString(),
        roleFilter: role,
        searchQuery: query,
        sortKey: sortKey,
        page: safePage,
        rowsPerPage: safeRowsPerPage,
      );
    }
  }

  void onSearchChanged(String query) {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(searchQuery: query, page: 0));

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () async {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(
        () => _fetchUsers(searchQuery: query, page: 0),
      );
    });
  }

  Future<void> onRoleFilterChanged(String role) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _fetchUsers(roleFilter: role, page: 0),
    );
  }

  void setSortKey(String sortKey) {
    final currentState = state.value;
    if (currentState == null || currentState.sortKey == sortKey) return;

    final sortedUsers = [...currentState.users]
      ..sort((a, b) => _sortUsers(a, b, sortKey));
    state = AsyncValue.data(
      currentState.copyWith(users: sortedUsers, sortKey: sortKey, page: 0),
    );
  }

  Future<void> setPage(int page) async {
    final currentState = state.value;
    if (currentState == null) return;

    final nextPage = page < 0 ? 0 : page;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchUsers(page: nextPage));
  }

  Future<void> setRowsPerPage(int rowsPerPage) async {
    final currentState = state.value;
    if (currentState == null || rowsPerPage <= 0) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _fetchUsers(rowsPerPage: rowsPerPage, page: 0),
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchUsers);
  }

  void toggleSelection(String userId, bool isSelected) {
    final currentState = state.value;
    if (currentState == null) return;

    final newSelectedIds = Set<String>.from(currentState.selectedIds);
    if (isSelected) {
      newSelectedIds.add(userId);
    } else {
      newSelectedIds.remove(userId);
    }

    state = AsyncValue.data(currentState.copyWith(selectedIds: newSelectedIds));
  }

  void toggleSelectAll(bool isSelected) {
    final currentState = state.value;
    if (currentState == null) return;

    final newSelectedIds = isSelected
        ? currentState.users.map((u) => u.id).toSet()
        : <String>{};

    state = AsyncValue.data(currentState.copyWith(selectedIds: newSelectedIds));
  }

  void toggleSelectionFor(Iterable<String> userIds, bool isSelected) {
    final currentState = state.value;
    if (currentState == null) return;

    final newSelectedIds = Set<String>.from(currentState.selectedIds);
    if (isSelected) {
      newSelectedIds.addAll(userIds);
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

    state = AsyncValue.data(currentState.copyWith(updatingUserId: user.id));

    try {
      await _adminService.updateUserRole(userId: user.id, role: nextRole);
      final newState = await _fetchUsers();
      state = AsyncValue.data(newState.copyWith(updatingUserId: null));
    } on Object catch (error) {
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(
          finalState.copyWith(
            updatingUserId: null,
            loadError: error.toString(),
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> applyRoleToSelected(String role) async {
    final currentState = state.value;
    if (currentState == null) return;

    final currentUserId = _adminService.currentUserId;
    final targetIds = currentState.selectedIds
        .where((id) => id != currentUserId)
        .toList();
    if (targetIds.isEmpty) return;

    state = AsyncValue.data(currentState.copyWith(bulkUpdatingRole: role));

    try {
      await Future.wait(
        targetIds.map(
          (id) => _adminService.updateUserRole(userId: id, role: role),
        ),
      );
      final newState = await _fetchUsers();
      state = AsyncValue.data(
        newState.copyWith(bulkUpdatingRole: null, selectedIds: {}),
      );
    } on Object {
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(finalState.copyWith(bulkUpdatingRole: null));
      }
      rethrow;
    }
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
