import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:mobi_app/core/utils/app_logger.dart';

class FirebaseAnalyticsService {
  FirebaseAnalyticsService._();

  static final instance = FirebaseAnalyticsService._();

  FirebaseAnalytics? _analytics;
  String? _lastScreenName;

  bool get isReady => _analytics != null;

  void attach(FirebaseAnalytics analytics) {
    _analytics = analytics;
  }

  List<NavigatorObserver> get observers {
    final analytics = _analytics;
    if (analytics == null) {
      return const <NavigatorObserver>[];
    }

    return <NavigatorObserver>[FirebaseAnalyticsObserver(analytics: analytics)];
  }

  Future<void> setCollectionEnabled(bool enabled) async {
    final analytics = _analytics;
    if (analytics == null) {
      return;
    }

    await analytics.setAnalyticsCollectionEnabled(enabled);
  }

  Future<void> logAppOpen() async {
    final analytics = _analytics;
    if (analytics == null) {
      return;
    }

    await analytics.logAppOpen();
  }

  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    final analytics = _analytics;
    if (analytics == null || _lastScreenName == screenName) {
      return;
    }

    _lastScreenName = screenName;

    await analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass ?? screenName,
    );
  }

  Future<void> setUserContext({String? userId, String? role}) async {
    final analytics = _analytics;
    if (analytics == null) {
      return;
    }

    await analytics.setUserId(id: userId);
    await analytics.setUserProperty(name: 'supabase_role', value: role);
  }

  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    final analytics = _analytics;
    if (analytics == null) {
      return;
    }

    try {
      await analytics.logEvent(name: name, parameters: parameters);
    } on Object catch (error, stackTrace) {
      AppLogger.warning(
        'Failed to log Firebase Analytics event "$name".',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
