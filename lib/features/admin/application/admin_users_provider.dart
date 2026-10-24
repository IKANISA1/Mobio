import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/auth/account_action_token.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/admin/application/admin_services.dart';
import 'package:mobi_app/features/admin/application/admin_users_state.dart';
import 'package:mobi_app/features/admin/data/admin_role_change_journal.dart';
import 'package:mobi_app/features/admin/data/admin_service.dart';
import 'package:mobi_app/features/admin/domain/admin_user_protocol.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

final adminUsersProvider =
    AsyncNotifierProvider.autoDispose<AdminUsersController, AdminUsersState>(
      AdminUsersController.new,
    );
final adminRoleJournalProvider = Provider<AdminRoleJournal>(
  (ref) => AdminRoleChangeJournal(),
);
final adminUsersElapsedProvider = Provider<Duration Function()>((ref) {
  final clock = Stopwatch()..start();
  ref.onDispose(clock.stop);
  return () => clock.elapsed;
});
final adminUsersAccountProvider = Provider<AccountSnapshot? Function()>(
  (ref) => () {
    try {
      return AccountContext.capture();
    } on Object {
      return null;
    }
  },
);
final adminUsersAccountRevisionProvider = Provider<int Function()>(
  (ref) =>
      () => AccountContext.changes.value,
);

class AdminUsersController extends AsyncNotifier<AdminUsersState> {
  AdminService get _service => ref.read(adminServiceProvider);
  AdminRoleJournal get _journal => ref.read(adminRoleJournalProvider);
  Duration Function() get _elapsed => ref.read(adminUsersElapsedProvider);
  Timer? _searchDebounce;
  Timer? _clockUpdates;
  int _requestVersion = 0;
  AccountSnapshot? _account;
  AccountActionToken? _ownerToken;
  AdminRoleRecoveryPointer? _pointer;
  AdminMonotonicDeadline? _snapshotDeadline;
  AdminMonotonicDeadline? _executeDeadline;
  final _batchEvidence = <String, AdminRoleBatchEnvelope>{};
  final _ownedSnapshots = <String>{};
  final _releases = <String, Future<void>>{};

  @override
  Future<AdminUsersState> build() async {
    _account = ref.read(adminUsersAccountProvider)();
    _ownerToken = AccountActionToken.capture(
      captureAccount: ref.read(adminUsersAccountProvider),
      readRevision: ref.read(adminUsersAccountRevisionProvider),
      captureReview: () => null,
    );
    AccountContext.changes.addListener(_accountChanged);
    ref.onDispose(() {
      _requestVersion++;
      _searchDebounce?.cancel();
      _clockUpdates?.cancel();
      AccountContext.changes.removeListener(_accountChanged);
    });
    if (!_isCurrent) {
      return const AdminUsersState(
        isLoading: false,
        loadError: 'Sign in again to load members.',
        recoveryPhase: AdminRoleRecoveryPhase.blocked,
        recoveryError: 'Your account session is unavailable.',
      );
    }
    var initial = const AdminUsersState();
    try {
      final started = _elapsed();
      final page = await _service.listUsersPage(_query(initial));
      _requireCurrent();
      _ownedSnapshots.add(page.snapshotId);
      _setSnapshotDeadline(page, started);
      initial = _withPage(initial, page);
    } on Object {
      initial = initial.copyWith(
        isLoading: false,
        loadError: 'Unable to load members. Refresh and try again.',
      );
    }
    initial = await _recoverState(initial);
    if (!_isCurrent) {
      return const AdminUsersState(
        isLoading: false,
        recoveryPhase: AdminRoleRecoveryPhase.blocked,
        recoveryError: 'Your account session changed. Sign in again.',
      );
    }
    _clockUpdates = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateClock(),
    );
    return initial;
  }

  bool get _isCurrent {
    if (!ref.mounted || _account == null || _ownerToken?.isCurrent != true) {
      return false;
    }
    final current = ref.read(adminUsersAccountProvider)();
    return current?.identity == _account!.identity &&
        current?.generation == _account!.generation &&
        _service.currentUserId == _account!.userId &&
        _service.currentSessionId == _account!.sessionId;
  }

  void _requireCurrent() {
    if (!_isCurrent) throw const StaleAccountWork();
  }

  void _accountChanged() {
    if (_isCurrent || !ref.mounted) return;
    _requestVersion++;
    _searchDebounce?.cancel();
    _clockUpdates?.cancel();
    _snapshotDeadline = null;
    _executeDeadline = null;
    _pointer = null;
    _batchEvidence.clear();
    _ownedSnapshots.clear();
    _releases.clear();
    final current = state.value;
    if (current != null) {
      // Never render the former actor's rows or receipts in a replacement account.
      state = AsyncValue.data(
        current.copyWith(
          users: [],
          roleRevisions: {},
          selectedIds: {},
          roleReview: null,
          roleEnvelope: null,
          roleOutcomes: [],
          outstandingReservationId: null,
          snapshotId: null,
          totalExact: null,
          asOf: null,
          expiresAt: null,
          snapshotExpired: true,
          isLoading: false,
          updatingUserId: null,
          bulkUpdatingRole: null,
          recoveryPhase: AdminRoleRecoveryPhase.blocked,
          recoveryError: 'Your account session changed. Sign in again.',
        ),
      );
    }
  }

  AdminUserQuery _query(AdminUsersState request) => AdminUserQuery(
    role: request.roleFilter,
    search: request.searchQuery,
    sort: request.sortKey,
    pageSize: request.rowsPerPage,
    snapshotId: request.snapshotId,
    offset: request.page * request.rowsPerPage,
  );

  void _setSnapshotDeadline(AdminUserPage page, Duration started) {
    _snapshotDeadline = AdminMonotonicDeadline(
      serverNow: page.serverNow,
      expiresAt: page.expiresAt,
      requestStarted: started,
      responseReceived: _elapsed(),
      elapsed: _elapsed,
    );
  }

  AdminUsersState _withPage(AdminUsersState current, AdminUserPage page) =>
      current.copyWith(
        users: page.rows.map((row) => row.user).toList(growable: false),
        roleRevisions: Map.unmodifiable({
          for (final row in page.rows) row.user.id: row.roleRevision,
        }),
        selectedIds: current.selectedIds.intersection(
          page.rows.map((row) => row.user.id).toSet(),
        ),
        isLoading: false,
        loadError: null,
        hasNextPage: page.hasNextPage,
        snapshotId: page.snapshotId,
        asOf: page.asOf,
        expiresAt: page.expiresAt,
        totalExact: page.totalExact,
        snapshotExpired: _snapshotDeadline?.expired ?? true,
        reviewRemaining: _snapshotDeadline?.remaining ?? Duration.zero,
        snapshotAge:
            _snapshotDeadline?.ageUpperBound(page.asOf) ?? Duration.zero,
      );

  void _updateClock() {
    if (!_isCurrent) {
      _accountChanged();
      return;
    }
    final current = state.value;
    if (current == null || _snapshotDeadline == null) return;
    state = AsyncValue.data(
      current.copyWith(
        snapshotExpired: _snapshotDeadline!.expired,
        reviewRemaining: _snapshotDeadline!.remaining,
        snapshotAge: current.asOf == null
            ? Duration.zero
            : _snapshotDeadline!.ageUpperBound(current.asOf!),
      ),
    );
  }

  // Retain the captured handle until release is proven, but never expose its
  // former count or rows as evidence for the pending normalized query.
  AdminUsersState _pendingFreshQuery(AdminUsersState current) =>
      current.copyWith(
        page: 0,
        users: [],
        asOf: null,
        expiresAt: null,
        totalExact: null,
        snapshotExpired: true,
        reviewRemaining: Duration.zero,
        snapshotAge: Duration.zero,
        selectedIds: {},
        roleRevisions: {},
        hasNextPage: false,
        roleReview: current.recoveryPhase == AdminRoleRecoveryPhase.ready
            ? null
            : current.roleReview,
        isLoading: true,
        loadError: null,
      );

  Future<void> _releaseSnapshot(String snapshotId) {
    final pending = _releases[snapshotId];
    if (pending != null) return pending;
    final work = () async {
      await _service.releaseUsersSnapshot(snapshotId);
      _requireCurrent();
      _ownedSnapshots.remove(snapshotId);
    }();
    _releases[snapshotId] = work;
    return work.whenComplete(() {
      if (identical(_releases[snapshotId], work)) _releases.remove(snapshotId);
    });
  }

  ({AdminUsersState request, int version}) _beginFreshQuery(
    AdminUsersState request,
  ) {
    _snapshotDeadline = null;
    final pending = _pendingFreshQuery(request);
    final version = ++_requestVersion;
    state = AsyncValue.data(pending);
    return (request: pending, version: version);
  }

  Future<void> _runFreshQuery(AdminUsersState request, int version) async {
    try {
      // Includes a superseded fresh response whose earlier release was uncertain.
      for (final handle in List<String>.of(_ownedSnapshots)) {
        await _releaseSnapshot(handle);
        if (!_isCurrent || version != _requestVersion) return;
      }
      if (!_isCurrent || version != _requestVersion) return;
      final fresh = (state.value ?? request).copyWith(snapshotId: null);
      await _loadUsers(fresh, requestVersion: version);
    } on Object {
      if (!_isCurrent || version != _requestVersion) return;
      state = AsyncValue.data(
        (state.value ?? request).copyWith(
          isLoading: false,
          loadError:
              'Unable to release the previous member snapshot. Refresh to retry.',
        ),
      );
    }
  }

  Future<void> _startFreshQuery(AdminUsersState request) async {
    if (!_isCurrent || !request.canChangeQuery) return;
    final pending = _beginFreshQuery(request);
    await _runFreshQuery(pending.request, pending.version);
  }

  Future<void> _loadUsers(
    AdminUsersState request, {
    int? requestVersion,
  }) async {
    _requireCurrent();
    final version = requestVersion ?? ++_requestVersion;
    state = AsyncValue.data(request.copyWith(isLoading: true, loadError: null));
    final started = _elapsed();
    try {
      final result = await _service.listUsersPage(_query(request));
      if (!_isCurrent) return;
      _ownedSnapshots.add(result.snapshotId);
      if (version != _requestVersion) {
        // A superseded fresh query minted its own cache. Release that exact
        // handle; a failed cleanup remains owned for the next controlled retry.
        if (request.snapshotId == null &&
            result.snapshotId != state.value?.snapshotId) {
          try {
            await _releaseSnapshot(result.snapshotId);
          } on Object {
            // Preserve its handle without replacing the newer query's state.
          }
        }
        return;
      }
      _setSnapshotDeadline(result, started);
      final current = state.value ?? request;
      state = AsyncValue.data(_withPage(current, result));
    } on Object catch (error) {
      if (!_isCurrent || version != _requestVersion) return;
      final expired =
          error is PostgrestException &&
          error.message == 'ADMIN_USERS_SNAPSHOT_EXPIRED';
      state = AsyncValue.data(
        (state.value ?? request).copyWith(
          users: [],
          roleRevisions: {},
          selectedIds: {},
          isLoading: false,
          hasNextPage: false,
          totalExact: null,
          snapshotExpired: true,
          loadError: expired
              ? 'This member snapshot expired. Refresh to load current results.'
              : 'Unable to load members. Refresh and try again.',
        ),
      );
    }
  }

  void onSearchChanged(String query) {
    final current = state.value;
    if (current == null || !_isCurrent || !current.canChangeQuery) return;
    _searchDebounce?.cancel();
    final pending = _beginFreshQuery(current.copyWith(searchQuery: query));
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (_isCurrent && pending.version == _requestVersion) {
        unawaited(_runFreshQuery(pending.request, pending.version));
      }
    });
  }

  Future<void> onRoleFilterChanged(String role) async {
    _searchDebounce?.cancel();
    final current = state.value;
    if (current == null || !current.canChangeQuery) return;
    await _startFreshQuery(current.copyWith(roleFilter: role));
  }

  Future<void> setSortKey(String sortKey) async {
    _searchDebounce?.cancel();
    final current = state.value;
    if (current == null ||
        !current.canChangeQuery ||
        current.sortKey == sortKey) {
      return;
    }
    await _startFreshQuery(current.copyWith(sortKey: sortKey));
  }

  Future<void> setPage(int page) async {
    final current = state.value;
    if (current == null ||
        !current.canChangeQuery ||
        current.isLoading ||
        page < 0) {
      return;
    }
    _searchDebounce?.cancel();
    if (_snapshotDeadline?.expired != false ||
        current.snapshotId == null ||
        (current.totalExact != 0 &&
            page * current.rowsPerPage >= (current.totalExact ?? 0))) {
      throw const ValidationException(
        message: 'Refresh this member snapshot before navigating.',
      );
    }
    await _loadUsers(current.copyWith(page: page, selectedIds: {}));
  }

  Future<void> setRowsPerPage(int size) async {
    _searchDebounce?.cancel();
    final current = state.value;
    if (current == null ||
        !current.canChangeQuery ||
        current.rowsPerPage == size) {
      return;
    }
    await _startFreshQuery(current.copyWith(rowsPerPage: size));
  }

  Future<void> refresh() async {
    _searchDebounce?.cancel();
    final current = state.value;
    if (current != null && current.canChangeQuery) {
      await _startFreshQuery(current);
    }
  }

  void toggleSelection(String id, bool selected) =>
      toggleSelectionFor([id], selected);
  void toggleSelectAll(bool selected) {
    final current = state.value;
    if (current == null) return;
    toggleSelectionFor(current.users.map((user) => user.id), selected);
  }

  void toggleSelectionFor(Iterable<String> ids, bool selected) {
    final current = state.value;
    if (current == null || current.isLoading || !_isCurrent) return;
    final next = Set<String>.of(current.selectedIds);
    final visible = current.users.map((user) => user.id).toSet();
    if (selected) {
      next.addAll(ids.where(visible.contains));
    } else {
      next.removeAll(ids);
    }
    state = AsyncValue.data(
      current.copyWith(selectedIds: Set.unmodifiable(next)),
    );
  }

  AdminRoleReview prepareRoleReview(String role, {Set<String>? targetIds}) {
    _requireCurrent();
    _updateClock();
    final current = state.value;
    if (current == null ||
        !current.canPrepareReview ||
        !AdminUserProtocol.roles.contains(role)) {
      throw const ValidationException(
        message: 'Refresh or finish the current review before changing roles.',
      );
    }
    final ids = targetIds ?? current.selectedIds;
    final rows = current.users
        .where((user) => ids.contains(user.id))
        .toList(growable: false);
    if (rows.isEmpty ||
        rows.length != ids.length ||
        rows.length > 100 ||
        rows.any((row) => !current.roleRevisions.containsKey(row.id))) {
      throw const ValidationException(
        message: 'Select members from this snapshot page.',
      );
    }
    final reservation = AdminRoleChangeJournal.newReservationId();
    final review = AdminRoleReview(
      reviewId: reservation,
      reservationId: reservation,
      actorId: _account!.userId,
      sessionId: _account!.sessionId,
      snapshotId: current.snapshotId!,
      requestedRole: role,
      entries: rows
          .map(
            (user) => AdminRoleReviewEntry(
              targetId: user.id,
              displayLabel: user.name,
              memberId: user.memberId,
              expectedRole: user.role,
              expectedRevision: current.roleRevisions[user.id]!,
              expectedIsDriver: user.isDriver,
              requestedRole: role,
              requestedIsDriver: role == 'driver',
              skipReason: user.id == _account!.userId
                  ? AdminRoleSkipReason.self
                  : user.role == role
                  ? AdminRoleSkipReason.sameRole
                  : null,
            ),
          )
          .toList(growable: false),
    );
    state = AsyncValue.data(
      current.copyWith(roleReview: review, recoveryError: null),
    );
    return review;
  }

  void cancelRoleReview(String reviewId) {
    final current = state.value;
    if (current == null ||
        !_isCurrent ||
        current.roleReview?.reviewId != reviewId ||
        current.recoveryPhase != AdminRoleRecoveryPhase.ready) {
      return;
    }
    state = AsyncValue.data(current.copyWith(roleReview: null));
  }

  Future<void> confirmRoleReview(String reviewId) async {
    _requireCurrent();
    _updateClock();
    final current = state.value;
    final review = current?.roleReview;
    if (current == null ||
        !current.reviewCanConfirm ||
        review?.reviewId != reviewId) {
      throw const ValidationException(
        message: 'This role review is no longer available.',
      );
    }
    final plan = review!;
    _pointer = AdminRoleRecoveryPointer(
      owner: _service.roleRecoveryOwner,
      reservationId: plan.reservationId,
    );
    state = AsyncValue.data(
      current.copyWith(
        recoveryPhase: AdminRoleRecoveryPhase.reserving,
        outstandingReservationId: plan.reservationId,
        bulkUpdatingRole: plan.requestedRole,
        roleEnvelope: null,
        recoveryError: null,
        roleOutcomes: plan.entries
            .map(
              (entry) => AdminRoleRecipientOutcome(
                entry: entry,
                status: entry.skipReason == null
                    ? AdminRoleOutcomeStatus.notStarted
                    : AdminRoleOutcomeStatus.skipped,
              ),
            )
            .toList(growable: false),
      ),
    );
    try {
      await _journal.save(_pointer!, ownerIsCurrent: () => _isCurrent);
      _requireCurrent();
      if (_snapshotDeadline?.expired != false) {
        _block(
          'This review expired. Close its reservation before a new review.',
        );
        return;
      }
    } on Object {
      if (_isCurrent) {
        _block(
          'Recovery storage could not be verified. No role changes were submitted.',
        );
      }
      return;
    }
    final started = _elapsed();
    AdminRoleBatchEnvelope envelope;
    try {
      envelope = await _service.reserveRoleChange(plan);
      _requireCurrent();
      final batch = envelope.batch!;
      _executeDeadline = AdminMonotonicDeadline(
        serverNow: envelope.serverNow,
        expiresAt: batch.executeExpiresAt,
        requestStarted: started,
        responseReceived: _elapsed(),
        elapsed: _elapsed,
      );
      _applyEnvelope(envelope);
      _pointer = _pointer!.withOperation(batch.batchId, null);
      await _journal.save(_pointer!, ownerIsCurrent: () => _isCurrent);
      _requireCurrent();
    } on Object catch (error) {
      if (!_isCurrent) return;
      if (error is MutationOutcomeUnknownException) {
        _markAllEligible(AdminRoleOutcomeStatus.unknown);
        _block(
          'The reservation outcome is unknown. Reconcile or close it before another review.',
          unresolved: true,
        );
      } else {
        _block(
          'The reservation could not be completed. Reconcile or close it before another review.',
        );
      }
      return;
    }
    for (final operation in envelope.operations) {
      if (operation.status != AdminRoleOperationStatus.prepared) continue;
      if (!_isCurrent) return;
      if (_executeDeadline?.expired != false) {
        _block(
          'This batch expired. Close it before another review.',
          unresolved: true,
        );
        return;
      }
      try {
        _pointer = _pointer!.withOperation(
          envelope.batch!.batchId,
          operation.operationId,
        );
        await _journal.save(_pointer!, ownerIsCurrent: () => _isCurrent);
        _requireCurrent();
      } on Object {
        if (_isCurrent) {
          _block(
            'Recovery storage could not be verified. Remaining role changes were not submitted.',
          );
        }
        return;
      }
      _mark(operation.operationId, AdminRoleOutcomeStatus.submitting);
      try {
        final result = await _service.executeRoleChange(
          envelope: envelope,
          operationId: operation.operationId,
        );
        if (!_isCurrent) return;
        _applyEnvelope(result);
        envelope = result;
        final resolved = result.operations.singleWhere(
          (item) => item.operationId == operation.operationId,
        );
        if (resolved.status == AdminRoleOperationStatus.prepared) {
          _mark(operation.operationId, AdminRoleOutcomeStatus.unknown);
          _block(
            'This role change is not confirmed. Reconcile or close the batch.',
            unresolved: true,
          );
          return;
        }
      } on Object catch (error) {
        if (!_isCurrent) return;
        final known =
            error is AdminReauthenticationRequiredException ||
            (error is PostgrestException &&
                {'42501', '22023', 'P0001'}.contains(error.code));
        _mark(
          operation.operationId,
          known
              ? AdminRoleOutcomeStatus.knownRejected
              : AdminRoleOutcomeStatus.unknown,
          rejectionCode: known
              ? (error is AdminReauthenticationRequiredException
                    ? 'reauthentication_required'
                    : 'request_rejected')
              : null,
        );
        _block(
          known
              ? 'This request was rejected. Close the batch before another review.'
              : 'A role change outcome is unknown. Reconcile or close the batch.',
          unresolved: true,
        );
        return;
      }
    }
    _block(
      'Review the recipient outcomes, then close this batch before another review.',
      unresolved: true,
    );
    if (_isCurrent) await refresh();
  }

  void _mark(
    String operationId,
    AdminRoleOutcomeStatus status, {
    String? rejectionCode,
  }) {
    final current = state.value;
    if (current == null || !_isCurrent) return;
    state = AsyncValue.data(
      current.copyWith(
        recoveryPhase: status == AdminRoleOutcomeStatus.submitting
            ? AdminRoleRecoveryPhase.submitting
            : current.recoveryPhase,
        roleOutcomes: current.roleOutcomes
            .map(
              (item) => item.operationId == operationId
                  ? AdminRoleRecipientOutcome(
                      entry: item.entry,
                      operationId: item.operationId,
                      status: status,
                      rejectionCode: rejectionCode,
                    )
                  : item,
            )
            .toList(growable: false),
      ),
    );
  }

  void _markAllEligible(AdminRoleOutcomeStatus status) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(
        roleOutcomes: current.roleOutcomes
            .map(
              (item) => item.entry.skipReason == null
                  ? item.withStatus(status)
                  : item,
            )
            .toList(growable: false),
      ),
    );
  }

  void _block(String message, {bool unresolved = false}) {
    if (!_isCurrent || state.value == null) return;
    state = AsyncValue.data(
      state.value!.copyWith(
        bulkUpdatingRole: null,
        recoveryPhase: unresolved
            ? AdminRoleRecoveryPhase.unresolved
            : AdminRoleRecoveryPhase.blocked,
        recoveryError: message,
      ),
    );
  }

  AdminUsersState _envelopeState(
    AdminUsersState current,
    AdminRoleBatchEnvelope envelope, {
    bool recovering = false,
  }) {
    if (envelope.batch != null) {
      final previous = _batchEvidence[envelope.reservationId];
      if (previous != null && !envelope.continues(previous)) {
        throw const FormatException(
          'Admin recovery immutable evidence changed.',
        );
      }
      _batchEvidence[envelope.reservationId!] = envelope;
    }
    final prior = {
      for (final item in current.roleOutcomes) item.entry.targetId: item,
    };
    final outcomes = envelope.operations
        .map((operation) {
          var old = prior[operation.entry.targetId];
          if (recovering &&
              operation.status == AdminRoleOperationStatus.prepared &&
              (old?.operationId != operation.operationId ||
                  _pointer?.operationId == operation.operationId)) {
            old = AdminRoleRecipientOutcome(
              entry: operation.entry,
              operationId: operation.operationId,
              status: AdminRoleOutcomeStatus.unknown,
            );
          }
          return AdminRoleRecipientOutcome.fromOperation(
            operation,
            previous: old,
          );
        })
        .toList(growable: false);
    if (envelope.reservationState ==
        AdminRoleReservationState.sealedBeforeReserve) {
      final reviewed =
          current.roleReview?.reservationId == envelope.reservationId;
      return current.copyWith(
        roleEnvelope: envelope,
        roleOutcomes: reviewed
            ? current.roleReview!.entries
                  .map(
                    (entry) => AdminRoleRecipientOutcome(
                      entry: entry,
                      status: entry.skipReason == null
                          ? AdminRoleOutcomeStatus.notStarted
                          : AdminRoleOutcomeStatus.skipped,
                    ),
                  )
                  .toList(growable: false)
            : current.roleOutcomes,
      );
    }
    return current.copyWith(roleEnvelope: envelope, roleOutcomes: outcomes);
  }

  void _applyEnvelope(AdminRoleBatchEnvelope envelope) {
    _requireCurrent();
    state = AsyncValue.data(_envelopeState(state.value!, envelope));
  }

  Future<AdminUsersState> _recoverState(AdminUsersState current) async {
    if (!_isCurrent) return current;
    try {
      _pointer ??= await _journal.load(_service.roleRecoveryOwner);
      _requireCurrent();
      final retained = _pointer;
      final lookup = await _service.roleChangeStatus(
        reservationId: retained?.reservationId,
      );
      _requireCurrent();
      // A terminal/absent older token says nothing about another tab's open
      // actor slot. Discover it independently before ever declaring ready.
      final discovered = retained == null
          ? lookup
          : await _service.roleChangeStatus();
      _requireCurrent();
      final open =
          discovered.reservationState == AdminRoleReservationState.reserved &&
          discovered.batch?.state == AdminRoleBatchState.open;
      if (retained != null && lookup.isSealed) {
        current = _envelopeState(current, lookup, recovering: true);
        await _journal.clear(
          retained.owner,
          retained.reservationId,
          ownerIsCurrent: () => _isCurrent,
        );
        _requireCurrent();
        _pointer = null;
        current = current.copyWith(
          roleReview: null,
          outstandingReservationId: null,
        );
      } else if (retained != null) {
        if (lookup.batch != null) {
          current = _envelopeState(current, lookup, recovering: true);
        }
        if (open && discovered.reservationId != retained.reservationId) {
          current = _envelopeState(current, discovered, recovering: true);
          return current.copyWith(
            outstandingReservationId: retained.reservationId,
            recoveryPhase: AdminRoleRecoveryPhase.unresolved,
            recoveryError:
                'An earlier reservation is uncertain and another batch is open. Close the earlier reservation first.',
          );
        }
        if (lookup.reservationState == AdminRoleReservationState.absent) {
          return current.copyWith(
            roleEnvelope: lookup,
            outstandingReservationId: retained.reservationId,
            recoveryPhase: AdminRoleRecoveryPhase.unresolved,
            recoveryError:
                'The reservation outcome is unknown. Close it to prevent a delayed submission.',
          );
        }
        current = _envelopeState(
          current,
          open && discovered.reservationId == retained.reservationId
              ? discovered
              : lookup,
          recovering: true,
        );
        return current.copyWith(
          outstandingReservationId: retained.reservationId,
          recoveryPhase: AdminRoleRecoveryPhase.unresolved,
          recoveryError:
              'An outstanding batch was found. Review its outcomes and close it before another review.',
        );
      }
      if (open) {
        current = _envelopeState(current, discovered, recovering: true);
        _pointer = AdminRoleRecoveryPointer(
          owner: _service.roleRecoveryOwner,
          reservationId: discovered.reservationId!,
          batchId: discovered.batch!.batchId,
        );
        await _journal.save(_pointer!, ownerIsCurrent: () => _isCurrent);
        _requireCurrent();
        return current.copyWith(
          outstandingReservationId: _pointer!.reservationId,
          recoveryPhase: AdminRoleRecoveryPhase.unresolved,
          recoveryError:
              'An outstanding batch was found. Review its outcomes and close it before another review.',
        );
      }
      return current.copyWith(
        roleEnvelope: current.roleEnvelope?.isSealed == true
            ? current.roleEnvelope
            : discovered,
        roleReview: null,
        outstandingReservationId: null,
        recoveryPhase: AdminRoleRecoveryPhase.ready,
        recoveryError:
            current.roleEnvelope?.reservationState ==
                AdminRoleReservationState.sealedBeforeReserve
            ? 'Reservation closed. No role changes were submitted.'
            : null,
      );
    } on Object {
      return current.copyWith(
        outstandingReservationId: _pointer?.reservationId,
        recoveryPhase: AdminRoleRecoveryPhase.blocked,
        recoveryError:
            'Recovery could not be verified. No role changes will be replayed.',
      );
    }
  }

  AdminUsersState _mergeRecovery(
    AdminUsersState current,
    AdminUsersState recovered,
  ) => current.copyWith(
    roleReview: recovered.roleReview,
    roleEnvelope: recovered.roleEnvelope,
    roleOutcomes: recovered.roleOutcomes,
    recoveryPhase: recovered.recoveryPhase,
    recoveryError: recovered.recoveryError,
    outstandingReservationId: recovered.outstandingReservationId,
    bulkUpdatingRole: null,
  );

  Future<void> reconcileOutstanding() async {
    _requireCurrent();
    final current = state.value;
    if (current == null || !current.canReconcile) return;
    state = AsyncValue.data(
      current.copyWith(
        recoveryPhase: AdminRoleRecoveryPhase.reconciling,
        recoveryError: null,
      ),
    );
    final recovered = await _recoverState(state.value!);
    if (_isCurrent) {
      state = AsyncValue.data(_mergeRecovery(state.value!, recovered));
    }
  }

  Future<void> closeOutstanding() async {
    _requireCurrent();
    final current = state.value;
    if (current == null || !current.canCloseOutstanding) return;
    final reservation =
        _pointer?.reservationId ?? current.outstandingReservationId;
    if (reservation == null) return;
    state = AsyncValue.data(
      current.copyWith(
        recoveryPhase: AdminRoleRecoveryPhase.sealing,
        recoveryError: null,
      ),
    );
    try {
      final envelope = await _service.sealRoleChange(
        reservationId: reservation,
      );
      _requireCurrent();
      final closed = _envelopeState(state.value!, envelope);
      await _journal.clear(
        _service.roleRecoveryOwner,
        reservation,
        ownerIsCurrent: () => _isCurrent,
      );
      _requireCurrent();
      _pointer = null;
      final recovered = await _recoverState(
        closed.copyWith(roleReview: null, outstandingReservationId: null),
      );
      _requireCurrent();
      state = AsyncValue.data(_mergeRecovery(state.value!, recovered));
      if (state.value!.recoveryPhase == AdminRoleRecoveryPhase.ready) {
        await refresh();
      }
    } on Object {
      if (_isCurrent) {
        _block(
          'Closure could not be verified. Reconcile or close this reservation again.',
          unresolved: true,
        );
      }
    }
  }

  Future<void> addInsuranceRewardTokens(AdminUserListItem user) async {
    _requireCurrent();
    final current = state.value;
    if (current == null ||
        current.isLoading ||
        current.updatingUserId != null ||
        current.bulkUpdatingRole != null) {
      throw const ValidationException(
        message: 'Wait for the current member update.',
      );
    }
    state = AsyncValue.data(current.copyWith(updatingUserId: user.id));
    try {
      await _service.adjustUserTokens(
        userId: user.id,
        amountTokens: 3000,
        note: 'Motor insurance purchase reward',
      );
      if (_isCurrent && state.value != null) {
        state = AsyncValue.data(state.value!.copyWith(updatingUserId: null));
        await refresh();
      }
    } finally {
      if (_isCurrent && state.value != null) {
        state = AsyncValue.data(state.value!.copyWith(updatingUserId: null));
      }
    }
  }
}
