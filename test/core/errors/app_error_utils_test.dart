import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/services/places_exception.dart';

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
        'The request took too long. Please try again.',
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
}
