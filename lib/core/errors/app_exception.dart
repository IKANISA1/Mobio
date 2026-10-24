/// Standardized exception hierarchy for the Mobio app.
///
/// All domain-level exceptions should extend [AppException] so that
/// error handling is consistent and user-facing messages can be
/// separated from technical details.
sealed class AppException implements Exception {
  const AppException({
    required this.message,
    this.debugMessage,
    this.originalError,
    this.stackTrace,
  });

  /// User-facing message (safe to display in UI).
  final String message;

  /// Technical debug details (for logging only).
  final String? debugMessage;

  /// The original error that was caught, if any.
  final Object? originalError;

  /// Stack trace from the original error.
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $message';
}

/// Network or connectivity error.
class NetworkException extends AppException {
  const NetworkException({
    super.message = 'Unable to connect. Check your internet and try again.',
    super.debugMessage,
    super.originalError,
    super.stackTrace,
  });
}

/// A write may have committed after the client stopped waiting for its reply.
/// Callers must read the authoritative state or reconcile [operationId] before
/// offering another attempt with a new request identity.
class MutationOutcomeUnknownException extends AppException {
  const MutationOutcomeUnknownException({
    required this.operation,
    this.operationId,
    super.message =
        'The result could not be confirmed. Check the current status before trying again.',
    super.debugMessage,
    super.originalError,
    super.stackTrace,
  });

  final String operation;
  final String? operationId;
}

/// Authentication / session error.
class AuthException extends AppException {
  const AuthException({
    super.message = 'Authentication failed. Please sign in again.',
    super.debugMessage,
    super.originalError,
    super.stackTrace,
  });
}

/// Permission / authorization error (e.g. non-admin trying admin action).
class ForbiddenException extends AppException {
  const ForbiddenException({
    super.message = 'You do not have permission for this action.',
    super.debugMessage,
    super.originalError,
    super.stackTrace,
  });
}

/// The current admin Auth session must be replaced by a new verification.
class AdminReauthenticationRequiredException extends ForbiddenException {
  const AdminReauthenticationRequiredException({
    super.message =
        'Your admin session needs verification. Verify again to continue.',
    super.debugMessage,
    super.originalError,
    super.stackTrace,
  });
}

/// Resource not found (e.g. profile, trip).
class NotFoundException extends AppException {
  const NotFoundException({
    super.message = 'The requested item was not found.',
    super.debugMessage,
    super.originalError,
    super.stackTrace,
  });
}

/// Validation error (e.g. invalid input).
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.debugMessage,
    super.originalError,
    super.stackTrace,
  });
}

/// Product flow is intentionally not supported by this app.
class UnsupportedFlowException extends AppException {
  const UnsupportedFlowException({
    required super.message,
    super.debugMessage,
    super.originalError,
    super.stackTrace,
  });
}

/// Server / backend error (Supabase RPC failure, Edge Function 500, etc.).
class ServerException extends AppException {
  const ServerException({
    super.message = 'Something went wrong on our end. Please try again.',
    super.debugMessage,
    super.originalError,
    super.stackTrace,
  });
}

/// Unexpected / unknown error — catch-all.
class UnexpectedException extends AppException {
  const UnexpectedException({
    super.message = 'An unexpected error occurred. Please try again.',
    super.debugMessage,
    super.originalError,
    super.stackTrace,
  });
}
