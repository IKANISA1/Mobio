import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/admin/data/admin_base_service.dart';
import 'package:mobi_app/features/admin/domain/admin_role_change.dart';
import 'package:mobi_app/features/admin/domain/admin_role_recovery.dart';
import 'package:mobi_app/features/admin/domain/admin_user_query.dart';
import 'package:mobi_app/features/admin/domain/admin_wire_record.dart';
import 'package:mobi_shared_types/models/admin/admin_models.dart';

class AdminUserService extends AdminBaseService {
  AdminUserService({super.supabase});

  String? get currentSessionId =>
      AccountContext.sessionId(supabaseClient.auth.currentSession);

  AdminRoleRecoveryOwner get roleRecoveryOwner {
    final user = supabaseClient.auth.currentUser;
    if (user == null || user.isAnonymous || currentSessionId == null) {
      throw const StaleAccountWork();
    }
    final rest = Uri.parse(supabaseClient.rest.url);
    const suffix = '/rest/v1';
    if (!rest.path.endsWith(suffix) ||
        rest.userInfo.isNotEmpty ||
        rest.hasQuery ||
        rest.hasFragment ||
        !{'https', 'http'}.contains(rest.scheme)) {
      throw StateError('ADMIN_PROJECT_IDENTITY_INVALID');
    }
    final base = rest.replace(
      path: rest.path.substring(0, rest.path.length - suffix.length),
    );
    return AdminRoleRecoveryOwner(
      actorId: user.id,
      hostIdentity: base.toString(),
    );
  }

  ({String actor, String session}) _transport() {
    final owner = roleRecoveryOwner;
    return (actor: owner.actorId, session: currentSessionId!);
  }

  void _requireTransport(({String actor, String session}) owner) {
    if (currentUserId != owner.actor || currentSessionId != owner.session) {
      throw const StaleAccountWork();
    }
  }

  Future<AdminUserPage> listUsersPage(AdminUserQuery query) async {
    final owner = _transport();
    final raw = await read(
      supabaseClient.rpc(
        'rpc_admin_users_page',
        params: query.toRpcParameters(),
      ),
    );
    _requireTransport(owner);
    return AdminUserPage.parse(
      raw,
      actorId: owner.actor,
      sessionId: owner.session,
      request: query,
    );
  }

  Future<AdminUserSnapshotRelease> releaseUsersSnapshot(
    String snapshotId,
  ) async {
    final owner = _transport();
    final raw = await read(
      supabaseClient.rpc(
        'rpc_admin_users_release_snapshot',
        params: {'p_snapshot_id': snapshotId},
      ),
    );
    _requireTransport(owner);
    return AdminUserSnapshotRelease.parse(
      raw,
      actorId: owner.actor,
      sessionId: owner.session,
      snapshotId: snapshotId,
    );
  }

  Future<AdminRoleBatchEnvelope> reserveRoleChange(
    AdminRoleReview review,
  ) async {
    final owner = _transport();
    if (review.actorId != owner.actor ||
        review.sessionId != owner.session ||
        review.entries.isEmpty ||
        review.entries.length > 100 ||
        review.entries.map((entry) => entry.targetId).toSet().length !=
            review.entries.length) {
      throw const ValidationException(
        message: 'This role review is no longer available.',
      );
    }
    return _roleMutation(
      () => supabaseClient.rpc(
        'rpc_admin_role_reserve',
        params: {
          'p_reservation_id': review.reservationId,
          'p_snapshot_id': review.snapshotId,
          'p_targets': review.entries
              .map((entry) => entry.toReserveTarget())
              .toList(growable: false),
        },
      ),
      operation: 'rpc_admin_role_reserve',
      operationId: review.reservationId,
      owner: owner,
      reservationId: review.reservationId,
      review: review,
    );
  }

  Future<AdminRoleBatchEnvelope> executeRoleChange({
    required AdminRoleBatchEnvelope envelope,
    required String operationId,
  }) async {
    final owner = _transport();
    final batch = envelope.batch;
    if (batch == null ||
        envelope.actorId != owner.actor ||
        batch.originSessionId != owner.session ||
        envelope.isSealed ||
        !envelope.operations.any(
          (item) =>
              item.operationId == operationId &&
              item.status == AdminRoleOperationStatus.prepared,
        )) {
      throw const ValidationException(
        message: 'Reconcile this batch before another role change.',
      );
    }
    return _roleMutation(
      () => supabaseClient.rpc(
        'rpc_admin_role_execute',
        params: {'p_batch_id': batch.batchId, 'p_operation_id': operationId},
      ),
      operation: 'rpc_admin_role_execute',
      operationId: operationId,
      owner: owner,
      reservationId: batch.reservationId,
      batchId: batch.batchId,
      previous: envelope,
    );
  }

  Future<AdminRoleBatchEnvelope> roleChangeStatus({
    String? batchId,
    String? reservationId,
  }) async {
    if (batchId != null && reservationId != null) {
      throw const ValidationException(
        message: 'Choose one role recovery reference.',
      );
    }
    final owner = _transport();
    final raw = await read(
      supabaseClient.rpc(
        'rpc_admin_role_status',
        params: {'p_batch_id': batchId, 'p_reservation_id': reservationId},
      ),
    );
    _requireTransport(owner);
    return AdminRoleBatchEnvelope.parse(
      raw,
      actorId: owner.actor,
      sessionId: owner.session,
      expectedBatchId: batchId,
      expectedReservationId: reservationId,
    );
  }

  Future<AdminRoleBatchEnvelope> sealRoleChange({
    String? batchId,
    String? reservationId,
  }) async {
    if ((batchId == null) == (reservationId == null)) {
      throw const ValidationException(
        message: 'Choose one role recovery reference.',
      );
    }
    final owner = _transport();
    return _roleMutation(
      () => supabaseClient.rpc(
        'rpc_admin_role_seal',
        params: {'p_batch_id': batchId, 'p_reservation_id': reservationId},
      ),
      operation: 'rpc_admin_role_seal',
      operationId: reservationId ?? batchId!,
      owner: owner,
      reservationId: reservationId,
      batchId: batchId,
      mustSeal: true,
    );
  }

  Future<AdminRoleBatchEnvelope> _roleMutation(
    Future<dynamic> Function() request, {
    required String operation,
    required String operationId,
    required ({String actor, String session}) owner,
    String? reservationId,
    String? batchId,
    AdminRoleReview? review,
    AdminRoleBatchEnvelope? previous,
    bool mustSeal = false,
  }) async {
    _requireTransport(owner);
    final raw = await mutate(
      request(),
      operation: operation,
      operationId: operationId,
    );
    try {
      _requireTransport(owner);
      final result = AdminRoleBatchEnvelope.parse(
        raw,
        actorId: owner.actor,
        sessionId: owner.session,
        expectedReservationId: reservationId,
        expectedBatchId: batchId,
        review: review,
      );
      if ((mustSeal && !result.isSealed) ||
          (review != null &&
              (result.reservationState != AdminRoleReservationState.reserved ||
                  result.batch?.originSessionId != owner.session)) ||
          (previous != null && !_sameBatch(previous, result))) {
        throw const FormatException('Admin role mutation receipt mismatch.');
      }
      return result;
    } on Object catch (error) {
      // A malformed successful reply cannot undo a committed server action.
      throw MutationOutcomeUnknownException(
        operation: operation,
        operationId: operationId,
        originalError: error,
        debugMessage: 'Admin role mutation receipt could not be verified.',
      );
    }
  }

  bool _sameBatch(
    AdminRoleBatchEnvelope previous,
    AdminRoleBatchEnvelope next,
  ) => next.continues(previous);

  Future<List<AdminUserListItem>> listUsers({
    String? role,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final rows = await read(
        supabaseClient.rpc(
          'rpc_admin_list_users',
          params: {
            'p_role': role,
            'p_search': search?.trim().isEmpty == true ? null : search?.trim(),
            'p_limit': limit,
            'p_offset': offset,
          },
        ),
      );

      return requireRows(
        rows,
        'rpc_admin_list_users',
      ).map(AdminWireRecord.user).toList();
    } on Object catch (error) {
      AppLogger.error('Error fetching admin users: $error');
      rethrow;
    }
  }

  Future<void> updateUserRole({
    required String userId,
    required String role,
  }) async {
    try {
      await mutate(
        supabaseClient.rpc(
          'rpc_admin_update_user_role',
          params: {'p_user_id': userId, 'p_role': role},
        ),
        operation: 'rpc_admin_update_user_role',
        operationId: userId,
      );
    } on Object catch (error) {
      AppLogger.error('Error updating admin user role: $error');
      rethrow;
    }
  }

  Future<AdminTokenAdjustmentReceipt> adjustUserTokens({
    required String userId,
    required int amountTokens,
    String? note,
  }) async {
    try {
      final data = await mutate(
        supabaseClient.rpc(
          'rpc_admin_adjust_user_tokens',
          params: {
            'p_profile_id': userId,
            'p_amount_tokens': amountTokens,
            'p_note': note,
          },
        ),
        operation: 'rpc_admin_adjust_user_tokens',
        operationId: userId,
      );

      try {
        return AdminWireRecord.tokenAdjustment(
          requireRow(data, 'rpc_admin_adjust_user_tokens'),
          userId: userId,
          amountTokens: amountTokens,
        );
      } on FormatException catch (error) {
        // A successful HTTP response with a broken receipt cannot prove that
        // the submitted credit did not happen. Reconcile before retrying it.
        throw MutationOutcomeUnknownException(
          operation: 'rpc_admin_adjust_user_tokens',
          operationId: userId,
          originalError: error,
          debugMessage: error.message,
        );
      }
    } on Object catch (error) {
      AppLogger.error('Error adjusting user TOKENS: $error');
      rethrow;
    }
  }

  Future<List<AdminWhatsappNumberItem>> listWhatsappAdminNumbers() async {
    try {
      final rows = await read(
        supabaseClient.rpc('rpc_admin_list_whatsapp_numbers'),
      );
      return requireRows(
        rows,
        'rpc_admin_list_whatsapp_numbers',
      ).map(AdminWireRecord.whatsapp).toList();
    } on Object catch (error) {
      AppLogger.error('Error fetching admin WhatsApp numbers: $error');
      rethrow;
    }
  }

  Future<AdminWhatsappNumberItem> upsertWhatsappAdminNumber({
    required String phoneE164,
    required String countryCode,
    String? displayName,
    bool isActive = true,
  }) async {
    try {
      final rows = await mutate(
        supabaseClient.rpc(
          'rpc_admin_upsert_whatsapp_number',
          params: {
            'p_phone_e164': phoneE164,
            'p_country_code': countryCode,
            'p_display_name': displayName?.trim().isEmpty == true
                ? null
                : displayName?.trim(),
            'p_is_active': isActive,
          },
        ),
        operation: 'rpc_admin_upsert_whatsapp_number',
        operationId: phoneE164,
      );

      return _confirmReceipt(
        () {
          final typedRows = requireRows(
            rows,
            'rpc_admin_upsert_whatsapp_number',
          );
          if (typedRows.length != 1) {
            throw const FormatException(
              'Admin WhatsApp upsert must return exactly one row.',
            );
          }
          return AdminWireRecord.whatsapp(
            typedRows.single,
            expectedPhone: phoneE164.trim().replaceAll(RegExp(r'\s+'), ''),
            expectedCountry: countryCode.trim().replaceAll(RegExp(r'\s+'), ''),
            expectedActive: isActive,
          );
        },
        operation: 'rpc_admin_upsert_whatsapp_number',
        operationId: phoneE164,
      );
    } on Object catch (error) {
      AppLogger.error('Error upserting admin WhatsApp number: $error');
      rethrow;
    }
  }

  Future<AdminWhatsappNumberItem> setWhatsappAdminNumberActive({
    required String id,
    required bool isActive,
  }) async {
    try {
      final rows = await mutate(
        supabaseClient.rpc(
          'rpc_admin_set_whatsapp_number_active',
          params: {'p_id': id, 'p_is_active': isActive},
        ),
        operation: 'rpc_admin_set_whatsapp_number_active',
        operationId: id,
      );

      return _confirmReceipt(
        () {
          final typedRows = requireRows(
            rows,
            'rpc_admin_set_whatsapp_number_active',
          );
          if (typedRows.length != 1) {
            throw const FormatException(
              'Admin WhatsApp update must return exactly one row.',
            );
          }
          return AdminWireRecord.whatsapp(
            typedRows.single,
            expectedId: id,
            expectedActive: isActive,
          );
        },
        operation: 'rpc_admin_set_whatsapp_number_active',
        operationId: id,
      );
    } on Object catch (error) {
      AppLogger.error('Error updating admin WhatsApp number status: $error');
      rethrow;
    }
  }

  T _confirmReceipt<T>(
    T Function() parse, {
    required String operation,
    required String operationId,
  }) {
    try {
      return parse();
    } on FormatException catch (error) {
      throw MutationOutcomeUnknownException(
        operation: operation,
        operationId: operationId,
        originalError: error,
        debugMessage: error.message,
      );
    }
  }
}
