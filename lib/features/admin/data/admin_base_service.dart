import 'package:mobi_app/core/auth/admin_mutation_guard.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AdminBaseService {
  AdminBaseService({SupabaseClient? supabase})
    : supabaseClient = supabase ?? Supabase.instance.client;

  final SupabaseClient supabaseClient;

  String? get currentUserId => supabaseClient.auth.currentUser?.id;

  Future<T> read<T>(Future<T> request) => RequestDeadline.read(request);

  Future<T> mutate<T>(
    Future<T> request, {
    required String operation,
    String? operationId,
  }) => AdminMutationGuard.run(
    request,
    client: supabaseClient,
    operation: operation,
    operationId: operationId,
  );

  /// A malformed RPC response must not look like an empty result to an admin.
  List<Map<String, dynamic>> requireRows(Object? value, String operation) {
    if (value is! List) {
      throw FormatException('$operation returned a non-list response');
    }
    return value.map((row) => requireRow(row, operation)).toList();
  }

  Map<String, dynamic> requireRow(Object? value, String operation) {
    if (value is! Map) {
      throw FormatException('$operation returned a non-object row');
    }
    if (value.keys.any((key) => key is! String)) {
      throw FormatException('$operation returned a row with non-string keys');
    }
    return Map<String, dynamic>.from(value);
  }
}
