import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/errors/app_exception_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

/// Observes one already-created mutation. Server rejection never replays it.
abstract final class AdminMutationGuard {
  static Future<T> run<T>(
    Future<T> request, {
    required SupabaseClient client,
    required String operation,
    String? operationId,
    Duration timeout = RequestDeadline.mutationTimeout,
  }) async {
    // Capture synchronously before the first await, including same-user sessions.
    final owner = client.auth.currentUser?.id;
    final session = AccountContext.sessionId(client.auth.currentSession);
    try {
      return await RequestDeadline.mutation(
        request,
        operation: operation,
        operationId: operationId,
        timeout: timeout,
      );
    } on Object catch (error, stackTrace) {
      final mapped = error is PostgrestException
          ? AppExceptionMapper.map(error, stackTrace)
          : error;
      if (mapped is! AdminReauthenticationRequiredException) rethrow;
      if (owner != null &&
          session != null &&
          client.auth.currentUser?.id == owner &&
          AccountContext.sessionId(client.auth.currentSession) == session) {
        AdminSessionGuard.rejectSession(userId: owner, sessionId: session);
      }
      throw mapped;
    }
  }
}
