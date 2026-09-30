import 'dart:async';

import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/location/places_exception.dart';

/// Converts exceptions into copy that is safe to show in the UI.
String userMessageForError(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is AppException) {
    return error.message;
  }

  if (error is PlacesException) {
    return error.userMessage;
  }

  if (error is TimeoutException) {
    return 'The request took too long. Check its current status before trying again.';
  }

  final raw = error.toString().trim();
  if (raw.isEmpty || raw.startsWith('Instance of')) {
    return fallback;
  }

  const technicalMarkers = <String>[
    'postgrestexception',
    'socketexception',
    'clientexception',
    'handshakeexception',
    'formatexception',
  ];
  if (technicalMarkers.any((marker) => raw.toLowerCase().contains(marker))) {
    return fallback;
  }

  final sanitized = raw.replaceFirst(
    RegExp(r'^[A-Za-z_]*(?:Exception|Error):\s*'),
    '',
  );

  return sanitized.isEmpty ? fallback : sanitized;
}
