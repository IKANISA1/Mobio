import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/utils/app_logger.dart';

/// Firebase Auth is treated as infrastructure support only in this repo.
///
/// Supabase remains the source of truth for product auth and data access.
/// This service optionally creates a parallel anonymous Firebase session for
/// Firebase-native capabilities, but it never replaces the Supabase session.
class FirebaseAuthService {
  FirebaseAuthService._();

  static final instance = FirebaseAuthService._();

  static const _enableAnonymousBootstrap = bool.fromEnvironment(
    'FIREBASE_ENABLE_ANONYMOUS_AUTH',
    defaultValue: true,
  );

  FirebaseAuth? _auth;
  bool _initializationAttempted = false;

  bool get isReady => _auth != null;

  User? get currentUser => _auth?.currentUser;

  Future<void> initialize() async {
    if (_initializationAttempted) {
      return;
    }
    _initializationAttempted = true;

    if (Firebase.apps.isEmpty) {
      return;
    }

    final auth = FirebaseAuth.instance;
    _auth = auth;

    if (!_enableAnonymousBootstrap || auth.currentUser != null) {
      return;
    }

    try {
      await RequestDeadline.read(auth.signInAnonymously());
      if (kDebugMode) {
        debugPrint('[firebase-auth] Anonymous Firebase session initialized');
      }
    } on FirebaseAuthException catch (error, stackTrace) {
      AppLogger.warning(
        'Firebase Auth initialized, but anonymous sign-in failed. '
        'Enable Anonymous auth in Firebase console if this infrastructure '
        'session is required.',
        error: error,
        stackTrace: stackTrace,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.warning(
        'Firebase Auth bootstrap failed unexpectedly.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
