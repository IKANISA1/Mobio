import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/utils/app_logger.dart';

class FirebaseAnalyticsService {
  FirebaseAnalyticsService._();
  FirebaseAnalyticsService.forTesting();

  static final instance = FirebaseAnalyticsService._();

  FirebaseAnalytics? _analytics;
  String? _lastScreenName;
  int _contextRevision = 0;
  Future<void> _contextTail = Future<void>.value();

  bool get isReady => _analytics != null;

  void attach(FirebaseAnalytics analytics) {
    _analytics = analytics;
    _lastScreenName = null;
    _contextRevision++;
  }

  List<NavigatorObserver> get observers {
    final analytics = _analytics;
    if (analytics == null) {
      return const <NavigatorObserver>[];
    }

    return <NavigatorObserver>[_BoundedAnalyticsObserver(this)];
  }

  Future<void> setCollectionEnabled(bool enabled) async {
    final analytics = _analytics;
    if (analytics == null) {
      return;
    }

    await RequestDeadline.read(
      analytics.setAnalyticsCollectionEnabled(enabled),
      timeout: const Duration(seconds: 4),
    );
  }

  Future<void> logAppOpen() async {
    final analytics = _analytics;
    if (analytics == null) {
      return;
    }

    await _bestEffort(analytics.logAppOpen());
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

    await _bestEffort(
      analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      ),
    );
  }

  Future<void> setUserContext({String? userId, String? role}) async {
    final analytics = _analytics;
    if (analytics == null) {
      return;
    }

    final revision = ++_contextRevision;
    // Preserve actual completion ordering: a timeout cannot let an old native
    // ID/role update race the next account context. Newer work skips stale role
    // writes and follows any already-dispatched native ID update.
    final work = _contextTail
        .then((_) async {
          if (revision != _contextRevision) return;
          await analytics.setUserId(id: userId);
          if (revision != _contextRevision) return;
          await analytics.setUserProperty(name: 'supabase_role', value: role);
        })
        .catchError((Object _) {
          AppLogger.warning('Analytics context update was not confirmed.');
        });
    _contextTail = work;
    await _bestEffort(work);
  }

  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    final analytics = _analytics;
    if (analytics == null) {
      return;
    }

    try {
      await RequestDeadline.read(
        analytics.logEvent(name: name, parameters: parameters),
        timeout: const Duration(seconds: 4),
      );
    } on Object catch (error, stackTrace) {
      AppLogger.warning(
        'Failed to log Firebase Analytics event "$name".',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _bestEffort(Future<void> request) async {
    try {
      await RequestDeadline.read(request, timeout: const Duration(seconds: 4));
    } on Object {
      // A timed-out native callback may still complete; no automatic resend.
      AppLogger.warning('Analytics update was not confirmed.');
    }
  }
}

/// Route callbacks use the same finite, best-effort native adapter as shell
/// analytics. A missing callback cannot accumulate unobserved SDK futures.
class _BoundedAnalyticsObserver extends RouteObserver<ModalRoute<dynamic>> {
  _BoundedAnalyticsObserver(this.service);
  final FirebaseAnalyticsService service;

  void _send(Route<dynamic> route) {
    final name = route.settings.name;
    if (route is PageRoute && name != null) {
      unawaited(service.logScreenView(screenName: name));
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _send(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _send(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route is PageRoute && previousRoute != null) _send(previousRoute);
  }
}
