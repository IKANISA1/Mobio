import 'package:mobi_app/core/services/admin_service.dart';

class AdminUsersState {
  final List<AdminUserListItem> users;
  final Set<String> selectedIds;
  final bool isLoading;
  final String? loadError;
  final String? updatingUserId;
  final String? bulkUpdatingRole;
  final String roleFilter;
  final String searchQuery;

  const AdminUsersState({
    this.users = const [],
    this.selectedIds = const {},
    this.isLoading = true,
    this.loadError,
    this.updatingUserId,
    this.bulkUpdatingRole,
    this.roleFilter = 'all',
    this.searchQuery = '',
  });

  AdminUsersState copyWith({
    List<AdminUserListItem>? users,
    Set<String>? selectedIds,
    bool? isLoading,
    String? loadError,
    String? updatingUserId,
    String? bulkUpdatingRole,
    String? roleFilter,
    String? searchQuery,
  }) {
    return AdminUsersState(
      users: users ?? this.users,
      selectedIds: selectedIds ?? this.selectedIds,
      isLoading: isLoading ?? this.isLoading,
      loadError: loadError ?? this.loadError,
      updatingUserId: updatingUserId ?? this.updatingUserId,
      bulkUpdatingRole: bulkUpdatingRole ?? this.bulkUpdatingRole,
      roleFilter: roleFilter ?? this.roleFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}
