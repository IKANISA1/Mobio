import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/admin/data/admin_base_service.dart';
import 'package:mobi_shared_types/models/admin/admin_models.dart';

class AdminUserService extends AdminBaseService {
  AdminUserService({super.supabase});

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
      ).map(AdminUserListItem.fromJson).toList();
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

      return AdminTokenAdjustmentReceipt.fromJson(
        requireRow(data, 'rpc_admin_adjust_user_tokens'),
      );
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
      ).map(AdminWhatsappNumberItem.fromJson).toList();
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

      final typedRows = requireRows(rows, 'rpc_admin_upsert_whatsapp_number');
      if (typedRows.isEmpty) {
        throw StateError(
          'Admin WhatsApp number was not returned by the server.',
        );
      }

      return AdminWhatsappNumberItem.fromJson(typedRows.first);
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

      final typedRows = requireRows(
        rows,
        'rpc_admin_set_whatsapp_number_active',
      );
      if (typedRows.isEmpty) {
        throw StateError('Admin WhatsApp number update returned no row.');
      }

      return AdminWhatsappNumberItem.fromJson(typedRows.first);
    } on Object catch (error) {
      AppLogger.error('Error updating admin WhatsApp number status: $error');
      rethrow;
    }
  }
}
