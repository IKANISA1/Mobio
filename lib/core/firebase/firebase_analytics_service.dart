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
  bool _collectionEnabled = false;
  bool _contextReady = false;
  String? _desiredUserId;
  String? _desiredRole;
  String? _lastScreenName;
  int _contextRevision = 0;
  int _collectionRevision = 0;
  Future<void> _contextTail = Future<void>.value();
  Future<void> _collectionTail = Future<void>.value();
  late final _observer = _BoundedAnalyticsObserver(this);

  bool get isReady => _analytics != null;

  void attach(FirebaseAnalytics analytics) {
    _analytics = analytics;
    _collectionEnabled = false;
    _contextReady = false;
    _lastScreenName = null;
    _contextRevision++;
    _collectionRevision++;
    // The shell may establish or clear account context before the SDK arrives.
    // Apply that latest intent before current-route telemetry can be emitted.
    unawaited(setUserContext(userId: _desiredUserId, role: _desiredRole));
  }

  List<NavigatorObserver> get observers => <NavigatorObserver>[_observer];

  Future<void> setCollectionEnabled(bool enabled) async {
    final revision = ++_collectionRevision;
    _collectionEnabled = false;
    final analytics = _analytics;
    if (analytics == null) {
      return;
    }

    final work = _collectionTail.then((_) async {
      if (revision != _collectionRevision ||
          !identical(analytics, _analytics)) {
        return;
      }
      await analytics.setAnalyticsCollectionEnabled(enabled);
      if (revision != _collectionRevision ||
          !identical(analytics, _analytics)) {
        return;
      }
      _collectionEnabled = enabled;
      if (enabled && _contextReady) _observer.onAttached();
    });
    _collectionTail = work.then<void>((_) {}, onError: (Object _) {});
    await RequestDeadline.read(work, timeout: const Duration(seconds: 4));
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
    if (analytics == null ||
        !_collectionEnabled ||
        !_contextReady ||
        _lastScreenName == screenName) {
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
    if (_contextReady && userId == _desiredUserId && role == _desiredRole) {
      return;
    }
    _desiredUserId = userId;
    _desiredRole = role;
    _contextReady = false;
    _lastScreenName = null;
    final revision = ++_contextRevision;
    final analytics = _analytics;
    if (analytics == null) {
      return;
    }

    // Preserve actual completion ordering: a timeout cannot let an old native
    // ID/role update race the next account context. Newer work skips stale role
    // writes and follows any already-dispatched native ID update.
    final work = _contextTail
        .then((_) async {
          if (revision != _contextRevision) return;
          await analytics.setUserId(id: userId);
          if (revision != _contextRevision) return;
          await analytics.setUserProperty(name: 'supabase_role', value: role);
          if (revision != _contextRevision) return;
          _contextReady = true;
          if (_collectionEnabled) _observer.onAttached();
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
  Route<dynamic>? _currentRoute;

  void onAttached() {
    final route = _currentRoute;
    if (route != null) _send(route);
  }

  void _send(Route<dynamic> route) {
    final name = route.settings.name;
    if (route is PageRoute && name != null) {
      _currentRoute = route;
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
