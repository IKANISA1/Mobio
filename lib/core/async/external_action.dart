import 'dart:async';

import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/utils/app_logger.dart';

/// Bounds native handoffs while allowing time for the system picker/share UI.
/// Losing the reply never proves that the OS action did not happen.
abstract final class ExternalAction {
  static const timeout = Duration(seconds: 60);

  static Future<T> run<T>(Future<T> request, {required String operation}) =>
      RequestDeadline.mutation(request, operation: operation, timeout: timeout);

  /// For simple callbacks with no confirmation UI. Observe errors so an optional
  /// clipboard/handoff failure cannot become an unhandled zone error.
  static void start<T>(Future<T> request, {required String operation}) {
    unawaited(
      run(request, operation: operation).then<void>((_) {}).catchError((
        Object _,
      ) {
        AppLogger.warning('External action completion was not confirmed.');
      }),
    );
  }
}
