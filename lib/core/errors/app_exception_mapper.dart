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
      final domainError = _mapPostgrestDomainError(error, stackTrace);
      if (domainError != null) return domainError;

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

  static AppException? _mapPostgrestDomainError(
    supa.PostgrestException error,
    StackTrace? stackTrace,
  ) {
    final raw = [
      error.message,
      error.details?.toString(),
      error.hint,
    ].whereType<String>().join(' ');

    if (raw.contains('WHATSAPP_LOGIN_REQUIRED')) {
      return AuthException(
        message: 'Sign in with WhatsApp to continue.',
        debugMessage: raw,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (raw.contains('MOTO_PRO_SUBSCRIPTION_REQUIRED')) {
      return ForbiddenException(
        message:
            'You have used your free Moto Taxi trip credit. Upgrade to Mobio Plus to schedule more driver trips.',
        debugMessage: raw,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (raw.contains('PROFILE_REQUIRED')) {
      return AuthException(
        message: 'Complete your profile before scheduling trips.',
        debugMessage: raw,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (raw.contains('INVALID_TRIP_PAYLOAD')) {
      return ValidationException(
        message: 'Complete the trip details before scheduling.',
        debugMessage: raw,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (raw.contains('USER_BLOCKED')) {
      return ForbiddenException(
        message:
            'Messaging is unavailable because one of you has blocked the other.',
        debugMessage: raw,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    return null;
  }
}
