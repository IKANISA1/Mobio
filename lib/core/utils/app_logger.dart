import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Centralized app logger with structured output.
///
/// Uses [Logger] in debug mode for pretty-printed logs,
/// and minimal output in release mode.
///
/// Usage:
/// ```dart
/// AppLogger.info('Profile loaded', context: 'ProfileService');
/// AppLogger.error('RPC failed', error, stackTrace);
/// ```
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
    ),
    level: kDebugMode ? Level.debug : Level.warning,
  );

  /// Formats the message with an optional context prefix.
  static String _fmt(String message, String? context) =>
      context != null ? '[$context] $message' : message;

  static void debug(String message, {String? context}) =>
      _logger.d(_fmt(message, context));

  static void info(String message, {String? context}) =>
      _logger.i(_fmt(message, context));

  static void warning(
    String message, {
    String? context,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _logger.w(_fmt(message, context), error: error, stackTrace: stackTrace);

  static void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}
