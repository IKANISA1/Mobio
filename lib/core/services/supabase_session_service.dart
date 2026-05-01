import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralizes anonymous Supabase session bootstrap and admin de-escalation.
class SupabaseSessionService {
  SupabaseSessionService._();

  static const _maxRetries = 3;
  static const _baseDelay = Duration(milliseconds: 800);

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<bool> ensureAnonymousSession() async {
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final existing = _client.auth.currentSession;
        if (existing != null) {
          if (kDebugMode) {
            debugPrint('✅ [auth] Existing session found');
          }
          return true;
        }

        if (kDebugMode) {
          debugPrint(
            '🔑 [auth] Attempt ${attempt + 1}/$_maxRetries — signInAnonymously()...',
          );
        }

        final response = await _client.auth.signInAnonymously();
        if (response.session != null) {
          if (kDebugMode) {
            debugPrint('✅ [auth] Anonymous session created');
          }
          return true;
        }

        if (kDebugMode) {
          debugPrint('❌ [auth] signInAnonymously returned null session');
        }
      } on Object catch (error, stackTrace) {
        AppLogger.warning(
          'Supabase anonymous bootstrap failed on attempt ${attempt + 1}.',
          error: error,
          stackTrace: stackTrace,
        );
      }

      if (attempt < _maxRetries - 1) {
        await Future<void>.delayed(_baseDelay * (1 << attempt));
      }
    }

    return false;
  }

  /// Fully drops the current session and restores the app's anonymous baseline.
  static Future<bool> signOutToAnonymous() async {
    try {
      await _client.auth.signOut();
    } on Object catch (error, stackTrace) {
      AppLogger.warning(
        'Supabase sign-out failed while de-escalating session.',
        error: error,
        stackTrace: stackTrace,
      );
    }

    return ensureAnonymousSession();
  }
}
