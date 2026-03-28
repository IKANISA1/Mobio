import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Centralized app logger with structured output.
///
/// Uses [Logger] in debug mode for pretty-printed logs,
/// and minimal output in release mode.
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

  static void debug(String message) => _logger.d(message);
  static void info(String message) => _logger.i(message);
  static void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => _logger.w(message, error: error, stackTrace: stackTrace);
  static void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}
