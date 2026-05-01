import 'dart:async';
import 'dart:io';

import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

/// Converts raw exceptions into typed [AppException] instances.
///
/// Usage:
/// ```dart
/// try {
///   await someOperation();
/// } on AppException {
///   rethrow;
/// } on Object catch (e, st) {
///   throw AppExceptionMapper.map(e, st);
/// }
/// ```
abstract final class AppExceptionMapper {
  /// Maps a raw error to the most appropriate [AppException] subtype.
  static AppException map(Object error, [StackTrace? stackTrace]) {
    // Already an AppException — pass through.
    if (error is AppException) return error;

    // Supabase auth errors
    if (error is supa.AuthException) {
      return AuthException(
        debugMessage: error.message,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Supabase Postgrest errors (RPC / table operations)
    if (error is supa.PostgrestException) {
      final code = error.code;

      // Forbidden / RLS violation
      if (code == '42501' || code == 'PGRST301') {
        return ForbiddenException(
          debugMessage: error.message,
          originalError: error,
          stackTrace: stackTrace,
        );
      }

      // Not found
      if (code == 'PGRST116') {
        return NotFoundException(
          debugMessage: error.message,
          originalError: error,
          stackTrace: stackTrace,
        );
      }

      // Generic server error
      return ServerException(
        debugMessage: '${error.code}: ${error.message}',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Network / IO errors
    if (error is SocketException || error is HttpException) {
      return NetworkException(
        debugMessage: error.toString(),
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (error is TimeoutException) {
      return NetworkException(
        message: 'The request took too long. Please try again.',
        debugMessage: error.message,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // FormatException (e.g. JSON parse)
    if (error is FormatException) {
      return ServerException(
        message: 'Received invalid data from the server.',
        debugMessage: error.message,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Catch-all
    return UnexpectedException(
      debugMessage: error.toString(),
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Logs the error and returns the mapped exception.
  static AppException mapAndLog(
    Object error, [
    StackTrace? stackTrace,
    String? context,
  ]) {
    final mapped = map(error, stackTrace);
    AppLogger.error(
      '${context ?? 'Error'}: ${mapped.debugMessage ?? mapped.message}',
      error,
      stackTrace,
    );
    return mapped;
  }
}
