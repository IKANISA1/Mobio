import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/firebase/firebase_analytics_service.dart';
import 'package:mobi_app/core/firebase/firebase_auth_service.dart';
import 'package:mobi_app/core/firebase/firebase_remote_config_service.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/firebase_options.dart';

class FirebaseBootstrapService {
  FirebaseBootstrapService._();

  static final instance = FirebaseBootstrapService._();

  bool _initializationAttempted = false;
  bool _isReady = false;
  bool _crashlyticsCollectionEnabled = false;

  bool get isReady => _isReady;

  bool get _supportsCrashlytics {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<bool> initialize() async {
    if (_initializationAttempted) {
      return _isReady;
    }
    _initializationAttempted = true;

    final options = DefaultFirebaseOptions.currentPlatform;
    if (options == null) {
      AppLogger.warning(
        'Firebase is not configured for this platform. '
        'Supply the registered platform app ID through --dart-define.',
      );
      return false;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await RequestDeadline.read(
          Firebase.initializeApp(options: options),
          timeout: const Duration(seconds: 8),
        );
      }

      await FirebaseAuthService.instance.initialize();
      FirebaseAnalyticsService.instance.attach(FirebaseAnalytics.instance);
      await FirebaseRemoteConfigService.instance.initialize();
      await FirebaseAnalyticsService.instance.setCollectionEnabled(
        FirebaseRemoteConfigService.instance.analyticsEnabled,
      );

      _crashlyticsCollectionEnabled =
          !kDebugMode &&
          _supportsCrashlytics &&
          FirebaseRemoteConfigService.instance.crashlyticsEnabled;

      if (_supportsCrashlytics) {
        await RequestDeadline.read(
          FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
            _crashlyticsCollectionEnabled,
          ),
          timeout: const Duration(seconds: 4),
        );
      }

      _isReady = true;
      return true;
    } on Object catch (error, stackTrace) {
      AppLogger.warning(
        'Firebase bootstrap failed; continuing without Firebase infra.',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<void> ensureBackgroundInitialized() async {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options == null || Firebase.apps.isNotEmpty) {
      return;
    }

    try {
      await RequestDeadline.read(
        Firebase.initializeApp(options: options),
        timeout: const Duration(seconds: 8),
      );
      _isReady = true;
    } on Object catch (error, stackTrace) {
      AppLogger.warning(
        'Firebase background initialization failed.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void recordFlutterFatalError(FlutterErrorDetails details) {
    if (_crashlyticsCollectionEnabled && _supportsCrashlytics) {
      unawaited(
        _recordSafely(
          FirebaseCrashlytics.instance.recordFlutterFatalError(details),
        ),
      );
      return;
    }

    FlutterError.presentError(details);
  }

  bool recordPlatformError(Object error, StackTrace stackTrace) {
    if (_crashlyticsCollectionEnabled && _supportsCrashlytics) {
      unawaited(
        _recordSafely(
          FirebaseCrashlytics.instance.recordError(
            error,
            stackTrace,
            fatal: true,
          ),
        ),
      );
    } else {
      AppLogger.error('PlatformError: $error', error, stackTrace);
    }

    return true;
  }

  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
  }) async {
    if (_crashlyticsCollectionEnabled && _supportsCrashlytics) {
      await _recordSafely(
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          fatal: fatal,
        ),
      );
      return;
    }

    AppLogger.error('Firebase-infra error: $error', error, stackTrace);
  }

  Future<void> _recordSafely(Future<void> request) async {
    try {
      await RequestDeadline.read(request, timeout: const Duration(seconds: 4));
    } on Object {
      // Error reporting is optional infrastructure. Do not feed a reporting
      // failure back into the zone's reporting hook or retry it automatically.
      AppLogger.warning('Crash reporting was not confirmed.');
    }
  }
}
