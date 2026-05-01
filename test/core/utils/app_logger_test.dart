import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/utils/app_logger.dart';

void main() {
  group('AppLogger', () {
    test('debug logs without context do not crash', () {
      expect(() => AppLogger.debug('test debug'), returnsNormally);
    });

    test('debug logs with context do not crash', () {
      expect(
        () => AppLogger.debug('test debug', context: 'TestCtx'),
        returnsNormally,
      );
    });

    test('info logs without context do not crash', () {
      expect(() => AppLogger.info('test info'), returnsNormally);
    });

    test('info logs with context do not crash', () {
      expect(
        () => AppLogger.info('test info', context: 'TestCtx'),
        returnsNormally,
      );
    });

    test('warning logs with context and error do not crash', () {
      expect(
        () => AppLogger.warning(
          'test warning',
          context: 'TestCtx',
          error: Exception('warn exception'),
          stackTrace: StackTrace.empty,
        ),
        returnsNormally,
      );
    });

    test('error logs act normally', () {
      expect(
        () => AppLogger.error(
          'test error',
          Exception('error exception'),
          StackTrace.empty,
        ),
        returnsNormally,
      );
    });
  });
}
