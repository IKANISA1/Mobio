import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/admin_service.dart';
import 'package:mobi_app/features/admin/models/admin_users_state.dart';

final adminUsersProvider = AsyncNotifierProvider.autoDispose<
  AdminUsersController,
  AdminUsersState
>(AdminUsersController.new);

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
  }) async {
    final role = roleFilter ?? state.value?.roleFilter ?? 'all';
    final query = searchQuery ?? state.value?.searchQuery ?? '';

    try {
      final users = await _adminService.listUsers(
        role: role == 'all' ? null : role,
        search: query.trim().isEmpty ? null : query.trim(),
        limit: 120,
      );

      final sortedUsers = [...users]..sort(_sortUsers);
      final currentSelectedIds = state.value?.selectedIds ?? <String>{};

      return AdminUsersState(
        users: sortedUsers,
        selectedIds: currentSelectedIds.intersection(
          sortedUsers.map((u) => u.id).toSet(),
        ),
        isLoading: false,
        roleFilter: role,
        searchQuery: query,
      );
    } catch (error) {
      return AdminUsersState(
        isLoading: false,
        loadError: error.toString(),
        roleFilter: role,
        searchQuery: query,
      );
    }
  }

  void onSearchChanged(String query) {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(searchQuery: query));

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () async {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() => _fetchUsers(searchQuery: query));
    });
  }

  void onRoleFilterChanged(String role) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchUsers(roleFilter: role));
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchUsers());
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

  Future<void> updateSingleUserRole(AdminUserListItem user, String nextRole) async {
    final currentState = state.value;
    if (currentState == null) return;
    if (_adminService.currentUserId == user.id || user.role == nextRole) return;

    state = AsyncValue.data(currentState.copyWith(updatingUserId: user.id));

    try {
      await _adminService.updateUserRole(userId: user.id, role: nextRole);
      final newState = await _fetchUsers();
      state = AsyncValue.data(newState.copyWith(updatingUserId: null));
    } catch (error) {
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(finalState.copyWith(
          updatingUserId: null,
          loadError: error.toString(),
        ));
      }
      rethrow;
    }
  }

  Future<void> applyRoleToSelected(String role) async {
    final currentState = state.value;
    if (currentState == null) return;

    final currentUserId = _adminService.currentUserId;
    final targetIds = currentState.selectedIds.where((id) => id != currentUserId).toList();
    if (targetIds.isEmpty) return;

    state = AsyncValue.data(currentState.copyWith(bulkUpdatingRole: role));

    try {
      await Future.wait(
        targetIds.map((id) => _adminService.updateUserRole(userId: id, role: role)),
      );
      final newState = await _fetchUsers();
      state = AsyncValue.data(newState.copyWith(
        bulkUpdatingRole: null,
        selectedIds: {},
      ));
    } catch (error) {
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(finalState.copyWith(bulkUpdatingRole: null));
      }
      rethrow;
    }
  }

  int _sortUsers(AdminUserListItem a, AdminUserListItem b) {
    if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
    if (a.role != b.role) return a.role.compareTo(b.role);
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }
}
