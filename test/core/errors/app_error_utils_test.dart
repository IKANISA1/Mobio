import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/errors/app_exception_mapper.dart';
import 'package:mobi_app/core/location/places_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

void main() {
  group('userMessageForError', () {
    test('returns AppException message verbatim', () {
      const error = ValidationException(message: 'Choose a pickup point.');
      expect(userMessageForError(error), 'Choose a pickup point.');
    });

    test('returns PlacesException user message', () {
      const error = PlacesException(
        kind: PlacesErrorKind.network,
        message: 'socket closed',
      );
      expect(
        userMessageForError(error),
        'No internet connection. Please check your network.',
      );
    });

    test('maps TimeoutException to a friendly timeout message', () {
      expect(
        userMessageForError(TimeoutException('deadline exceeded')),
        'The request took too long. Check its current status before trying again.',
      );
    });

    test('strips generic exception prefixes', () {
      expect(
        userMessageForError(Exception('Trip already cancelled.')),
        'Trip already cancelled.',
      );
    });

    test('hides technical transport errors behind fallback copy', () {
      expect(
        userMessageForError(
          Exception('PostgrestException(message: denied, code: 42501)'),
        ),
        'Something went wrong. Please try again.',
      );
    });
  });

  group('AppExceptionMapper domain RPC errors', () {
    test('maps moto quota exhaustion to upgrade copy', () {
      final mapped = AppExceptionMapper.map(
        const PostgrestException(
          message: 'MOTO_PRO_SUBSCRIPTION_REQUIRED',
          code: 'P0001',
        ),
      );

      expect(mapped, isA<ForbiddenException>());
      expect(
        mapped.message,
        'You have used your free Moto Taxi trip credit. Upgrade to Mobio Plus to schedule more driver trips.',
      );
    });

    test('maps WhatsApp login enforcement to auth copy', () {
      final mapped = AppExceptionMapper.map(
        const PostgrestException(
          message: 'WHATSAPP_LOGIN_REQUIRED',
          code: 'P0001',
        ),
      );

      expect(mapped, isA<AuthException>());
      expect(mapped.message, 'Sign in with WhatsApp to continue.');
    });
  });
}
