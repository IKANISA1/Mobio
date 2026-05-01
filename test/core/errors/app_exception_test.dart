import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/errors/app_exception_mapper.dart';

void main() {
  group('AppException hierarchy', () {
    test('NetworkException has correct default message', () {
      const e = NetworkException();
      expect(e.message, contains('internet'));
      expect(e.toString(), contains('NetworkException'));
    });

    test('AuthException has correct default message', () {
      const e = AuthException();
      expect(e.message, contains('sign in'));
    });

    test('ForbiddenException has correct default message', () {
      const e = ForbiddenException();
      expect(e.message, contains('permission'));
    });

    test('NotFoundException has correct default message', () {
      const e = NotFoundException();
      expect(e.message, contains('not found'));
    });

    test('ValidationException requires a message', () {
      const e = ValidationException(message: 'Phone is required');
      expect(e.message, 'Phone is required');
    });

    test('ServerException has correct default message', () {
      const e = ServerException();
      expect(e.message, contains('our end'));
    });

    test('UnexpectedException has correct default message', () {
      const e = UnexpectedException();
      expect(e.message, contains('unexpected'));
    });

    test('debugMessage and originalError are preserved', () {
      const e = ServerException(
        debugMessage: 'RPC failed',
        originalError: 'raw error',
      );
      expect(e.debugMessage, 'RPC failed');
      expect(e.originalError, 'raw error');
    });
  });

  group('AppExceptionMapper', () {
    test('maps SocketException to NetworkException', () {
      final result = AppExceptionMapper.map(
        const SocketException('Connection refused'),
      );
      expect(result, isA<NetworkException>());
    });

    test('maps TimeoutException to NetworkException', () {
      final result = AppExceptionMapper.map(
        TimeoutException('deadline exceeded'),
      );
      expect(result, isA<NetworkException>());
      expect(result.message, contains('too long'));
    });

    test('maps FormatException to ServerException', () {
      final result = AppExceptionMapper.map(
        const FormatException('Invalid JSON'),
      );
      expect(result, isA<ServerException>());
      expect(result.message, contains('invalid data'));
    });

    test('maps generic error to UnexpectedException', () {
      final result = AppExceptionMapper.map(Exception('unknown'));
      expect(result, isA<UnexpectedException>());
    });

    test('passes through existing AppException', () {
      const original = AuthException(message: 'Session expired');
      final result = AppExceptionMapper.map(original);
      expect(identical(result, original), isTrue);
    });

    test('preserves stack trace', () {
      final trace = StackTrace.current;
      final result = AppExceptionMapper.map(Exception('test'), trace);
      expect(result.stackTrace, trace);
    });
  });
}
