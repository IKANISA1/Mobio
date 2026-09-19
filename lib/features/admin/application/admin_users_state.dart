import 'package:mobi_shared_types/models/admin/admin_models.dart';

const Object _unset = Object();

class AdminRoleUpdateResult {
  const AdminRoleUpdateResult({
    required this.updatedCount,
    required this.failedIds,
    required this.skippedCount,
  });

  final int updatedCount;
  final Set<String> failedIds;
  final int skippedCount;
}

class AdminUsersState {
  final List<AdminUserListItem> users;
  final Set<String> selectedIds;
  final bool isLoading;
  final String? loadError;
  final String? updatingUserId;
  final String? bulkUpdatingRole;
  final String roleFilter;
  final String searchQuery;
  final String sortKey;
  final int page;
  final int rowsPerPage;
  final bool hasNextPage;

  const AdminUsersState({
    this.users = const [],
    this.selectedIds = const {},
    this.isLoading = true,
    this.loadError,
    this.updatingUserId,
    this.bulkUpdatingRole,
    this.roleFilter = 'all',
    this.searchQuery = '',
    this.sortKey = 'online',
    this.page = 0,
    this.rowsPerPage = 25,
    this.hasNextPage = false,
  });

  AdminUsersState copyWith({
    List<AdminUserListItem>? users,
    Set<String>? selectedIds,
    bool? isLoading,
    Object? loadError = _unset,
    Object? updatingUserId = _unset,
    Object? bulkUpdatingRole = _unset,
    String? roleFilter,
    String? searchQuery,
    String? sortKey,
    int? page,
    int? rowsPerPage,
    bool? hasNextPage,
  }) {
    return AdminUsersState(
      users: users ?? this.users,
      selectedIds: selectedIds ?? this.selectedIds,
      isLoading: isLoading ?? this.isLoading,
      loadError: identical(loadError, _unset)
          ? this.loadError
          : loadError as String?,
      updatingUserId: identical(updatingUserId, _unset)
          ? this.updatingUserId
          : updatingUserId as String?,
      bulkUpdatingRole: identical(bulkUpdatingRole, _unset)
          ? this.bulkUpdatingRole
          : bulkUpdatingRole as String?,
      roleFilter: roleFilter ?? this.roleFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      sortKey: sortKey ?? this.sortKey,
      page: page ?? this.page,
      rowsPerPage: rowsPerPage ?? this.rowsPerPage,
      hasNextPage: hasNextPage ?? this.hasNextPage,
    );
  }

  int get paginationTotal =>
      page * rowsPerPage + users.length + (hasNextPage ? 1 : 0);
}
