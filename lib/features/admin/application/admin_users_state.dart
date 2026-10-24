import 'package:mobi_app/features/admin/domain/admin_role_change.dart';
import 'package:mobi_app/features/admin/domain/admin_role_recovery.dart';
import 'package:mobi_shared_types/models/admin/admin_models.dart';

export 'package:mobi_app/features/admin/domain/admin_role_change.dart';
export 'package:mobi_app/features/admin/domain/admin_role_recovery.dart';

const Object _unset = Object();

/// Read pagination and durable role outcomes have independent lifetimes.
class AdminUsersState {
  final List<AdminUserListItem> users;
  final Map<String, int> roleRevisions;
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
  final String? snapshotId;
  final DateTime? asOf;
  final DateTime? expiresAt;
  final int? totalExact;
  final bool snapshotExpired;
  final Duration snapshotAge;
  final Duration reviewRemaining;
  final AdminRoleReview? roleReview;
  final AdminRoleBatchEnvelope? roleEnvelope;
  final List<AdminRoleRecipientOutcome> roleOutcomes;
  final AdminRoleRecoveryPhase recoveryPhase;
  final String? recoveryError;

  /// Retains a journaled token even when reserve returned no batch/envelope.
  final String? outstandingReservationId;

  const AdminUsersState({
    this.users = const [],
    this.roleRevisions = const {},
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
    this.snapshotId,
    this.asOf,
    this.expiresAt,
    this.totalExact,
    this.snapshotExpired = true,
    this.snapshotAge = Duration.zero,
    this.reviewRemaining = Duration.zero,
    this.roleReview,
    this.roleEnvelope,
    this.roleOutcomes = const [],
    this.recoveryPhase = AdminRoleRecoveryPhase.checking,
    this.recoveryError,
    this.outstandingReservationId,
  });

  /// Label as "snapshot age up to"; measured from server + full round trip.
  bool get snapshotAgeIsUpperBound => true;
  bool get roleWorkSealed => roleEnvelope?.isSealed ?? false;
  bool get canChangeQuery =>
      recoveryPhase != AdminRoleRecoveryPhase.reserving &&
      recoveryPhase != AdminRoleRecoveryPhase.submitting &&
      bulkUpdatingRole == null &&
      updatingUserId == null;
  bool get canPrepareReview =>
      recoveryPhase == AdminRoleRecoveryPhase.ready &&
      roleReview == null &&
      !isLoading &&
      loadError == null &&
      !snapshotExpired &&
      snapshotId != null &&
      updatingUserId == null;
  bool get reviewCanConfirm =>
      recoveryPhase == AdminRoleRecoveryPhase.ready &&
      roleReview != null &&
      !isLoading &&
      !snapshotExpired &&
      roleReview!.snapshotId == snapshotId &&
      updatingUserId == null;
  bool get canReconcile =>
      recoveryPhase == AdminRoleRecoveryPhase.unresolved ||
      recoveryPhase == AdminRoleRecoveryPhase.blocked;
  bool get canCloseOutstanding =>
      canReconcile &&
      (outstandingReservationId != null || roleEnvelope?.reservationId != null);
  AdminRoleOutcomeCounts get roleOutcomeCounts =>
      AdminRoleOutcomeCounts(roleOutcomes);
  int get paginationTotal => totalExact ?? 0;

  AdminUsersState copyWith({
    List<AdminUserListItem>? users,
    Map<String, int>? roleRevisions,
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
    Object? snapshotId = _unset,
    Object? asOf = _unset,
    Object? expiresAt = _unset,
    Object? totalExact = _unset,
    bool? snapshotExpired,
    Duration? snapshotAge,
    Duration? reviewRemaining,
    Object? roleReview = _unset,
    Object? roleEnvelope = _unset,
    List<AdminRoleRecipientOutcome>? roleOutcomes,
    AdminRoleRecoveryPhase? recoveryPhase,
    Object? recoveryError = _unset,
    Object? outstandingReservationId = _unset,
  }) => AdminUsersState(
    users: users ?? this.users,
    roleRevisions: roleRevisions ?? this.roleRevisions,
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
    snapshotId: identical(snapshotId, _unset)
        ? this.snapshotId
        : snapshotId as String?,
    asOf: identical(asOf, _unset) ? this.asOf : asOf as DateTime?,
    expiresAt: identical(expiresAt, _unset)
        ? this.expiresAt
        : expiresAt as DateTime?,
    totalExact: identical(totalExact, _unset)
        ? this.totalExact
        : totalExact as int?,
    snapshotExpired: snapshotExpired ?? this.snapshotExpired,
    snapshotAge: snapshotAge ?? this.snapshotAge,
    reviewRemaining: reviewRemaining ?? this.reviewRemaining,
    roleReview: identical(roleReview, _unset)
        ? this.roleReview
        : roleReview as AdminRoleReview?,
    roleEnvelope: identical(roleEnvelope, _unset)
        ? this.roleEnvelope
        : roleEnvelope as AdminRoleBatchEnvelope?,
    roleOutcomes: roleOutcomes ?? this.roleOutcomes,
    recoveryPhase: recoveryPhase ?? this.recoveryPhase,
    recoveryError: identical(recoveryError, _unset)
        ? this.recoveryError
        : recoveryError as String?,
    outstandingReservationId: identical(outstandingReservationId, _unset)
        ? this.outstandingReservationId
        : outstandingReservationId as String?,
  );
}
