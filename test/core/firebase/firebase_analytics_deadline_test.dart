import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/firebase/firebase_analytics_service.dart';

void main() {
  testWidgets('route observer observes late native failure without resending', (
    tester,
  ) async {
    final analytics = _HeldAnalytics();
    final service = FirebaseAnalyticsService.forTesting()..attach(analytics);
    final observer = service.observers.single;
    final route = MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/held-route'),
      builder: (_) => const SizedBox.shrink(),
    );
    observer.didPush(route, null);
    expect(analytics.screens, ['/held-route']);
    await tester.pump(const Duration(seconds: 5));
    analytics.pending.completeError(
      StateError('Synthetic late native failure'),
    );
    await tester.pump();
    observer.didPush(route, null);
    await tester.pump();
    expect(analytics.screens, ['/held-route']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('native screen telemetry observer completes at its deadline', (
    tester,
  ) async {
    final analytics = _HeldAnalytics();
    final service = FirebaseAnalyticsService.forTesting()..attach(analytics);
    var completed = false;
    unawaited(
      service
          .logScreenView(screenName: '/deadline')
          .then((_) => completed = true),
    );
    await tester.pump();
    expect(completed, isFalse);
    await tester.pump(const Duration(seconds: 5));
    expect(completed, isTrue);
    analytics.pending.complete();
    await tester.pump();
    expect(analytics.screens, ['/deadline']);
  });

  for (final next in ['clear', 'same-owner-role']) {
    testWidgets('late old context cannot overwrite newer $next context', (
      tester,
    ) async {
      final analytics = _HeldContextAnalytics();
      final service = FirebaseAnalyticsService.forTesting()..attach(analytics);
      var oldObserverDone = false;
      unawaited(
        service
            .setUserContext(userId: 'owner', role: 'driver')
            .then((_) => oldObserverDone = true),
      );
      await tester.pump();
      expect(analytics.calls, ['id:owner']);
      final newest = next == 'clear'
          ? service.setUserContext()
          : service.setUserContext(userId: 'owner', role: 'passenger');
      await tester.pump(const Duration(seconds: 5));
      expect(oldObserverDone, isTrue);
      expect(analytics.calls, ['id:owner']);
      analytics.pending.complete();
      await tester.pump();
      await newest;
      expect(
        analytics.calls,
        next == 'clear'
            ? ['id:owner', 'id:null', 'role:null']
            : ['id:owner', 'id:owner', 'role:passenger'],
      );
      expect(analytics.calls, isNot(contains('role:driver')));
      expect(tester.takeException(), isNull);
    });
  }
}

class _HeldAnalytics implements FirebaseAnalytics {
  final pending = Completer<void>();
  final screens = <String>[];

  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) {
    screens.add(screenName!);
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HeldContextAnalytics implements FirebaseAnalytics {
  final pending = Completer<void>();
  final calls = <String>[];
  bool held = false;

  @override
  Future<void> setUserId({String? id, AnalyticsCallOptions? callOptions}) {
    calls.add('id:$id');
    if (!held) {
      held = true;
      return pending.future;
    }
    return Future.value();
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
    AnalyticsCallOptions? callOptions,
  }) async {
    calls.add('role:$value');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
