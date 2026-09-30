import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

/// Bounds how long the UI waits for a request. A Dart timeout does not prove
/// that an underlying HTTP write was cancelled or rolled back.
abstract final class RequestDeadline {
  static const readTimeout = Duration(seconds: 15);
  static const mutationTimeout = Duration(seconds: 20);

  static Future<T> read<T>(
    Future<T> request, {
    Duration timeout = readTimeout,
  }) => request.timeout(timeout);

  static Future<T> mutation<T>(
    Future<T> request, {
    required String operation,
    String? operationId,
    Duration timeout = mutationTimeout,
  }) async {
    try {
      return await request.timeout(timeout);
    } on Object catch (error, stackTrace) {
      // An explicit server rejection has a known result. A timeout or broken
      // transport does not tell the client whether the write reached the server.
      if (!responseWasLost(error)) rethrow;
      throw MutationOutcomeUnknownException(
        operation: operation,
        operationId: operationId,
        debugMessage: error.toString(),
        originalError: error,
        stackTrace: stackTrace,
      );
    }
  }

  static bool responseWasLost(Object error) =>
      error is TimeoutException ||
      error is SocketException ||
      error is HttpException ||
      error is http.ClientException ||
      (error is supa.FunctionException && error.status >= 500) ||
      // The locked PostgREST SDK uses an HTTP status string when a proxy
      // response has no structured database error. Preserve SQLSTATE/PTxxx
      // errors, whose explicit transaction rejection is known.
      (error is supa.PostgrestException && _isProxyFailureCode(error.code)) ||
      (error is DioException &&
          switch (error.type) {
            DioExceptionType.connectionTimeout ||
            DioExceptionType.sendTimeout ||
            DioExceptionType.receiveTimeout ||
            DioExceptionType.connectionError => true,
            DioExceptionType.unknown => _lostNativeTransport(error.error),
            DioExceptionType.badResponse =>
              error.response?.statusCode != null &&
                  error.response!.statusCode! >= 500 &&
                  error.response!.statusCode! <= 599 &&
                  error.response!.data is! Map,
            _ => false,
          });
  static bool _isProxyFailureCode(String? code) {
    final status = int.tryParse(code ?? '');
    return status != null && status >= 500 && status <= 599;
  }

  static bool _lostNativeTransport(Object? error) =>
      error is TimeoutException ||
      error is SocketException ||
      error is HttpException ||
      error is http.ClientException;
}
